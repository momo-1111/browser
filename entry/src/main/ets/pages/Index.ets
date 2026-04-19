import webview from '@ohos.web.webview'
import { Prompt } from '@kit.ArkUI'
import CommonConstants from "../common/constants/CommonConstants"
import { FunctionButtons } from '../common/bean/FunctionButtons'
import History from '../common/bean/History'
import window from '@ohos.window'
import { inputMethod } from '@kit.IMEKit'
import RdbUtils from '../utils/RdbUtils'
import DomainUtils from '../utils/DomainUtils'
import RequestPolicy, { PolicyConfig } from '../utils/RequestPolicy'
import StudyModeRules from '../utils/StudyModeRules'

// 持久化数据
PersistentStorage.PersistProp("privateMode", false)
PersistentStorage.PersistProp("currentEngineIndex", 0)
PersistentStorage.PersistProp("currentEngineName", "Bing")
PersistentStorage.PersistProp("darkMode", false)
PersistentStorage.PersistProp("studyModeEnabled", false)
PersistentStorage.PersistProp("studyWhitelistJson", CommonConstants.DEFAULT_STUDY_WHITELIST_JSON)

@Entry
@Component
struct Index {
  // 绑定搜索框内显示的 URL 地址
  @State url: string = ""
  // 绑定 Web 组件的显示状态,默认为隐藏
  @State isShowed: Visibility = Visibility.None

  @State high: string = "10%"
  // 绑定搜索框内的文本对齐方式,默认为左对齐
  @State textAlign: TextAlign = TextAlign.Start
  // 绑定搜索框是否聚焦
  // @State isInputFocused: boolean = false
  // 绑定键盘高度
  @State keyboardHeight: number = 0
  // 绑定是否显示遮罩层
  @State isShowMask: boolean = false
  // 绑定当前页面加载进度
  @State currentProgress: number = 0
  // 绑定当前页面是否可回退
  @State isBacked: boolean = false
  // 绑定当前页面是否可前进
  @State isForwarded: boolean = false
  @State pendingTopLevelUrl: string = ""
  @State lastBlockedMainFrameUrl: string = ""
  @State skipNextHistorySave: boolean = false

  // 历史浏览记录
  @Provide("historyMap") historyMap: Map<string, History[]> = new Map()

  @Provide webviewController: webview.WebviewController = new webview.WebviewController()
  // 是否进行过搜索，用于判断是否显示 Web 组件
  @Provide("webIsSearched") @Watch("onSearched") isSearched: boolean = false

  // 从 AppStore 中获取持久化数据
  // privateMode 表示当前是否为隐私模式
  @StorageLink("privateMode") privateMode: boolean = false
  // darkMode 表示当前是否为夜间模式
  @StorageLink("darkMode") darkMode: boolean = false
  // currentEngineIndex 表示当前的搜索引擎的索引
  @StorageLink("currentEngineIndex") searchEngine: number = 0
  @StorageLink("studyModeEnabled") studyModeEnabled: boolean = false
  @StorageLink("studyWhitelistJson") studyWhitelistJson: string = CommonConstants.DEFAULT_STUDY_WHITELIST_JSON

  private windowClass: window.Window | null = null

  private textInputController: TextInputController = new TextInputController()

  // 获取输入法实例
  private inputMethodController: inputMethod.InputMethodController = inputMethod.getController()

  async aboutToAppear() {
    console.debug("项目正在启动")

    const allDate: string[] = await RdbUtils.queryAllDate()

    allDate.forEach(async date => {
      this.historyMap.set(date, await RdbUtils.queryHistoriesByDate(date))
    })

    // 开启软键盘高度变化的监听
    window.getLastWindow(getContext(this), (err, data) => {
      if (err) {
        console.log(err.message)
      }
      this.windowClass = data
      this.windowClass.on("keyboardHeightChange", (data) => {
        this.keyboardHeight = data
        console.log(this.keyboardHeight.toString())
      })
    })

    console.debug("项目已启动")
  }

