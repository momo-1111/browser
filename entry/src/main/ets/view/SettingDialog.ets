import { router, Prompt, PromptAction } from '@kit.ArkUI'
import History from '../common/bean/History'
import CommonConstants from '../common/constants/CommonConstants'
import StudyModeRules from '../utils/StudyModeRules'
import WhitelistDialog from './WhitelistDialog'

@CustomDialog
export default struct SettingDialog {
  @Consume('historyMap') historyMap: Map<string, History[]>

  @StorageLink('currentEngineIndex') currentEngineIndex: number = 0
  @StorageLink('currentEngineName') currentEngineName: string = CommonConstants.SEARCH_ENGINES[0].engine
  @StorageLink('darkMode') darkMode: boolean = false
  @StorageLink('privateMode') privateMode: boolean = false
  @StorageLink('studyModeEnabled') studyModeEnabled: boolean = false
  @StorageLink('studyWhitelistJson') studyWhitelistJson: string = CommonConstants.DEFAULT_STUDY_WHITELIST_JSON
  @StorageLink('readerModeEnabled') readerModeEnabled: boolean = false
  @StorageLink('readerFeatureAvailable') readerFeatureAvailable: boolean = false
  @StorageLink('readerDetectLoading') readerDetectLoading: boolean = false
  @StorageLink('readerConfidence') readerConfidence: number = 0
  @StorageLink('readerUnsupportedReason') readerUnsupportedReason: string = ''
  @StorageLink('ttsRequestToken') ttsRequestToken: number = 0

  controller: CustomDialogController

  @State showWhitelist: boolean = false

  promptAction: PromptAction = this.getUIContext().getPromptAction()

  private cycleSearchEngine() {
    const nextIndex = (this.currentEngineIndex + 1) % CommonConstants.SEARCH_ENGINES.length
    this.currentEngineIndex = nextIndex
    this.currentEngineName = CommonConstants.SEARCH_ENGINES[nextIndex].engine
    Prompt.showToast({ message: `搜索引擎已切换到 ${this.currentEngineName}` })
  }

  private openPage(url: string) {
    this.controller.close()
    router.pushUrl({ url })
  }

  private clearHistory() {
    this.historyMap.clear()
    Prompt.showToast({ message: '浏览历史已清空' })
  }

  private showClearHistoryDialog() {
    this.promptAction.showDialog({
      title: '清空浏览历史',
      message: '确认删除当前历史记录吗？这个操作无法撤销。',
      alignment: DialogAlignment.Bottom,
      buttons: [
        {
          text: '取消',
          color: '#667085'
        },
        {
          text: '清空',
          color: '#E5484D'
        }
      ]
    }, (error, data) => {
      if (!error && data.index === 1) {
        this.clearHistory()
      }
    })
  }

  private toggleReaderMode() {
    if (!this.readerModeEnabled && !this.readerFeatureAvailable) {
      const reason = this.readerUnsupportedReason && this.readerUnsupportedReason.length > 0
        ? this.readerUnsupportedReason
        : '当前页面暂不支持'
      Prompt.showToast({ message: `阅读模式暂时不可用：${reason}` })
      return
    }
    this.readerModeEnabled = !this.readerModeEnabled
    Prompt.showToast({ message: this.readerModeEnabled ? '阅读模式已开启' : '阅读模式已关闭' })
  }

  @Builder
  private QuickAction(label: string, badge: string, tone: string, active: boolean, onClick: () => void) {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(44)
          .height(44)
          .fill(active ? '#2F6BFF' : '#F2F4F7')
        Text(badge)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(active ? Color.White : tone)
      }

