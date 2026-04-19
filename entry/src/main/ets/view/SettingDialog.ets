import History from '../common/bean/History'
import CommonConstants from '../common/constants/CommonConstants'
import { Prompt, PromptAction } from '@kit.ArkUI'
import WhitelistDialog from './WhitelistDialog'
import emitter from '@ohos.events.emitter'

@CustomDialog
export default struct SettingDialog {
  @Consume("historyMap") historyMap: Map<string, History[]>

  @StorageLink("currentEngineIndex") currentEngineIndex: number = 0
  @StorageLink("currentEngineName") currentEngineName: string = CommonConstants.SEARCH_ENGINES[0].engine
  @StorageLink("privateMode") privateMode: boolean = false
  @StorageLink("darkMode") darkMode: boolean = false
  @StorageLink("studyModeEnabled") studyModeEnabled: boolean = false
  @StorageLink("studyWhitelistJson") studyWhitelistJson: string = CommonConstants.DEFAULT_STUDY_WHITELIST_JSON
  @StorageLink("readerModeEnabled") readerModeEnabled: boolean = false
  @StorageLink("readerFeatureAvailable") readerFeatureAvailable: boolean = false
  @StorageLink("readerDetectLoading") readerDetectLoading: boolean = false
  @StorageLink("readerConfidence") readerConfidence: number = 0
  @StorageLink("readerUnsupportedReason") readerUnsupportedReason: string = ''
  @StorageLink("readerRequestToken") readerRequestToken: number = 0
  @StorageLink("ttsRequestToken") ttsRequestToken: number = 0

  controller: CustomDialogController

  @State showWhitelist: boolean = false
  @State showEnginePicker: boolean = false
  @State showReaderStatus: boolean = false
  @State readerModeActive: boolean = false
  @State privateModeActive: boolean = false
  @State darkModeActive: boolean = false
  @State studyModeActive: boolean = false
  @State refreshTick: number = 0

  private searchEngine: SelectOption[] = []

  promptAction: PromptAction = this.getUIContext().getPromptAction()

  async aboutToAppear() {
    this.readerModeActive = this.readerModeEnabled
    this.privateModeActive = this.privateMode
    this.darkModeActive = this.darkMode
    this.studyModeActive = this.studyModeEnabled
    this.searchEngine = []
    for (let item of CommonConstants.SEARCH_ENGINES) {
      this.searchEngine.push({ value: item.engine })
    }
  }

  private clearHistory() {
    this.historyMap.clear()
    Prompt.showToast({ message: "浏览记录已被清除" })
  }

  private showClearHistoryDialog() {
    try {
      this.promptAction.showDialog({
        title: "提示",
        message: "确定要删除所有浏览记录？",
        alignment: DialogAlignment.Bottom,
        buttons: [
          { text: "取消", color: "#E62E31" },
          { text: "确定", color: "#45A5FF" }
        ]
      }, (error, data) => {
        if (error) {
          console.error(`弹窗异常：${error}`)
          return
        }
        if (data.index === 1) {
          this.clearHistory()
        }
      })
    } catch (error) {
      console.error(`弹出提示框异常：${error}`)
    }
  }

  private toggleReaderMode() {
    if (!this.readerModeEnabled && !this.readerFeatureAvailable) {
      const reason = this.readerUnsupportedReason.length > 0 ? this.readerUnsupportedReason : "识别结果未满足阈值"
      Prompt.showToast({ message: `当前页面暂不支持阅读器模式：${reason}` })
      return
    }

    const nextEnabled = !this.readerModeActive
    this.readerModeActive = nextEnabled
    this.readerModeEnabled = nextEnabled
    this.refreshTick = this.refreshTick + 1
    if (nextEnabled) {
      this.readerRequestToken = this.readerRequestToken + 1
      emitter.emit('readerRequest', { data: { enabled: true, token: this.readerRequestToken } })
    }
    Prompt.showToast({ message: nextEnabled ? "已进入阅读器模式" : "已退出阅读器模式" })
  }

  private toggleDarkMode() {
    const nextEnabled = !this.darkModeActive
    this.darkModeActive = nextEnabled
    this.darkMode = nextEnabled
    this.refreshTick = this.refreshTick + 1
    Prompt.showToast({ message: nextEnabled ? "深色模式已启用" : "深色模式已关闭" })
  }

  private togglePrivateMode() {
    const nextEnabled = !this.privateModeActive
    this.privateModeActive = nextEnabled
    this.privateMode = nextEnabled
    this.refreshTick = this.refreshTick + 1
    Prompt.showToast({ message: nextEnabled ? "已开启无痕浏览" : "已关闭无痕浏览" })
  }

  private toggleStudyMode() {
    const nextEnabled = !this.studyModeActive
    this.studyModeActive = nextEnabled
    this.studyModeEnabled = nextEnabled
    this.refreshTick = this.refreshTick + 1
    Prompt.showToast({ message: nextEnabled ? "学习模式已启用" : "学习模式已关闭" })
  }

  private startTts() {
    this.ttsRequestToken = this.ttsRequestToken + 1
    Prompt.showToast({ message: "已发起朗读" })
  }

  private isActionActive(active: boolean): boolean {
    const tick = this.refreshTick
    return active || tick < 0
  }