  // 保存浏览记录
  async onSaveHistory() {
    try {
      // 生成当前时间格式
      const now = new Date()

      const date = `${now.getFullYear().toString()}_${(now.getMonth() + 1).toString().padStart(2, '0')}_${now.getDate().toString().padStart(2, '0')}`

      await RdbUtils.insertDate(date)

      const timestamp = `${now.getFullYear().toString()}_${(now.getMonth() + 1).toString().padStart(2, '0')}_${now.getDate().toString().padStart(2, '0')} ${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`

      const history = new History(this.webviewController.getTitle(), this.webviewController.getUrl(), timestamp)

      // 判断是否有该日期
      if (!this.historyMap.has(date)) {
        this.historyMap.set(date, [])
      }

      this.historyMap.get(date)?.unshift(history)

      await RdbUtils.insertHistory(date, history)

      console.info("保存浏览记录成功")
    } catch (error) {
      // TODO: Implement error handling.
      console.error("保存浏览记录异常：" + error)
    }
  }

  private getPolicyConfig(): PolicyConfig {
    const enginePrefix = CommonConstants.SEARCH_ENGINES[this.searchEngine].prefix
    const engineHost = DomainUtils.extractHostFromPrefix(enginePrefix)
    return {
      studyModeEnabled: this.studyModeEnabled,
      whitelist: StudyModeRules.parseWhitelist(this.studyWhitelistJson),
      currentSearchEngineHost: engineHost
    }
  }

  private showPolicyToast(message: string) {
    Prompt.showToast({
      message
    })
  }

  private getCurrentTopLevelUrl(): string {
    if (this.pendingTopLevelUrl.length > 0) {
      return this.pendingTopLevelUrl
    }
    return this.url
  }

  private navigateWithPolicy(content: string) {
    const targetUrl = DomainUtils.resolveInputToUrl(content, CommonConstants.SEARCH_ENGINES[this.searchEngine].prefix)
    const decision = RequestPolicy.evaluateNavigation(targetUrl, this.getPolicyConfig())

    if (decision.action === "block") {
      this.showPolicyToast(decision.message)
      this.inputMethodController.stopInputSession()
      return
    }

    this.pendingTopLevelUrl = targetUrl
    this.skipNextHistorySave = false
    this.lastBlockedMainFrameUrl = ""
    this.webviewController.loadUrl(targetUrl)
    this.url = targetUrl

    if (!this.isSearched) {
      this.isSearched = true
    }

    this.inputMethodController.stopInputSession()
  }

  private buildBlockedPageResponse(message: string): WebResourceResponse {
    const response = new WebResourceResponse()
    response.setResponseData(`<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Blocked</title>
</head>
<body style="margin:0;font-family:sans-serif;background:#f7f8fa;display:flex;align-items:center;justify-content:center;min-height:100vh;color:#1f2329;">
  <div style="max-width:280px;padding:24px;border-radius:18px;background:#ffffff;box-shadow:0 10px 30px rgba(0,0,0,0.08);text-align:center;">
    <div style="font-size:18px;font-weight:600;margin-bottom:12px;">学习模式已拦截</div>
    <div style="font-size:14px;line-height:1.6;">${message}</div>
  </div>
</body>
</html>`)
    response.setResponseEncoding('utf-8')
    response.setResponseMimeType('text/html')
    response.setResponseCode(403)
    response.setReasonMessage('Blocked')
    response.setResponseIsReady(true)
    return response
  }

  private buildEmptyBlockedResponse(): WebResourceResponse {
    const response = new WebResourceResponse()
    response.setResponseData("")
    response.setResponseEncoding('utf-8')
    response.setResponseMimeType('text/plain')
    response.setResponseCode(403)
    response.setReasonMessage('Blocked')
    response.setResponseIsReady(true)
    return response
  }

  onSearched() {
    this.isShowed = Visibility.Visible
    this.high = "91%"
    this.textAlign = TextAlign.Center
  }

