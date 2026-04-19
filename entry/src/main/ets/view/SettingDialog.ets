import History from '../common/bean/History'
import CommonConstants from '../common/constants/CommonConstants'
import { Prompt, PromptAction } from '@kit.ArkUI'
import StudyModeRules from '../utils/StudyModeRules'
import WhitelistDialog from './WhitelistDialog'

@CustomDialog
export default struct SettingDialog {
  @Consume("historyMap") historyMap: Map<string, History[]>

  // 从 AppStore 中获取持久化数据
  @StorageLink("currentEngineIndex") currentEngineIndex: number = 0
  @StorageLink("currentEngineName") currentEngineName: string = CommonConstants.SEARCH_ENGINES[0].engine
  @StorageLink("darkMode") darkMode: boolean = false
  // 学习模式相关（吕）
  @StorageLink("studyModeEnabled") studyModeEnabled: boolean = false
  @StorageLink("studyWhitelistJson") studyWhitelistJson: string = CommonConstants.DEFAULT_STUDY_WHITELIST_JSON
  // 阅读器相关（许）
  @StorageLink("readerModeEnabled") readerModeEnabled: boolean = false
  @StorageLink("readerFeatureAvailable") readerFeatureAvailable: boolean = false
  @StorageLink("readerDetectLoading") readerDetectLoading: boolean = false
  @StorageLink("readerConfidence") readerConfidence: number = 0
  @StorageLink("readerUnsupportedReason") readerUnsupportedReason: string = ''
  @StorageLink("ttsRequestToken") ttsRequestToken: number = 0

  controller: CustomDialogController

  @State showWhitelist: boolean = false

  private searchEngine: SelectOption[] = []

  private itemHeight: number = 40

  promptAction: PromptAction = this.getUIContext().getPromptAction();

  async aboutToAppear() {
    this.searchEngine = []
    for (let item of CommonConstants.SEARCH_ENGINES) {
      this.searchEngine.push({value: item.engine})
    }
  }

  onConfirm() {
    this.historyMap.clear()

    Prompt.showToast({
      message: "浏览记录已被清除"
    })
  }

  build() {
    if (this.showWhitelist) {
      WhitelistDialog({
        onBack: () => { this.showWhitelist = false }
      })
    } else {
      Column() {
        this.EngineBuilder()
        this.DarkModeBuilder()
        this.StudyModeBuilder()     // 学习模式（吕）
        this.WhitelistBuilder()     // 白名单管理（吕）
        this.ReaderModeBuilder()    // 阅读器模式（许）
        this.TtsEntryBuilder()      // 朗读入口（许）
        this.ClearHistoryBuilder()
        this.AboutBuilder()
      }
      .padding({top: 5, bottom: 5})
    }
  }

  // 设置搜索引擎
  @Builder EngineBuilder() {
    Row() {
      Text("搜索引擎")
        .margin({left: 15})
        .fontSize(17)
      Select(this.searchEngine)
        .margin({right: 15})
        .fontColor("#45A5FF")
        .selected(this.currentEngineIndex)
        .value(this.currentEngineName)
        .onSelect((index: number, value: string) => {
          this.currentEngineIndex = index
          this.currentEngineName = value
        })
    }
    .height(this.itemHeight)
    .width("100%")
    .justifyContent(FlexAlign.SpaceBetween)
  }

  // 设置深色模式
  @Builder DarkModeBuilder() {
    Row() {
      Text("深色模式")
        .margin({left: 15})
        .fontSize(17)
      Toggle({type: ToggleType.Switch, isOn: !this.darkMode? false : true})
        .margin({right: 15})
        .animation({
          duration: 50
        })
        .onChange((isOn: boolean) => {
          this.darkMode = isOn
          Prompt.showToast({
            message: isOn ? "深色模式已启用" : "深色模式已关闭",
          })
        })
    }
    .height(this.itemHeight)
    .width("100%")
    .justifyContent(FlexAlign.SpaceBetween)
  }

  // 学习模式开关（吕）
  @Builder StudyModeBuilder() {
    Column() {
      Row() {
        Text("学习模式")
          .margin({left: 15})
          .fontSize(17)
        Toggle({type: ToggleType.Switch, isOn: this.studyModeEnabled})
          .margin({right: 15})
          .animation({
            duration: 50
          })
          .onChange((isOn: boolean) => {
            this.studyModeEnabled = isOn
            Prompt.showToast({
              message: isOn ? "学习模式已启用" : "学习模式已关闭",
            })
          })
      }
      .height(this.itemHeight)
      .width("100%")
      .justifyContent(FlexAlign.SpaceBetween)
      Text("开启后仅允许访问白名单站点和搜索引擎")
        .margin({left: 15})
        .fontSize(12)
        .fontColor(Color.Gray)
    }
  }

