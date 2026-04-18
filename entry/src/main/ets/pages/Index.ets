import webview from '@ohos.web.webview'
import CommonConstants from "../common/constants/CommonConstants"
import { FunctionButtons } from '../common/bean/FunctionButtons'
import History from '../common/bean/History'
import window from '@ohos.window'
import { inputMethod } from '@kit.IMEKit'
import RdbUtils from '../utils/RdbUtils'
import { fileUri } from '@kit.CoreFileKit';
import { promptAction } from '@kit.ArkUI'; // 改为 promptAction
import UserCenter from '../view/BookmarkDialog'
import Bookmark from '../common/bean/Bookmark'

// 持久化数据
PersistentStorage.PersistProp("privateMode", false)
PersistentStorage.PersistProp("currentEngineIndex", 0)
PersistentStorage.PersistProp("currentEngineName", "Bing")
PersistentStorage.PersistProp("darkMode", false)
PersistentStorage.PersistProp("userId", "guest") // 模拟账户关联 ID

PersistentStorage.PersistProp("nickname", "小狐狸用户")
PersistentStorage.PersistProp("avatarPath", "") // 存储头像在应用沙盒里的本地路径


@Entry
@Component
struct Index {
  // 绑定搜索框内显示的url地址
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

  // 历史浏览记录
  @StorageLink("userId") @Watch("onUserChanged") userId: string = "guest";

  @Provide("historyMap") @Watch("onHistoryChange") historyMap: Map<string, History[]> = new Map();


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
  @State isUserCenterShow: boolean = false // 控制个人中心显示
  // 新增监听：当主页需要加载来自历史页的跳转时
  @StorageLink("targetUrl") targetUrl: string = "" // 移除这里的 @Watch
  @StorageLink("nickname") nickname: string = "小狐狸用户"
  @StorageLink("avatarPath") avatarPath: string = ""

  delegate: webview.WebDownloadDelegate = new webview.WebDownloadDelegate();

  // 1. 用户变更监听
  async onUserChanged() {
    console.info("用户切换，准备加载个人资料: " + this.userId)

    // 1. 加载历史记录 (之前的逻辑)
    await this.refreshHistoryData()

    // 2. 加载个人资料
    const profile = await RdbUtils.queryProfile(this.userId)
    if (profile) {
      this.nickname = profile.nickname
      this.avatarPath = profile.avatarPath
    } else {
      // 如果是新用户或 guest，设置默认值
      this.nickname = this.userId === "guest" ? "小狐狸用户" : "华为新用户"
      this.avatarPath = ""
    }
  }

  // 2. 刷新数据逻辑
  async refreshHistoryData() {
    try {
      const allDate: string[] = await RdbUtils.queryAllDate();
      // 关键：创建一个全新的 Map 实例
      let newMap = new Map<string, History[]>();

      for (const date of allDate) {
        const list = await RdbUtils.queryHistoriesByDate(date, this.userId);
        if (list.length > 0) {
          newMap.set(date, list);
        }
      }

      // 关键：替换引用，触发 UI 刷新
      this.historyMap = newMap;
      // 同步到全局
      AppStorage.setOrCreate("globalHistoryMap", this.historyMap);
      console.info("[Index] 历史数据刷新完成，当前组数: " + this.historyMap.size);
    } catch (e) {
      console.error("[Index] 刷新历史失败: " + e.message);
    }
  }

  onPageShow() {
    console.info("Index PageShow, targetUrl: " + this.targetUrl);

    let target: string = AppStorage.get("targetUrl") || "";
    if (target !== "") {
      this.webviewController.loadUrl(target);
      this.isSearched = true;
      AppStorage.setOrCreate("targetUrl", ""); // 用完即清空
    }

    // 每次回到主页都检查一下，防止状态同步延迟
    if (this.historyMap.size === 0) {
      this.refreshHistoryData();
    }

    // 检查是否有待跳转的 URL
    if (this.targetUrl && this.targetUrl !== "") {

      // 1. 确保 Web 组件可见逻辑触发
      if (!this.isSearched) {
        this.isSearched = true;
        this.onSearched(); // 触发 UI 变换（高度、logo 隐藏等）
      }

      // 2. 执行加载。由于 ArkWeb 加载需要时间，建议稍微延迟 50ms 确保 Webview 已初始化
      setTimeout(() => {
        try {
          this.webviewController.loadUrl(this.targetUrl);
          this.url = this.targetUrl; // 同步地址栏文本

          // 3. 关键：加载完后立刻清空全局变量，防止下次打开主页又重复跳转
          AppStorage.setOrCreate("targetUrl", "");
        } catch (e) {
          console.error("加载 URL 失败: " + e);
        }
      }, 50)
    }
  }
  onHistoryChange() {
    AppStorage.SetOrCreate("globalHistoryMap", this.historyMap)
  }