  build() {
    Flex({ direction: FlexDirection.Column , alignItems: ItemAlign.Center}) {
      Column() {
        Column() {
          if (!this.isSearched) {
            // logo 显示
            Row() {
              Image($r("app.media.app_icon"))
                .width(30)
                .height(30)
                .margin({ bottom: 25, right: 10 })
              Text(CommonConstants.APP_NAME)
                .fontSize(25)
                .fontColor(!this.darkMode? Color.Black : Color.White)
                .margin({ bottom: 25 })
                .animation({
                  duration: 300
                })
            }
            .width("100%")
            .height("100%")
            .justifyContent(FlexAlign.Center)
          }
          // 网页内容区域
          Web({ src: this.url, controller: this.webviewController })
            .width("100%")
            .height("100%")
            .visibility(this.isShowed)
            .animation({
              duration: 300
            })
            .onInterceptRequest((event) => {
              if (!event) {
                return null
              }

              const requestUrl = event.request.getRequestUrl()
              const isMainFrame = event.request.isMainFrame()
              const topLevelUrl = isMainFrame ? requestUrl : this.getCurrentTopLevelUrl()
              const decision = RequestPolicy.evaluateRequest(requestUrl, topLevelUrl, this.getPolicyConfig(), isMainFrame)

              if (decision.action === "allow") {
                if (isMainFrame) {
                  this.pendingTopLevelUrl = requestUrl
                }
                return null
              }

              console.info(`学习模式拦截请求: ${requestUrl}`)
              if (isMainFrame) {
                this.pendingTopLevelUrl = requestUrl
                this.skipNextHistorySave = true
                if (this.lastBlockedMainFrameUrl !== requestUrl) {
                  this.lastBlockedMainFrameUrl = requestUrl
                  this.showPolicyToast(decision.message)
                }
                return this.buildBlockedPageResponse(decision.message)
              }

              return this.buildEmptyBlockedResponse()
            })
            .onProgressChange((event) => {
              this.currentProgress = event.newProgress
            }) // 回调，监视当前页面加载情况
            .onPageEnd(async () => {
              try {
                this.url = this.webviewController.getUrl()
                this.pendingTopLevelUrl = this.url
                if (this.skipNextHistorySave) {
                  this.skipNextHistorySave = false
                  return
                }
                if (!this.privateMode) {
                  await this.onSaveHistory()
                }
              } catch (error) {
                // TODO: Implement error handling.
                console.log("获取 Url 异常：" + error)
              }
            }) // 回调：页面加载成功则读取 url ，交给 savehistory 持久化
            .onRefreshAccessedHistory(() => {
              try {
                this.isBacked = this.webviewController.accessBackward()
                this.isForwarded = this.webviewController.accessForward()
              } catch (error) {
                // TODO: Implement error handling.
                console.log("更新前进或后退状态异常：" + error)
              }
            })
        }
        .width("100%")
        .height(this.high)
        .justifyContent(FlexAlign.Center)
        .animation({
          duration: 300
        })

        Stack({ alignContent: Alignment.Bottom }) {
          // 地址栏
          Search({ placeholder: "搜索或输入网址", value: this.url, controller: this.textInputController})
            .width("90%")
            .height("8%")
            .size({ height: 50 })
            .margin({ top: 5, bottom: 10, left: 5, right: 5})
            .textAlign(this.textAlign)
            .backgroundColor(!this.darkMode? "#E8E8E8" : "#696969")
            .zIndex(3)
            .animation({
              duration: 300
            })
            .onClick(() => {
              // 唤起软键盘
              this.inputMethodController.showSoftKeyboard()
              // 默认全选文本
              if (this.isSearched) {
                this.textInputController.setTextSelection(0, this.url.length)
              }
            })
            // 输入状态变化时
            .onEditChange((isEditing: boolean) => {
              // this.isInputFocused = isEditing;
              this.isShowMask = isEditing;
            })
            // 提交搜索时
            .onSubmit((value) => {
              try {
                this.navigateWithPolicy(value)
              } catch (error) {
                console.log("提交搜索时异常：" + error)
              }
            })
          // 网页加载进度条
          Progress({ value: this.currentProgress, type: ProgressType.Linear })
            .visibility(this.currentProgress === 100 || this.currentProgress === 0 ? Visibility.None : Visibility.Visible)
            .animation({
              duration: 100
            })
        }
      }
      .width("100%")
      .layoutWeight(11)
      .justifyContent(FlexAlign.Center)
      // 底部按钮
      FunctionButtons({ isBacked: $isBacked, isForward: $isForwarded })
        .width("100%")
        .margin({ top: 5 })
        .layoutWeight(1)
      // 遮罩层
      if (this.isShowMask) {
        Column()
          .width("100%")
          .height("100%")
          .position({ x: 0, y: 0 })
          .backgroundColor('rgba(0,0,0,0.3)')
          .onClick(() => {
            // 点击外部区域时收起软键盘
            this.isShowMask = false;
            // 收起软键盘
            this.inputMethodController.stopInputSession()
          })
          .zIndex(2)
      }
    }
    .width("100%")
    .height("100%")
    .backgroundColor(!this.darkMode? Color.White : "#1C1C1C")
    .animation({
      duration: 300
    })
  }
}
