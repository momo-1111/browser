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
  @StorageLink("studyModeEnabled") studyModeEnabled: boolean = false
  @StorageLink("studyWhitelistJson") studyWhitelistJson: string = CommonConstants.DEFAULT_STUDY_WHITELIST_JSON

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
        this.StudyModeBuilder()
        this.WhitelistBuilder()
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
