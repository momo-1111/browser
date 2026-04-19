import {
  DocType,
  DocumentScanner,
  DocumentScannerConfig,
  SaveOption,
  FilterId,
  ShootingMode
} from "@kit.VisionKit"
import { router, Prompt } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';


const TAG: string = 'DocScanPage'

@Entry
@Component
struct DocScanPage {
  private docScanConfig = new DocumentScannerConfig();

  aboutToAppear() {
    // 配置扫描参数：开启相册支持，设置拍摄模式等
    this.docScanConfig.supportType = [DocType.DOC];
    this.docScanConfig.isGallerySupported = true;
    // 【关键】：设置最大扫描页数，实现多页连扫
    this.docScanConfig.maxShotCount = 50;
    this.docScanConfig.defaultFilterId = FilterId.STRENGTHEN; // 默认使用增强滤镜（更清晰）
    this.docScanConfig.defaultShootingMode = ShootingMode.MANUAL;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 1. 调用华为原生扫描组件
      DocumentScanner({
        scannerConfig: this.docScanConfig,
        onResult: (code: number, saveType: SaveOption, uris: string[]) => {
          hilog.info(0x0001, TAG, `Scan Result: ${code}, URIs: ${uris.length}`);

          if (code === -1) { // 用户点击了返回/取消
            router.back();
            return;
          }

          if (uris.length > 0) {
            // 将扫描到的多条 URI 存入全局存储，跳转到结果管理页
            AppStorage.setOrCreate("currentScanUris", uris);
            router.replaceUrl({ url: 'pages/ScanResultPage' });
          }
        }
      })
        .size({ width: '100%', height: '100%' })

      // 2. 覆盖一个返回按钮（可选，因为组件自带返回逻辑）
      Image($r('app.media.left_arrow_icon'))
        .width(30).height(30)
        .margin({ top: 40, left: 20 })
        .onClick(() => router.back())
    }
    .width('100%')
    .height('100%')
  }
}