import { router, Prompt } from '@kit.ArkUI';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { http } from '@kit.NetworkKit'; // 引入网络模块
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit'; // 引入图片处理模块
import { util } from '@kit.ArkTS'; // 必须显式引入 util 模块

interface ProfileMenuItem {
  icon: Resource;
  title: string;
  url: string;
}

@Entry
@Component
struct ProfilePage {
  @StorageLink("darkMode") darkMode: boolean = false;
  @StorageLink("isLogin") isLogin: boolean = false;
  @StorageLink("nickname") nickname: string = "小狐狸用户";
  @StorageLink("avatarPath") avatarPath: string = "";
  @StorageLink("lastScanUri") lastScanUri: string = "";

  private mainMenus: ProfileMenuItem[] = [
    { icon: $r('app.media.clone_regular'), title: '浏览历史', url: 'pages/HistoryListPage' },
    { icon: $r('app.media.bookmark'), title: '我的书签', url: '' },
    { icon: $r('app.media.download'), title: '下载记录', url: 'pages/DownloadListPage' }, // 补全路径
    { icon: $r('app.media.note'), title: '网页笔记', url: '' },
    { icon: $r('app.media.gear_setting_settings_wheel_icon'), title: '设置中心', url: 'pages/SettingsPage' },
  ];

  onPageShow(): void {
    let target: string | undefined = AppStorage.get<string>("targetUrl");
    if (target && target !== "") {
      router.back();
    }
  }


  // 扫码
  async startScan(): Promise<void> {
    // 1. 配置扫码参数
    let options: scanBarcode.ScanOptions = {
      scanTypes: [scanCore.ScanType.ALL], // 识别所有类型的码（QR, 条形码等）
      enableMultiMode: true,             // 开启多码识别
      enableAlbum: true                  // 允许从相册选择图片扫码
    };

    try {
      // 2. 启动扫码界面
      // getContext(this) 获取当前上下文
      const result: scanBarcode.ScanResult = await scanBarcode.startScanForResult(getContext(this), options);

      // 3. 处理扫码结果
      if (result && result.originalValue) {
        let content: string = result.originalValue;
        console.info(`[Scan] 扫码结果: ${content}`);

        // 4. 逻辑处理：判断是否为网址
        if (content.startsWith("http://") || content.startsWith("https://")) {
          // 如果是网址，通过全局 targetUrl 机制跳转加载
          AppStorage.setOrCreate("targetUrl", content);
          router.back(); // 返回 Index 页面会自动触发加载
        } else {
          // 如果不是网址，弹窗显示内容
          this.showScanResult(content);
        }
      }
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      // 错误码 1000500001 表示用户取消了扫码
      if (error.code !== 1000500001) {
        console.error(`[Scan] 扫码异常: Code: ${error.code}, Msg: ${error.message}`);
        Prompt.showToast({ message: "扫码启动失败" });
      }
    }
  }
  /**
   * 触发华为原生 AI 识图流程
   */
  async startAiAnalysis(): Promise<void> {
    try {
      // 1. 调用 Picker 选择图片
      const photoSelectOptions = new picker.PhotoSelectOptions();
      photoSelectOptions.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;
      const photoPicker = new picker.PhotoViewPicker();
      const photoSelectResult = await photoPicker.select(photoSelectOptions);

      if (photoSelectResult && photoSelectResult.photoUris.length > 0) {
        // 2. 存储 URI 并跳转
        AppStorage.setOrCreate("selectedImageUri", photoSelectResult.photoUris[0]);
        router.pushUrl({ url: 'pages/ImageAnalysisPage' });
      }
    } catch (err) {
      console.error("启动识图失败");
    }
  }


  // 修复点：添加缺失的 showScanResult 函数
  showScanResult(content: string): void {
    AlertDialog.show({
      title: '扫码结果',
      message: content,
      confirm: {
        value: '确定',
        action: () => {}
      }
    })
  }

