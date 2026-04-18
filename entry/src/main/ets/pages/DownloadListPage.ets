import { router, promptAction } from '@kit.ArkUI';
import { common, Want, wantConstant } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileUri } from '@kit.CoreFileKit'; // 必须导入
import RdbUtils from '../utils/RdbUtils';
@Entry
@Component
struct DownloadListPage {
  @StorageLink("darkMode") darkMode: boolean = false;
  @StorageLink("userId") userId: string = "guest";
  @State downloadList: Array<Record<string, Object>> = [];

  async onPageShow() {
    this.downloadList = await RdbUtils.queryDownloads(this.userId);
  }

  /**
   * 核心：通过内部路径生成 URI，并带上 MimeType 打开
   */
  openFile(path: string, type: string): void {
    const context = getContext(this) as common.UIAbilityContext;

    if (!path) {
      promptAction.showToast({ message: "文件记录异常" });
      return;
    }

    try {
      // 1. 从内部私有路径生成标准的系统 URI
      const uri = fileUri.getUriFromPath(path);

      // 2. 根据文件类型确定 MimeType (这是系统识别的关键)
      let mimeType = (type === "pdf") ? "application/pdf" : "image/jpeg";

      const want: Want = {
        action: 'ohos.want.action.viewData',
        uri: uri,
        type: mimeType, // 【必须】：告知系统文件类型
        flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION // 授权读取
      };

      console.info(`[Open] 正在尝试打开: ${uri}, 类型: ${mimeType}`);

      context.startAbility(want).then(() => {
        console.info("打开成功");
      }).catch((err: BusinessError) => {
        console.error(`打开失败: ${err.code} ${err.message}`);
        promptAction.showToast({ message: "未找到可查看此文件的应用" });
      });
    } catch (e) {
      promptAction.showToast({ message: "文件可能已被删除" });
    }
  }

  build() {
    Column() {
      // 标题栏...
      Row() {
        Image($r('app.media.left_arrow_icon')).width(24).onClick(() => router.back())
        Text("下载记录").fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 15 })
          .fontColor(this.darkMode ? Color.White : Color.Black)
      }.width('100%').padding(20)

      List() {
        ForEach(this.downloadList, (item: Record<string, Object>) => {
          ListItem() {
            Row() {
              Image(item['fileType'] === 'pdf' ? $r('app.media.file_scan') : $r('app.media.ai_picture_analyser'))
                .width(30).height(30).margin({ right: 15 })

              Column() {
                Text(item['fileName'] as string).fontSize(16).fontWeight(FontWeight.Medium)
                  .fontColor(this.darkMode ? Color.White : Color.Black)
                Text(new Date(item['timestamp'] as number).toLocaleString()).fontSize(12).fontColor(Color.Gray)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)

              Button("查看")
                .backgroundColor(Color.Transparent)
                .fontColor("#45A5FF")
                // 传入路径和类型
                .onClick(() => this.openFile(item['filePath'] as string, item['fileType'] as string))
            }
            .width('100%').padding(15)
            .border({ width: { bottom: 1 }, color: this.darkMode ? "#333" : "#EEE" })
          }
        }, (item: Record<string, Object>) => item['id'].toString())
      }.width('100%').layoutWeight(1)
    }
    .width('100%').height('100%')
    .backgroundColor(this.darkMode ? "#1C1C1C" : "#F5F5F7")
  }
}