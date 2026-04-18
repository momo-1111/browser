import { visionImageAnalyzer } from '@kit.VisionKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { router } from '@kit.ArkUI';

@Entry
@Component
struct ImageAnalysisPage {
  // 获取从 ProfilePage 传过来的图片 URI
  @StorageLink("selectedImageUri") selectedImageUri: string = "";
  @StorageLink("darkMode") darkMode: boolean = false;

  private visionImageAnalyzerController: visionImageAnalyzer.VisionImageAnalyzerController = new visionImageAnalyzer.VisionImageAnalyzerController();
  @State isSupportImageAnalyzer: boolean = false;

  aboutToAppear(): void {
    // 1. 判断设备是否支持 AI 识图
    let supportTypes = this.visionImageAnalyzerController.getImageAnalyzerSupportTypes();
    if (supportTypes.length > 0) {
      this.isSupportImageAnalyzer = true;
      this.registerListener();
    }
  }

  // 2. 注册监听（可选，用于调试或扩展业务）
  registerListener() {
    this.visionImageAnalyzerController.on('analyzerFailed', (error: BusinessError) => {
      console.error("AI识图失败", JSON.stringify(error));
    });
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 3. 核心：带 AI 识图能力的 Image 控件
      if (this.selectedImageUri !== "") {
        Image(this.selectedImageUri, {
          // 开启：文字识别、主体分割、对象查找（识图搜索）
          types: [ImageAnalyzerType.TEXT, ImageAnalyzerType.SUBJECT, ImageAnalyzerType.OBJECT_LOOKUP],
          aiController: this.visionImageAnalyzerController
        })
          .width('100%')
          .height('100%')
          // 使能分析器
          .enableAnalyzer(this.isSupportImageAnalyzer)
          .objectFit(ImageFit.Contain)
          .backgroundColor(Color.Black)
      }

      // 返回按钮
      Image($r('app.media.left_arrow_icon'))
        .width(30).height(30)
        .margin({ top: 40, left: 20 })
        .fillColor(Color.White)
        .onClick(() => router.back())

      // 底部操作提示
      Text("提示：长按图片可抠图或选文字，点击AI图标识物")
        .fontSize(12).fontColor(Color.White).width('100%')
        .textAlign(TextAlign.Center).margin({ bottom: 20 })
        .position({ x: 0, y: '90%' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }

  aboutToDisappear(): void {
    // 4. 释放资源
    this.visionImageAnalyzerController.off('analyzerFailed');
  }
}