  build() {
    Column() {
      // 1. 顶部返回 + 用户信息
      this.UserInfoHeader()

      // 2. 功能列表
      List() {
        ForEach(this.mainMenus, (item: ProfileMenuItem) => {
          ListItem() {
            this.MenuRow(item)
          }
        })
      }
      .divider({ strokeWidth: 1, color: this.darkMode ? "#333" : "#EEE", startMargin: 50 })
      .backgroundColor(this.darkMode ? "#2C2C2C" : Color.White)
      .borderRadius(12).margin(15)

      Blank()
      this.AiToolBar()
    }
    .width('100%').height('100%')
    .backgroundColor(this.darkMode ? "#1C1C1C" : "#F5F5F7")
  }

  @Builder UserInfoHeader() {
    Column() {
      Row() {
        Image($r('app.media.left_arrow_icon')).width(24)
          .onClick(() => router.back())
        Text("个人主页").fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 15 })
          .fontColor(this.darkMode ? Color.White : Color.Black)
      }.width('100%').padding(20)

      Row() {
        // 头像：如果是 file:// 路径则显示，否则显示默认图标
        Image(this.avatarPath !== "" ? "file://" + this.avatarPath : $r('app.media.app_icon'))
          .width(80).height(80).borderRadius(40)
          .border({ width: 2, color: '#45A5FF' })
          .objectFit(ImageFit.Cover)
          .onClick(() => {
            if (this.isLogin) {
              router.pushUrl({ url: 'pages/ProfileEditPage' })
            }
          })

        Column() {
          Text(this.isLogin ? this.nickname : "点击登录账号")
            .fontSize(20).fontWeight(FontWeight.Bold)
            .fontColor(this.darkMode ? Color.White : Color.Black)
            .onClick(() => {
              if (!this.isLogin) {
                router.pushUrl({ url: 'pages/LoginPage' })
              } else {
                router.pushUrl({ url: 'pages/ProfileEditPage' })
              }
            })

          Text(this.isLogin ? "点击修改个人资料" : "同步书签与历史记录")
            .fontSize(12).margin({ top: 5 }).fontColor(Color.Gray)
        }.alignItems(HorizontalAlign.Start).margin({ left: 15 })
      }
      .width('100%').padding({ left: 30, bottom: 20 })
    }
  }

  @Builder MenuRow(item: ProfileMenuItem) {
    Row() {
      Row() {
        Image(item.icon).width(22).height(22).margin({ right: 15 })
        Text(item.title).fontSize(16).fontColor(this.darkMode ? Color.White : Color.Black)
      }
      Image($r('app.media.right_arrow_icon')).width(12).opacity(0.3)
    }
    .width('100%').padding(18)
    .justifyContent(FlexAlign.SpaceBetween)
    .onClick(() => {
      if (item.url !== "") router.pushUrl({ url: item.url })
    })
  }

  @Builder AiToolBar() {
    Row() {
      // 扫码
      this.AiToolItem($r('app.media.scan' ), "扫码", () => {
        this.startScan(); // 调用之前的扫码方法
      })

      // 识图
      this.AiToolItem($r('app.media.ai_picture_analyser'), "识图", () => {
        this.startAiAnalysis(); // 调用新写的识图方法
      })

      // 扫描：跳转到新创建的扫描页
      this.AiToolItem($r('app.media.file_scan'), "扫描", () => {
        router.pushUrl({ url: 'pages/DocScanPage' })
      })
    }
    .width('100%').padding({ bottom: 40 }).justifyContent(FlexAlign.SpaceAround)
  }

  @Builder AiToolItem(icon: Resource, label: string, onClick: () => void) {
    Column() {
      Image(icon).width(28).height(28)
      Text(label).fontSize(12).margin({ top: 5 }).fontColor(this.darkMode ? Color.White : Color.Black)
    }
    .onClick(() => onClick())
  }
}