      Text(label)
        .fontSize(12)
        .fontColor('#344054')
        .maxLines(2)
        .textAlign(TextAlign.Center)
    }
    .width('20%')
    .onClick(() => {
      onClick()
    })
  }

  @Builder
  private FooterAction(title: string, value: string, onClick: () => void) {
    Row() {
      Text(title)
        .fontSize(15)
        .fontColor('#111827')
      Blank()
      Text(value)
        .fontSize(13)
        .fontColor('#98A2B3')
    }
    .width('100%')
    .padding({ top: 14, bottom: 14, left: 4, right: 4 })
    .border({
      width: { bottom: 1 },
      color: '#F2F4F7'
    })
    .onClick(() => {
      onClick()
    })
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
        Column() {
          Row() {
            Text('快捷设置')
              .fontSize(22)
              .fontWeight(FontWeight.Medium)
              .fontColor('#111827')
            Blank()
            Button({ type: ButtonType.Circle, stateEffect: false }) {
              Text('v')
                .fontSize(18)
                .fontColor('#344054')
            }
            .width(34)
            .height(34)
            .backgroundColor('#F2F4F7')
            .onClick(() => {
              this.controller.close()
            })
          }
          .width('100%')

          Text('参考图里的底部面板样式，改成更轻、更整齐的两行快捷入口。')
            .width('100%')
            .fontSize(12)
            .fontColor('#98A2B3')
            .margin({ top: 6 })
        }
        .width('100%')

        Column({ space: 18 }) {
          Row() {
            this.QuickAction('夜间模式', '夜', '#344054', this.darkMode, () => {
              this.darkMode = !this.darkMode
              Prompt.showToast({ message: this.darkMode ? '夜间模式已开启' : '夜间模式已关闭' })
            })
            this.QuickAction('书签', '签', '#344054', false, () => {
              this.openPage('pages/ProfilePage')
            })
            this.QuickAction('历史', '史', '#344054', false, () => {
              this.openPage('pages/HistoryListPage')
            })
            this.QuickAction('下载', '下', '#344054', false, () => {
              this.openPage('pages/DownloadListPage')
            })
            this.QuickAction('无痕', '隐', '#344054', this.privateMode, () => {
              this.privateMode = !this.privateMode
              Prompt.showToast({ message: this.privateMode ? '无痕模式已开启' : '无痕模式已关闭' })
            })
          }
          .width('100%')

          Row() {
            this.QuickAction('学习模式', '学', '#344054', this.studyModeEnabled, () => {
              this.studyModeEnabled = !this.studyModeEnabled
              Prompt.showToast({ message: this.studyModeEnabled ? '学习模式已开启' : '学习模式已关闭' })
            })
            this.QuickAction('白名单', '白', '#344054', false, () => {
              this.showWhitelist = true
            })
            this.QuickAction('阅读模式', '读', '#344054', this.readerModeEnabled, () => {
              this.toggleReaderMode()
            })
            this.QuickAction('搜索引擎', '搜', '#344054', false, () => {
              this.cycleSearchEngine()
            })
            this.QuickAction('设置', '设', '#344054', false, () => {
              this.openPage('pages/SettingsPage')
            })
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: 6, right: 6, top: 6, bottom: 6 })
        .backgroundColor(Color.White)
        .borderRadius(24)

        Column() {
          this.FooterAction('当前搜索引擎', this.currentEngineName, () => {
            this.cycleSearchEngine()
          })
          this.FooterAction('白名单数量', `${StudyModeRules.parseWhitelist(this.studyWhitelistJson).length} 个站点`, () => {
            this.showWhitelist = true
          })
          this.FooterAction('语音朗读', this.readerDetectLoading ? '分析中' : '立即开始', () => {
            this.ttsRequestToken = this.ttsRequestToken + 1
            Prompt.showToast({ message: '已发起语音朗读请求' })
          })
          this.FooterAction('清空浏览历史', '删除记录', () => {
            this.showClearHistoryDialog()
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .backgroundColor(Color.White)
        .borderRadius(24)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 14, bottom: 24 })
      .backgroundColor('#F7F7FB')
      .borderRadius({ topLeft: 28, topRight: 28 })
    }
  }
}
