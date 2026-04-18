// pages/Index.ets
import webview from '@ohos.web.webview'
import CommonConstants from "../common/constants/CommonConstants"
import { FunctionButtons } from '../common/bean/FunctionButtons'
import History from '../common/bean/History'
import window from '@ohos.window'
import { inputMethod } from '@kit.IMEKit'
import RdbUtils from '../utils/RdbUtils'
import { TabManager } from '../model/TabManager'
import { TabModel } from '../model/TabModel'

PersistentStorage.PersistProp("privateMode", false)
PersistentStorage.PersistProp("currentEngineIndex", 0)
PersistentStorage.PersistProp("currentEngineName", "Bing")
PersistentStorage.PersistProp("darkMode", false)

@Entry
@Component
struct Index {
  @State url: string = ""
  @State isShowed: Visibility = Visibility.None
  @State high: string = "10%"
  @State textAlign: TextAlign = TextAlign.Start
  @State keyboardHeight: number = 0
  @State isShowMask: boolean = false
  @State currentProgress: number = 0
  @State isBacked: boolean = false
  @State isForwarded: boolean = false

  @Provide("historyMap") historyMap: Map<string, History[]> = new Map()
  @Provide webviewController: webview.WebviewController = new webview.WebviewController()
  @Provide("webIsSearched") @Watch("onSearched") isSearched: boolean = false

  @StorageLink("privateMode") privateMode: boolean = false
  @StorageLink("darkMode") darkMode: boolean = false
  @StorageLink("currentEngineIndex") searchEngine: number = 0

  private windowClass: window.Window | null = null
  private textInputController: TextInputController = new TextInputController()
  private inputMethodController: inputMethod.InputMethodController = inputMethod.getController()

  // 多标签页管理
  private tabManager: TabManager = new TabManager()
  @State tabs: TabModel[] = []
  @State currentIndex: number = 0
  @Provide('tabManager') providedTabManager: TabManager = this.tabManager   // 提供给子组件

  async aboutToAppear() {
    console.debug("项目正在启动")

    // 加载历史记录
    const allDate: string[] = await RdbUtils.queryAllDate()
    for (const date of allDate) {
      this.historyMap.set(date, await RdbUtils.queryHistoriesByDate(date))
    }

    // 创建收藏夹表格
    await RdbUtils.createBookmarkTable()

    // 创建初始标签页（空白页）
    const firstTab = this.tabManager.newTab('about:blank', '新标签页')
    this.tabs = this.tabManager.getTabs()
    this.currentIndex = 0
    this.url = firstTab.url

    // 键盘监听
    window.getLastWindow(getContext(this), (err, data) => {
      if (err) {
        console.log(err.message)
      }
      this.windowClass = data
      this.windowClass.on("keyboardHeightChange", (data) => {
        this.keyboardHeight = data
      })
    })

    console.debug("项目已启动")
  }

  // 保存浏览记录
  async onSaveHistory() {
    try {
      const now = new Date()
      const date = `${now.getFullYear()}_${(now.getMonth() + 1).toString().padStart(2, '0')}_${now.getDate().toString().padStart(2, '0')}`
      await RdbUtils.insertDate(date)
      const timestamp = `${now.getFullYear()}_${(now.getMonth() + 1).toString().padStart(2, '0')}_${now.getDate().toString().padStart(2, '0')} ${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`
      const history = new History(this.webviewController.getTitle(), this.webviewController.getUrl(), timestamp)
      if (!this.historyMap.has(date)) {
        this.historyMap.set(date, [])
      }
      this.historyMap.get(date)?.unshift(history)
      await RdbUtils.insertHistory(date, history)
      console.info("保存浏览记录成功")
    } catch (error) {
      console.error("保存浏览记录异常：" + error)
    }
  }

  private checkContent(content: string): boolean {
    return content.endsWith(".com") || content.endsWith(".cn") || content.endsWith(".tv")
  }

  onSearched() {
    this.isShowed = Visibility.Visible
    this.high = "91%"
    this.textAlign = TextAlign.Center
  }

