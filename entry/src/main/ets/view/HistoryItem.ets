import { Prompt } from '@kit.ArkUI'
import CommonConstants from '../common/constants/CommonConstants'
import DomainUtils from '../utils/DomainUtils'
import RequestPolicy, { PolicyConfig } from '../utils/RequestPolicy'
import StudyModeRules from '../utils/StudyModeRules'

@Component
export default struct HistoryItem {
  @Prop title: string = ""
  @Prop url: string = ""
  @State translateX: number = 0
  @State deleteIcon: Resource = $r("app.media.trash_icon")
  @State showDeleteIcon: boolean = false

  // 接收外部传入的回调函数，用于点击后的跳转处理
  public onItemSelected: () => void = () => {}

  // 学习模式
  @StorageLink("studyModeEnabled") studyModeEnabled: boolean = false
  @StorageLink("studyWhitelistJson") studyWhitelistJson: string = CommonConstants.DEFAULT_STUDY_WHITELIST_JSON
  @StorageLink("currentEngineIndex") currentEngineIndex: number = 0
  @StorageLink("darkMode") darkMode: boolean = false

  /**
   * 构建当前策略配置并判断是否允许导航
   * 返回 true 表示放行，false 表示拦截
   */
  private tryNavigate(url: string): boolean {
    const enginePrefix = CommonConstants.SEARCH_ENGINES[this.currentEngineIndex].prefix
    const engineHost = DomainUtils.extractHostFromPrefix(enginePrefix)
    const config: PolicyConfig = {
      studyModeEnabled: this.studyModeEnabled,
      whitelist: StudyModeRules.parseWhitelist(this.studyWhitelistJson),
      currentSearchEngineHost: engineHost
    }
    const decision = RequestPolicy.evaluateNavigation(url, config)
    if (decision.action === "block") {
      Prompt.showToast({ message: decision.message })
      return false
    }
    return true
  }

  build() {
    Row() {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 12 }) {
          Text((this.title === "" ? this.url : this.title).substring(0, 1).toUpperCase())
            .width(38)
            .height(38)
            .textAlign(TextAlign.Center)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#45A5FF')
            .backgroundColor(this.darkMode ? '#17324A' : '#EAF5FF')
            .borderRadius(14)

          Column({ space: 5 }) {
            Text(this.title === "" ? this.url : this.title)
              .width("100%")
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.darkMode ? '#F8FAFC' : '#101828')
              .textAlign(TextAlign.Start)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .maxLines(1)
            Text(this.url)
              .width("100%")
              .fontSize(11)
              .fontColor(this.darkMode ? '#98A2B3' : '#667085')
              .textAlign(TextAlign.Start)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .maxLines(1)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ left: 14, right: 14, top: 12, bottom: 12 })
      }
      .margin({ left: 16, right: 16, bottom: 10 })
      .borderRadius(18)
      .backgroundColor(this.darkMode ? '#252B33' : Color.White)
      .shadow({
        radius: this.darkMode ? 0 : 12,
        color: '#16000000',
        offsetY: 5
      })
      .layoutWeight(1)
      .onClick(() => {
        // 先进行学习模式策略校验，拦截时仅提示 toast，不执行后续跳转
        if (!this.tryNavigate(this.url)) {
          return;
        }

        // 校验通过：存储 URL 到 AppStorage，执行外部回调。
        AppStorage.setOrCreate("targetUrl", this.url);
        this.onItemSelected();
      });

      if (this.showDeleteIcon) {
        Button({ type: ButtonType.Circle }) {
          Image(this.deleteIcon)
            .width(20)
            .height(20)
            .fillColor("#E62E31")
        }
        .height(30)
        .width(30)
        .margin({ right: 15 })
        .backgroundColor("#00000000")
        .onClick(() => {
          console.log('删除项目:', this.title)
        })
      }
    }
    .justifyContent(FlexAlign.SpaceBetween)
    .width('100%')
    .offset({ x: this.translateX })
    .gesture(
      SwipeGesture({
        direction: SwipeDirection.Horizontal,
      })
      .onAction((event: GestureEvent) => {
        if (event.offsetX < -30) {
          // 向左滑动显示删除按钮
          this.translateX = -80
          this.showDeleteIcon = true
        } else if (event.offsetX > 30) {
          // 向右滑动隐藏删除按钮
          this.translateX = 0
          this.showDeleteIcon = false
        }
      })
    )
  }
}
