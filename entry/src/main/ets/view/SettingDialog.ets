import History from '../common/bean/History'
import CommonConstants from '../common/constants/CommonConstants'
import { Prompt, PromptAction } from '@kit.ArkUI'

@CustomDialog
export default struct SettingDialog {
  @Consume("historyMap") historyMap: Map<string, History[]>

  // 从 AppStore 中获取持久化数据
  @StorageLink("currentEngineIndex") currentEngineIndex: number = 0
  @StorageLink("currentEngineName") currentEngineName: string = CommonConstants.SEARCH_ENGINES[0].engine
  @StorageLink("darkMode") darkMode: boolean = false
  @StorageLink("readerModeEnabled") readerModeEnabled: boolean = false
  @StorageLink("readerFeatureAvailable") readerFeatureAvailable: boolean = false
  @StorageLink("readerDetectLoading") readerDetectLoading: boolean = false
  @StorageLink("readerConfidence") readerConfidence: number = 0
  @StorageLink("readerUnsupportedReason") readerUnsupportedReason: string = ''
  @StorageLink("ttsRequestToken") ttsRequestToken: number = 0

  controller: CustomDialogController

  private searchEngine: SelectOption[] = []

  private itemHeight: number = 40

  promptAction: PromptAction = this.getUIContext().getPromptAction();

  async aboutToAppear() {
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
    Column() {
      this.EngineBuilder()
      this.DarkModeBuilder()
      this.ReaderModeBuilder()
      this.TtsEntryBuilder()
      this.ClearHistoryBuilder()
      this.AboutBuilder()
    }
    .padding({top: 5, bottom: 5})
  }

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

  // 设置深色模式 or 浅色模式
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
            // 根据开关状态显示不同消息
            message: isOn ? "深色模式已启用" : "深色模式已关闭",
          })
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