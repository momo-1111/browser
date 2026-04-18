import { router, promptAction, Prompt } from '@kit.ArkUI'; // 1. 关键：改为 promptAction
import { fileIo as fs, picker, fileUri } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { webview } from '@kit.ArkWeb';
import { util } from '@kit.ArkTS'; // 用于 Base64 转换
import RdbUtils from '../utils/RdbUtils';

@Entry
@Component
struct ScanResultPage {
  @StorageLink("currentScanUris") scanUris: string[] = [];
  @StorageLink("darkMode") darkMode: boolean = false;
  @StorageLink("userId") userId: string = "guest";

  // Web 控制器
  controller: webview.WebviewController = new webview.WebviewController();

  // PDF 配置 (A4 尺寸)
  pdfConfig: webview.PdfConfiguration = {
    width: 8.27,
    height: 11.69,
    marginTop: 0.1, // 留出微小页边距防止切边
    marginBottom: 0.1,
    marginRight: 0.1,
    marginLeft: 0.1,
    shouldPrintBackground: true
  };

  build() {
    Column() {
      // 1. 标题栏
      Row() {
        Image($r('app.media.left_arrow_icon')).width(24).onClick(() => router.back())
        Text(`扫描件管理 (${this.scanUris.length}页)`)
          .fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 15 })
          .fontColor(this.darkMode ? Color.White : Color.Black)
      }.width('100%').padding(20)

      // 2. 预览网格
      Grid() {
        ForEach(this.scanUris, (uri: string) => {
          GridItem() {
            Image(uri)
              .width('100%')
              .height(220)
              .objectFit(ImageFit.Contain)
              .borderRadius(8)
              .backgroundColor(this.darkMode ? "#333" : "#EEE")
          }
        }, (item: string) => item)
      }
      .columnsTemplate('1fr 1fr')
      .columnsGap(10)
      .rowsGap(10)
      .layoutWeight(1)
      .padding(15)

      // 3. 底部操作栏
      Row() {
        // 保留：保存图片功能
        Button("保存图片")
          .onClick(() => this.downloadAsImages())
          .backgroundColor("#45A5FF")
          .layoutWeight(1)
          .margin({ right: 10 })

        // 增强：导出合规 PDF 功能
        Button("导出 PDF")
          .onClick(() => this.generateWebPdf())
          .backgroundColor("#32D74B")
          .layoutWeight(1)
      }
      .width('100%').padding(20)

      // 4. 隐藏的渲染引擎
      Web({ src: "", controller: this.controller })
        .width(1)
        .height(1)
        .visibility(Visibility.Hidden)
        .fileAccess(true)
    }
    .width('100%').height('100%')
    .backgroundColor(this.darkMode ? "#1C1C1C" : "#F5F5F7")
  }

  /**
   * 功能一：导出图片到公共目录
   */
  // --- 图片保存逻辑同样修改：存入 sandboxPath ---
  async downloadAsImages(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const documentPicker = new picker.DocumentViewPicker();
      for (let i = 0; i < this.scanUris.length; i++) {
        const fileName = `FoxImage_${new Date().getTime()}_${i}.jpg`;
        const sandboxPath = `${context.filesDir}/${fileName}`;

        // 先存沙箱
        let srcPath = this.scanUris[i];
        if (srcPath.startsWith('file://')) srcPath = new fileUri.FileUri(srcPath).path;
        fs.copyFileSync(fs.openSync(srcPath).fd, fs.openSync(sandboxPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE).fd);

        // 再 Picker 存公共
        const saveOptions = new picker.DocumentSaveOptions();
        saveOptions.newFileNames = [fileName];
        const saveUris = await documentPicker.save(saveOptions);
        if (saveUris.length > 0) {
          fs.copyFileSync(fs.openSync(sandboxPath).fd, fs.openSync(new fileUri.FileUri(saveUris[0]).path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE).fd);
          // 数据库存沙箱路径
          await RdbUtils.insertDownload(fileName, sandboxPath, "", "image", this.userId);
        }
      }
      this.showSuccessDialog();
    } catch (err) { console.error(JSON.stringify(err)); }
  }

  /**
   * 功能二：生成 PDF (修复图片加载失败问题)
   */
  // --- PDF 转换逻辑 ---
  async generateWebPdf(): Promise<void> {
    if (this.scanUris.length === 0) return;
    promptAction.showToast({ message: "正在转换高质量 PDF..." });

    let htmlContent = `<html><style>body{margin:0;padding:0;}img{width:100%;display:block;page-break-after:always;}</style><body>`;
    for (let path of this.scanUris) {
      const base64 = await this.fileToBase64(path);
      if (base64) htmlContent += `<img src="data:image/jpeg;base64,${base64}">`;
    }
    htmlContent += `</body></html>`;

    this.controller.loadData(htmlContent, "text/html", "utf-8");
    setTimeout(() => { this.performPdfExport(); }, 1500);
  }

  async fileToBase64(uri: string): Promise<string | null> {
    try {
      let realPath = uri.startsWith('file://') ? new fileUri.FileUri(uri).path : uri;
      let file = fs.openSync(realPath, fs.OpenMode.READ_ONLY);
      let stat = fs.statSync(file.fd);
      let buffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      fs.closeSync(file.fd);
      return new util.Base64Helper().encodeToStringSync(new Uint8Array(buffer));
    } catch (e) { return null; }
  }

  async performPdfExport(): Promise<void> {
    try {
      const result: webview.PdfData = await this.controller.createPdf(this.pdfConfig);
      const context = getContext(this) as common.UIAbilityContext;

      // 1. 定义沙箱永久路径
      const fileName = `FoxScan_${new Date().getTime()}.pdf`;
      const sandboxPath = `${context.filesDir}/${fileName}`;

      // 2. 将 PDF 写入沙箱 (这个文件将用于后续在“下载记录”中点开)
      let file = fs.openSync(sandboxPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      await fs.write(file.fd, result.pdfArrayBuffer().buffer);
      fs.closeSync(file);

      // 3. 调起 Picker 让用户另存一份到公共目录 (给用户看)
      const documentPicker = new picker.DocumentViewPicker();
      const saveOptions = new picker.DocumentSaveOptions();
      saveOptions.newFileNames = [fileName];
      const saveUris = await documentPicker.save(saveOptions);

      if (saveUris.length > 0) {
        const publicUri = saveUris[0];
        const publicPath = new fileUri.FileUri(publicUri).path;

        // 拷贝到公共目录
        let srcFile = fs.openSync(sandboxPath, fs.OpenMode.READ_ONLY);
        let destFile = fs.openSync(publicPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
        fs.copyFileSync(srcFile.fd, destFile.fd);
        fs.closeSync(srcFile.fd);
        fs.closeSync(destFile.fd);

        // 4. 【关键】：数据库存入沙箱路径，类型标记为 pdf
        await RdbUtils.insertDownload(fileName, sandboxPath, "", "pdf", this.userId);
        this.showSuccessDialog();
      }
    } catch (err) {
      console.error("PDF 导出失败: " + JSON.stringify(err));
    }
  }

  showSuccessDialog() {
    promptAction.showDialog({
      title: "保存成功",
      message: "文件已存至手机下载目录，是否前往下载记录查看？",
      buttons: [
        { text: "留在本页", color: "#666666" },
        { text: "去查看", color: "#45A5FF" }
      ]
    }).then((data: promptAction.ShowDialogSuccessResponse) => {
      if (data.index === 1) {
        router.pushUrl({ url: 'pages/DownloadListPage' });
      }
    });
  }
}