  build() {
    Flex({ direction: FlexDirection.Column, alignItems: ItemAlign.Center }) {
      Column() {
        Column() {
          if (!this.isSearched) {
            Row() {
              Image($r("app.media.app_icon"))
                .width(30)
                .height(30)
                .margin({ bottom: 25, right: 10 })
              Text(CommonConstants.APP_NAME)
                .fontSize(25)
                .fontColor(!this.darkMode ? Color.Black : Color.White)
                .margin({ bottom: 25 })
                .animation({ duration: 300 })
            }
            .width("100%")
            .height("100%")
            .justifyContent(FlexAlign.Center)
          }
          // 网页内容区域（单 Web 实例）
          Web({ src: this.url, controller: this.webviewController })
            .width("100%")
            .height("100%")
            .visibility(this.isShowed)
            .animation({ duration: 300 })
            .onProgressChange((event) => {
              this.currentProgress = event.newProgress
            })
            .onPageEnd(async () => {
              try {
                this.url = this.webviewController.getUrl()
                // 更新当前标签页信息
                const currentTab = this.tabManager.getCurrentTab()
                if (currentTab) {
                  currentTab.url = this.url
                  currentTab.title = this.webviewController.getTitle()
                  // 刷新 tabs 数组以更新 UI（例如标签页管理对话框中的标题）
                  this.tabs = [...this.tabManager.getTabs()]
                }
                if (!this.privateMode) {
                  await this.onSaveHistory()
                }
              } catch (error) {
                console.log("获取 Url 异常：" + error)
              }
            })
            .onRefreshAccessedHistory(() => {
              try {
                this.isBacked = this.webviewController.accessBackward()
                this.isForwarded = this.webviewController.accessForward()
              } catch (error) {
                console.log("更新前进或后退状态异常：" + error)
              }
            })
        }
        .width("100%")
        .height(this.high)
        .justifyContent(FlexAlign.Center)
        .animation({ duration: 300 })

        Stack({ alignContent: Alignment.Bottom }) {
          Search({ placeholder: "搜索或输入网址", value: this.url, controller: this.textInputController })
            .width("90%")
            .height("8%")
            .size({ height: 50 })
            .margin({ top: 5, bottom: 10, left: 5, right: 5 })
            .textAlign(this.textAlign)
            .backgroundColor(!this.darkMode ? "#E8E8E8" : "#696969")
            .zIndex(3)
            .animation({ duration: 300 })
            .onClick(() => {
              this.inputMethodController.showSoftKeyboard()
              if (this.isSearched) {
                this.textInputController.setTextSelection(0, this.url.length)
              }
            })
            .onEditChange((isEditing: boolean) => {
              this.isShowMask = isEditing
            })
            .onSubmit((value) => {
              try {
                if (this.checkContent(value)) {
                  this.webviewController.loadUrl(value)
                } else {
                  this.webviewController.loadUrl(CommonConstants.SEARCH_ENGINES[this.searchEngine].prefix + value)
                }
                this.url = this.webviewController.getOriginalUrl()
                // 更新当前标签页 URL
                const currentTab = this.tabManager.getCurrentTab()
                if (currentTab) {
                  currentTab.url = this.url
                  this.tabs = [...this.tabManager.getTabs()]
                }
                if (!this.isSearched) {
                  this.isSearched = true
                }
                this.inputMethodController.stopInputSession()
              } catch (error) {
                console.log("提交搜索时异常：" + error)
              }
            })

          Progress({ value: this.currentProgress, type: ProgressType.Linear })
            .visibility(this.currentProgress === 100 || this.currentProgress === 0 ? Visibility.None : Visibility.Visible)
            .animation({ duration: 100 })
        }
      }
      .width("100%")
      .layoutWeight(11)
      .justifyContent(FlexAlign.Center)

      FunctionButtons({ isBacked: $isBacked, isForward: $isForwarded })
        .width("100%")
        .margin({ top: 5 })
        .layoutWeight(1)

      if (this.isShowMask) {
        Column()
          .width("100%")
          .height("100%")
          .position({ x: 0, y: 0 })
          .backgroundColor('rgba(0,0,0,0.3)')
          .onClick(() => {
            this.isShowMask = false
            this.inputMethodController.stopInputSession()
          })
          .zIndex(2)
      }
    }
    .width("100%")
    .height("100%")
    .backgroundColor(!this.darkMode ? Color.White : "#1C1C1C")
    .animation({ duration: 300 })
  }
}