  // 白名单管理（吕）
  @Builder WhitelistBuilder() {
    Row() {
      Column() {
        Text("白名单管理")
          .fontSize(17)
        Text("允许直接访问的学习站点")
          .fontSize(11)
          .fontColor(Color.Gray)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({left: 15})
      Text(`共 ${StudyModeRules.parseWhitelist(this.studyWhitelistJson).length} 项`)
        .margin({right: 15})
        .fontSize(12)
        .fontColor("#45A5FF")
    }
    .height(this.itemHeight + 10)
    .width("100%")
    .justifyContent(FlexAlign.SpaceBetween)
    .onClick(() => {
      this.showWhitelist = true
    })
  }

  // 阅读器模式开关（许）
  @Builder ReaderModeBuilder() {
    Row() {
      Column({ space: 2 }) {
        Text("阅读器模式")
          .fontSize(17)
          .fontColor(Color.Black)
        if (this.readerDetectLoading) {
          Text("识别中...")
            .fontSize(11)
            .fontColor("#45A5FF")
        } else {
          Text(this.readerFeatureAvailable ? `当前页面可阅读 (${Math.round(this.readerConfidence * 100)}%)` : "当前页面不可用")
            .fontSize(11)
            .fontColor(this.readerFeatureAvailable ? "#45A5FF" : Color.Gray)
          if (!this.readerFeatureAvailable && this.readerUnsupportedReason.length > 0) {
            Text(`原因：${this.readerUnsupportedReason}`)
              .fontSize(10)
              .fontColor("#E67E22")
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
      }
      .margin({left: 15})
      .alignItems(HorizontalAlign.Start)

      Toggle({ type: ToggleType.Switch, isOn: this.readerModeEnabled })
        .margin({ right: 15 })
        .onChange((isOn: boolean) => {
          if (isOn && !this.readerFeatureAvailable) {
            this.readerModeEnabled = false
            const reason = this.readerUnsupportedReason.length > 0 ? this.readerUnsupportedReason : "识别结果未满足阈值"
            Prompt.showToast({ message: `当前页面暂不支持阅读器模式：${reason}` })
            return
          }
          this.readerModeEnabled = isOn
          Prompt.showToast({ message: isOn ? "已进入阅读器模式" : "已退出阅读器模式" })
        })
    }
    .height(54)
    .width("100%")
    .justifyContent(FlexAlign.SpaceBetween)
  }

  // 朗读入口（许）
  @Builder TtsEntryBuilder() {
    Row() {
      Text("朗读页面")
        .margin({left: 15})
        .fontSize(17)

      Button("开始")
        .type(ButtonType.Capsule)
        .height(30)
        .fontSize(12)
        .margin({ right: 15 })
        .enabled(true)
        .opacity(1)
        .onClick(() => {
          this.ttsRequestToken = this.ttsRequestToken + 1
        })
    }
    .height(this.itemHeight)
    .width("100%")
    .justifyContent(FlexAlign.SpaceBetween)
  }

  // 清除浏览记录
  @Builder ClearHistoryBuilder() {
    Row() {
      Text("清除浏览记录")
        .margin({left: 15})
        .fontSize(17)
        .onClick(() => {
          try {
            this.promptAction.showDialog({
              title: "提示",
              message: "确定要删除所有浏览记录？",
              alignment: DialogAlignment.Bottom,
              buttons: [
                {
                  text: "取消",
                  color: "#E62E31"
                },
                {
                  text: "确定",
                  color: "#45A5FF"
                }
              ]
            }, (error, data) => {
              if (error) {
                console.error(`弹窗异常：${error}`)
                return
              }
              if (data.index === 1) {
                this.onConfirm()
              }
            })
          } catch (error) {
            console.error(`弹出提示框异常：${error}`)
          }
        })
    }
    .height(this.itemHeight)
    .width("100%")
    .justifyContent(FlexAlign.SpaceBetween)
  }

  // 关于我们
  @Builder AboutBuilder() {
    Row() {
      Text("关于我们")
        .margin({left: 15})
        .fontSize(17)
      Text(CommonConstants.APP_NAME + " " + CommonConstants.VERSION)
        .margin({right: 15})
        .fontSize(10)
        .fontColor(Color.Gray)
    }
    .height(this.itemHeight)
    .width("100%")
    .justifyContent(FlexAlign.SpaceBetween)
  }
}