  @Builder
  private QuickAction(label: string, badge: string, active: boolean, onClick: () => void) {
    Column({ space: 7 }) {
      Text(badge)
        .width(42)
        .height(42)
        .fontSize(15)
        .fontWeight(active ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(active ? Color.White : '#3D4350')
        .textAlign(TextAlign.Center)
        .backgroundColor(active ? '#1F2937' : '#F3F4F8')
        .borderRadius(21)
      .shadow({
        radius: active ? 8 : 0,
        color: '#26000000',
        offsetY: active ? 3 : 0
      })

      Text(label)
        .fontSize(12)
        .fontWeight(active ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(active ? '#111827' : '#252B36')
        .textAlign(TextAlign.Center)
        .maxLines(2)
    }
    .width('25%')
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      onClick()
    })
  }

  @Builder
  private EnginePicker() {
    Row() {
      Text("搜索引擎")
        .fontSize(14)
        .fontColor('#555C66')
      Blank()
      Select(this.searchEngine)
        .selected(this.currentEngineIndex)
        .value(this.currentEngineName)
        .fontColor("#2F6BFF")
        .onSelect((index: number, value: string) => {
          this.currentEngineIndex = index
          this.currentEngineName = value
          Prompt.showToast({ message: `搜索引擎已切换为 ${value}` })
        })
    }
    .width('100%')
    .height(44)
    .padding({ left: 14, right: 10 })
    .backgroundColor('#F6F7FA')
    .borderRadius(16)
  }

  @Builder
  private ReaderStatusCard() {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(40)
          .height(40)
          .fill(this.readerModeEnabled ? '#2F6BFF' : (this.readerFeatureAvailable ? '#EAF5FF' : '#F3F4F8'))
        Text(this.readerDetectLoading ? '...' : `${Math.round(this.readerConfidence * 100)}`)
          .fontSize(this.readerDetectLoading ? 13 : 12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.readerModeEnabled ? Color.White : (this.readerFeatureAvailable ? '#2F6BFF' : '#6B7280'))
      }

      Column({ space: 3 }) {
        Text('阅读器模式')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#252B36')
        if (this.readerDetectLoading) {
          Text('识别中...')
            .fontSize(11)
            .fontColor('#45A5FF')
        } else {
          Text(this.readerFeatureAvailable ? `当前页面可阅读 (${Math.round(this.readerConfidence * 100)}%)` : '当前页面不可用')
            .fontSize(11)
            .fontColor(this.readerFeatureAvailable ? '#45A5FF' : '#8B9099')
          if (!this.readerFeatureAvailable && this.readerUnsupportedReason.length > 0) {
            Text(`原因：${this.readerUnsupportedReason}`)
              .fontSize(10)
              .fontColor('#E67E22')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(this.readerModeEnabled ? '已开启' : '切换')
        .fontSize(12)
        .fontColor(this.readerModeEnabled ? '#2F6BFF' : '#6B7280')
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor('#F6F7FA')
    .borderRadius(16)
    .onClick(() => {
      this.toggleReaderMode()
    })
  }

  @Builder
  private FooterHandle() {
    Column({ space: 8 }) {
      Row({ space: 4 }) {
        Circle().width(4).height(4).fill('#8B9099')
        Circle().width(4).height(4).fill('#D8DADF')
      }
      .justifyContent(FlexAlign.Center)

      Button({ type: ButtonType.Circle, stateEffect: false }) {
        Text('v')
          .fontSize(18)
          .fontColor('#3D4350')
      }
      .width(36)
      .height(24)
      .backgroundColor('#00FFFFFF')
      .onClick(() => {
        this.controller.close()
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    if (this.showWhitelist) {
      WhitelistDialog({
        onBack: () => {
          this.showWhitelist = false
        }
      })
    } else {
      Column({ space: 18 }) {
        Row() {
          this.QuickAction("搜索引擎", "搜", this.isActionActive(this.showEnginePicker), () => {
            this.showEnginePicker = !this.showEnginePicker
            this.refreshTick = this.refreshTick + 1
          })
          this.QuickAction("阅读器", "读", this.isActionActive(this.readerModeActive), () => {
            this.showReaderStatus = !this.showReaderStatus
            this.refreshTick = this.refreshTick + 1
          })
          this.QuickAction("深色", "夜", this.isActionActive(this.darkModeActive), () => {
            this.toggleDarkMode()
          })
          this.QuickAction("学习", "学", this.isActionActive(this.studyModeActive), () => {
            this.toggleStudyMode()
          })
        }
        .width('100%')

        Row() {
          this.QuickAction("白名单", "白", false, () => {
            this.showWhitelist = true
          })
          this.QuickAction("朗读", "朗", false, () => {
            this.startTts()
          })
          this.QuickAction("清记录", "清", false, () => {
            this.showClearHistoryDialog()
          })
          this.QuickAction("无痕浏览", "隐", this.isActionActive(this.privateModeActive), () => {
            this.togglePrivateMode()
          })
        }
        .width('100%')

        if (this.showReaderStatus) {
          this.ReaderStatusCard()
        }

        if (this.showEnginePicker) {
          this.EnginePicker()
        }

        this.FooterHandle()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 20, bottom: 14 })
      .backgroundColor(Color.White)
      .borderRadius({ topLeft: 18, topRight: 18 })
    }
  }
}