  private windowClass: window.Window | null = null

  private textInputController: TextInputController = new TextInputController()

  // 获取输入法实例
  private inputMethodController: inputMethod.InputMethodController = inputMethod.getController()

  async aboutToAppear() {
    console.debug("项目正在启动")

    await RdbUtils.createDownloadTable(); // 初始化表
    this.initDownloadListener();
    // 初始化数据库表
    await RdbUtils.createProfileTable() // 初始化表
    await RdbUtils.createDateTable()
    // 如果你有书签功能，也在这里初始化
    await RdbUtils.createBookmarkTable()

    // ... 生成 date 和 history 的代码不变
    await this.refreshHistoryData();

    const allDate: string[] = await RdbUtils.queryAllDate()

    for (let date of allDate) {
      const histories = await RdbUtils.queryHistoriesByDate(date, this.userId)
      this.historyMap.set(date, histories)
    }
    // 手动触发一次同步
    this.onHistoryChange()

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

  initDownloadListener() {
    this.delegate.onBeforeDownload((item: webview.WebDownloadItem) => {
      // 设置下载到应用沙盒的 cache 目录
      const path = getContext(this).cacheDir + '/' + item.getSuggestedFileName();
      item.start(path);
    })

    this.delegate.onDownloadFinish(async (item: webview.WebDownloadItem) => {
      const fileName = item.getSuggestedFileName();
      const path = getContext(this).cacheDir + '/' + fileName;
      const uri = fileUri.getUriFromPath(path); // 生成内部 URI

      await RdbUtils.insertDownload(fileName, path, uri, "file", this.userId);
      promptAction.showToast({ message: "下载完成" });
    })

    this.webviewController.setDownloadDelegate(this.delegate);
  }
  // 保存浏览记录
  async onSaveHistory() {
    try {
      const now = new Date();
      const date = `${now.getFullYear()}_${(now.getMonth() + 1).toString().padStart(2, '0')}_${now.getDate().toString().padStart(2, '0')}`;

      await RdbUtils.insertDate(date);

      const timestamp = "刚才的时间格式...";
      const history = new History(this.webviewController.getTitle(), this.webviewController.getUrl(), timestamp);

      // 【关键】：保存时必须传入当前登录的 ID (或者是 "guest")
      console.info(`[Index] 准备保存历史，当前用户 ID: ${this.userId}`);
      await RdbUtils.insertHistory(date, history, this.userId);

      // 更新内存 Map
      if (!this.historyMap.has(date)) {
        this.historyMap.set(date, []);
      }
      this.historyMap.get(date)?.unshift(history);
      AppStorage.setOrCreate("globalHistoryMap", this.historyMap);

    } catch (error) {
      console.error("保存失败: " + error);
    }
  }

  // 判断用户输入的内容是否为网址
  private checkContent(content: string) {
    if (content.endsWith(".com") || content.endsWith(".cn") || content.endsWith(".tv")) {
      return true
    } else {
      return false
    }
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
            .onProgressChange((event) => {
              this.currentProgress = event.newProgress
            })
            .onPageEnd(async () => {
              try {
                this.url = this.webviewController.getUrl()
                if (!this.privateMode) {
                  await this.onSaveHistory()
                }
              } catch (error) {
                // TODO: Implement error handling.
                console.log("获取 Url 异常：" + error)
              }
            })
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
                if (this.checkContent(value)) {
                  this.webviewController.loadUrl(value)
                } else {
                  this.webviewController.loadUrl(CommonConstants.SEARCH_ENGINES[this.searchEngine].prefix + value)
                }

                this.url = this.webviewController.getOriginalUrl()

                //更改搜索框的搜索状态
                if (!this.isSearched) {
                  this.isSearched = true
                }

                // 收起软键盘
                this.inputMethodController.stopInputSession()
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
  // 在 Index 类中添加
  async toggleBookmark() {
    const currentTitle = this.webviewController.getTitle()
    const currentUrl = this.webviewController.getUrl()
    const history = new History(currentTitle, currentUrl, "")

    await RdbUtils.insertBookmark(history)
    // 可以加个 Toast 提示
  }
}