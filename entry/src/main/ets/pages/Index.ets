import webview from '@ohos.web.webview';
import { Prompt, promptAction } from '@kit.ArkUI';
import CommonConstants from '../common/constants/CommonConstants';
import { FunctionButtons } from '../common/bean/FunctionButtons';
import History from '../common/bean/History';
import window from '@ohos.window';
import { inputMethod } from '@kit.IMEKit';
import RdbUtils from '../utils/RdbUtils';
import DomainUtils from '../utils/DomainUtils';
import RequestPolicy, { PolicyConfig } from '../utils/RequestPolicy';
import StudyModeRules from '../utils/StudyModeRules';
import { fileUri } from '@kit.CoreFileKit';
import { TabManager } from '../model/TabManager';
import { TabModel } from '../model/TabModel';
import { WebLongPressHelper } from '../utils/WebLongPressHelper';
import emitter from '@ohos.events.emitter';

interface SwitchTabEventData {
  index: number;
}

// 持久化数据
PersistentStorage.PersistProp('privateMode', false);
PersistentStorage.PersistProp('currentEngineIndex', 0);
PersistentStorage.PersistProp('currentEngineName', 'Bing');
PersistentStorage.PersistProp('darkMode', false);
PersistentStorage.PersistProp('userId', 'guest');
PersistentStorage.PersistProp('nickname', '小狐狸用户');
PersistentStorage.PersistProp('avatarPath', '');
PersistentStorage.PersistProp('studyModeEnabled', false);
PersistentStorage.PersistProp('studyWhitelistJson', CommonConstants.DEFAULT_STUDY_WHITELIST_JSON);

@Entry
@Component
struct Index {
  // 绑定搜索框内显示的url地址
  @State url: string = '';
  // 绑定 Web 组件的显示状态,默认为隐藏
  @State isShowed: Visibility = Visibility.None;
  @State high: string = '10%';
  @State textAlign: TextAlign = TextAlign.Start;
  @State keyboardHeight: number = 0;
  @State isShowMask: boolean = false;
  @State currentProgress: number = 0;
  @State isBacked: boolean = false;
  @State isForwarded: boolean = false;
  @State pendingTopLevelUrl: string = '';
  @State lastBlockedMainFrameUrl: string = '';
  @State skipNextHistorySave: boolean = false;

  // 历史浏览记录（多用户隔离）
  @StorageLink('userId') @Watch('onUserChanged') userId: string = 'guest';
  @Provide('historyMap') @Watch('onHistoryChange') historyMap: Map<string, History[]> = new Map();

  @Provide webviewController: webview.WebviewController = new webview.WebviewController();
  @Provide('webIsSearched') @Watch('onSearched') isSearched: boolean = false;

  // 持久化配置
  @StorageLink('privateMode') privateMode: boolean = false;
  @StorageLink('darkMode') darkMode: boolean = false;
  @StorageLink('currentEngineIndex') searchEngine: number = 0;
  @StorageLink('studyModeEnabled') studyModeEnabled: boolean = false;
  @StorageLink('studyWhitelistJson') studyWhitelistJson: string = CommonConstants.DEFAULT_STUDY_WHITELIST_JSON;
  @StorageLink('targetUrl') targetUrl: string = '';
  @StorageLink('nickname') nickname: string = '小狐狸用户';
  @StorageLink('avatarPath') avatarPath: string = '';

  delegate: webview.WebDownloadDelegate = new webview.WebDownloadDelegate();
  private windowClass: window.Window | null = null;
  private textInputController: TextInputController = new TextInputController();
  private inputMethodController: inputMethod.InputMethodController = inputMethod.getController();
  private longPressHelper?: WebLongPressHelper;

  // 多标签页管理
  private tabManager: TabManager = new TabManager();
  @State tabs: TabModel[] = [];
  @State currentIndex: number = 0;
  @Provide('tabManager') providedTabManager: TabManager = this.tabManager;

  // ---------- 用户切换 & 历史刷新 ----------
  async onUserChanged() {
    console.info('用户切换，准备加载个人资料: ' + this.userId);
    await this.refreshHistoryData();

    const profile = await RdbUtils.queryProfile(this.userId);
    if (profile) {
      this.nickname = profile.nickname;
      this.avatarPath = profile.avatarPath;
    } else {
      this.nickname = this.userId === 'guest' ? '小狐狸用户' : '华为新用户';
      this.avatarPath = '';
    }
  }

  async refreshHistoryData() {
    try {
      const allDate: string[] = await RdbUtils.queryAllDate();
      let newMap = new Map<string, History[]>();

      for (const date of allDate) {
        const list = await RdbUtils.queryHistoriesByDate(date, this.userId);
        if (list.length > 0) {
          newMap.set(date, list);
        }
      }

      this.historyMap = newMap;
      AppStorage.setOrCreate('globalHistoryMap', this.historyMap);
      console.info('[Index] 历史数据刷新完成，当前组数: ' + this.historyMap.size);
    } catch (e) {
      console.error('[Index] 刷新历史失败: ' + e.message);
    }
  }

  onHistoryChange() {
    AppStorage.setOrCreate('globalHistoryMap', this.historyMap);
  }

  // ---------- 标签页切换 ----------
  private switchToTab(index: number) {
    if (index < 0 || index >= this.tabs.length) return;
    this.currentIndex = index;
    this.tabManager.switchTo(index);
    const currentTab = this.tabManager.getCurrentTab();
    if (currentTab) {
      this.url = currentTab.url;
      this.isBacked = currentTab.canGoBack;
      this.isForwarded = currentTab.canGoForward;
      if (currentTab.url === 'about:blank') {
        this.isSearched = false;
        if (this.webviewController.getUrl() !== 'about:blank') {
          this.webviewController.loadUrl('about:blank');
        }
      } else {
        this.isSearched = true;
        if (this.webviewController.getUrl() !== currentTab.url) {
          this.webviewController.loadUrl(currentTab.url);
        }
      }
    }
  }

  // ---------- 生命周期 ----------
  async aboutToAppear() {
    console.debug('项目正在启动');

    await RdbUtils.createDownloadTable();
    this.initDownloadListener();
    await RdbUtils.createProfileTable();
    await RdbUtils.createDateTable();
    await RdbUtils.createBookmarkTable();

    await this.refreshHistoryData();

    const allDate: string[] = await RdbUtils.queryAllDate();
    for (let date of allDate) {
      const histories = await RdbUtils.queryHistoriesByDate(date, this.userId);
      this.historyMap.set(date, histories);
    }
    this.onHistoryChange();

    // 新建标签页
    const firstTab = this.tabManager.newTab('about:blank', '新标签页');
    this.tabs = this.tabManager.getTabs();
    this.currentIndex = 0;
    this.switchToTab(0);

    window.getLastWindow(getContext(this), (err, data) => {
      if (err) {
        console.log(err.message);
      }
      this.windowClass = data;
      this.windowClass.on('keyboardHeightChange', (data) => {
        this.keyboardHeight = data;
        console.log(this.keyboardHeight.toString());
      });
    });

    emitter.on('switchTab', (data?: emitter.EventData) => {
      const eventData = data?.data as SwitchTabEventData;
      if (eventData && eventData.index !== undefined) {
        this.switchToTab(eventData.index);
      }
    });

    this.longPressHelper = new WebLongPressHelper(this.webviewController, this.tabManager, this.getUIContext());
    console.debug('项目已启动');
  }

  onPageShow() {
    console.info('Index PageShow, targetUrl: ' + this.targetUrl);

    let target: string = AppStorage.get('targetUrl') || '';
    if (target !== '') {
      this.webviewController.loadUrl(target);
      this.isSearched = true;
      AppStorage.setOrCreate('targetUrl', '');
    }

    if (this.historyMap.size === 0) {
      this.refreshHistoryData();
    }

    if (this.targetUrl && this.targetUrl !== '') {
      if (!this.isSearched) {
        this.isSearched = true;
        this.onSearched();
      }
      setTimeout(() => {
        try {
          this.webviewController.loadUrl(this.targetUrl);
          this.url = this.targetUrl;
          AppStorage.setOrCreate('targetUrl', '');
        } catch (e) {
          console.error('加载 URL 失败: ' + e);
        }
      }, 50);
    }
  }

  // ---------- 下载监听 ----------
  initDownloadListener() {
    this.delegate.onBeforeDownload((item: webview.WebDownloadItem) => {
      const path = getContext(this).cacheDir + '/' + item.getSuggestedFileName();
      item.start(path);
    });

    this.delegate.onDownloadFinish(async (item: webview.WebDownloadItem) => {
      const fileName = item.getSuggestedFileName();
      const path = getContext(this).cacheDir + '/' + fileName;
      const uri = fileUri.getUriFromPath(path);
      await RdbUtils.insertDownload(fileName, path, uri, 'file', this.userId);
      promptAction.showToast({ message: '下载完成' });
    });

    this.webviewController.setDownloadDelegate(this.delegate);
  }

  // ---------- 保存浏览记录 ----------
  async onSaveHistory() {
    try {
      const now = new Date();
      const date = `${now.getFullYear()}_${(now.getMonth() + 1).toString().padStart(2, '0')}_${now.getDate().toString().padStart(2, '0')}`;
      await RdbUtils.insertDate(date);

      const timestamp = `${now.getFullYear()}_${(now.getMonth() + 1).toString().padStart(2, '0')}_${now.getDate().toString().padStart(2, '0')} ${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;
      const history = new History(this.webviewController.getTitle(), this.webviewController.getUrl(), timestamp);

      await RdbUtils.insertHistory(date, history, this.userId);

      if (!this.historyMap.has(date)) {
        this.historyMap.set(date, []);
      }
      this.historyMap.get(date)?.unshift(history);
      AppStorage.setOrCreate('globalHistoryMap', this.historyMap);
    } catch (error) {
      console.error('保存失败: ' + error);
    }
  }

  // ---------- 书签 ----------
  async toggleBookmark() {
    const currentTitle = this.webviewController.getTitle();
    const currentUrl = this.webviewController.getUrl();
    const history = new History(currentTitle, currentUrl, '');
    await RdbUtils.insertBookmark(history);
    promptAction.showToast({ message: '已添加到书签' });
  }

  // ---------- 学习模式策略 ----------
  private getPolicyConfig(): PolicyConfig {
    const enginePrefix = CommonConstants.SEARCH_ENGINES[this.searchEngine].prefix;
    const engineHost = DomainUtils.extractHostFromPrefix(enginePrefix);
    return {
      studyModeEnabled: this.studyModeEnabled,
      whitelist: StudyModeRules.parseWhitelist(this.studyWhitelistJson),
      currentSearchEngineHost: engineHost
    };
  }

  private showPolicyToast(message: string) {
    Prompt.showToast({ message });
  }

  private getCurrentTopLevelUrl(): string {
    if (this.pendingTopLevelUrl.length > 0) {
      return this.pendingTopLevelUrl;
    }
    return this.url;
  }

  private navigateWithPolicy(content: string) {
    const targetUrl = DomainUtils.resolveInputToUrl(content, CommonConstants.SEARCH_ENGINES[this.searchEngine].prefix);
    const decision = RequestPolicy.evaluateNavigation(targetUrl, this.getPolicyConfig());

    if (decision.action === 'block') {
      this.showPolicyToast(decision.message);
      this.inputMethodController.stopInputSession();
      return;
    }

    this.pendingTopLevelUrl = targetUrl;
    this.skipNextHistorySave = false;
    this.lastBlockedMainFrameUrl = '';
    this.webviewController.loadUrl(targetUrl);
    this.url = targetUrl;

    // 更新当前标签页的 URL
    const currentTab = this.tabManager.getCurrentTab();
    if (currentTab) {
      currentTab.url = targetUrl;
      currentTab.title = '';
      this.tabs = [...this.tabManager.getTabs()];
    }

    if (!this.isSearched) {
      this.isSearched = true;
    }

    this.inputMethodController.stopInputSession();
  }

  private buildBlockedPageResponse(message: string): WebResourceResponse {
    const response = new WebResourceResponse();
    response.setResponseData(`<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Blocked</title></head>
<body style="margin:0;font-family:sans-serif;background:#f7f8fa;display:flex;align-items:center;justify-content:center;min-height:100vh;color:#1f2329;">
  <div style="max-width:280px;padding:24px;border-radius:18px;background:#ffffff;box-shadow:0 10px 30px rgba(0,0,0,0.08);text-align:center;">
    <div style="font-size:18px;font-weight:600;margin-bottom:12px;">学习模式已拦截</div>
    <div style="font-size:14px;line-height:1.6;">${message}</div>
  </div>
</body>
</html>`);
    response.setResponseEncoding('utf-8');
    response.setResponseMimeType('text/html');
    response.setResponseCode(403);
    response.setReasonMessage('Blocked');
    response.setResponseIsReady(true);
    return response;
  }

  private buildEmptyBlockedResponse(): WebResourceResponse {
    const response = new WebResourceResponse();
    response.setResponseData('');
    response.setResponseEncoding('utf-8');
    response.setResponseMimeType('text/plain');
    response.setResponseCode(403);
    response.setReasonMessage('Blocked');
    response.setResponseIsReady(true);
    return response;
  }

  onSearched() {
    this.isShowed = Visibility.Visible;
    this.high = '91%';
    this.textAlign = TextAlign.Center;
  }

  // ---------- 构建 UI ----------
  build() {
    Flex({ direction: FlexDirection.Column, alignItems: ItemAlign.Center }) {
      Column() {
        Column() {
          if (!this.isSearched) {
            Row() {
              Image($r('app.media.app_icon'))
                .width(30)
                .height(30)
                .margin({ bottom: 25, right: 10 });
              Text(CommonConstants.APP_NAME)
                .fontSize(25)
                .fontColor(!this.darkMode ? Color.Black : Color.White)
                .margin({ bottom: 25 })
                .animation({ duration: 300 });
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center);
          }

          Web({ src: this.url, controller: this.webviewController })
            .width('100%')
            .height('100%')
            .visibility(this.isShowed)
            .animation({ duration: 300 })
            .onInterceptRequest((event) => {
              if (!event) {
                return null;
              }

              const requestUrl = event.request.getRequestUrl();
              const isMainFrame = event.request.isMainFrame();
              const topLevelUrl = isMainFrame ? requestUrl : this.getCurrentTopLevelUrl();
              const decision = RequestPolicy.evaluateRequest(requestUrl, topLevelUrl, this.getPolicyConfig(), isMainFrame);

              if (decision.action === 'allow') {
                if (isMainFrame) {
                  this.pendingTopLevelUrl = requestUrl;
                }
                return null;
              }

              console.info(`学习模式拦截请求: ${requestUrl}`);
              if (isMainFrame) {
                this.pendingTopLevelUrl = requestUrl;
                this.skipNextHistorySave = true;
                if (this.lastBlockedMainFrameUrl !== requestUrl) {
                  this.lastBlockedMainFrameUrl = requestUrl;
                  this.showPolicyToast(decision.message);
                }
                return this.buildBlockedPageResponse(decision.message);
              }
              return this.buildEmptyBlockedResponse();
            })
            .onProgressChange((event) => {
              this.currentProgress = event.newProgress;
            })
            .onPageEnd(async () => {
              try {
                const newUrl = this.webviewController.getUrl();
                const currentTab = this.tabManager.getCurrentTab();
                if (currentTab && currentTab.url !== newUrl && newUrl !== 'about:blank') {
                  currentTab.url = newUrl;
                  currentTab.title = this.webviewController.getTitle();
                  this.url = newUrl;
                  this.tabs = [...this.tabManager.getTabs()];
                }

                this.pendingTopLevelUrl = this.url;
                if (this.skipNextHistorySave) {
                  this.skipNextHistorySave = false;
                  return;
                }
                if (!this.privateMode) {
                  await this.onSaveHistory();
                }
                emitter.emit({ eventId: 10002 });
              } catch (error) {
                console.log('获取 Url 异常：' + error);
              }
            })
            .onRefreshAccessedHistory(() => {
              try {
                this.isBacked = this.webviewController.accessBackward();
                this.isForwarded = this.webviewController.accessForward();
                const currentTab = this.tabManager.getCurrentTab();
                if (currentTab) {
                  currentTab.canGoBack = this.isBacked;
                  currentTab.canGoForward = this.isForwarded;
                }
              } catch (error) {
                console.log('更新前进或后退状态异常：' + error);
              }
            })
            .onTouch((event: TouchEvent) => {
              this.longPressHelper?.onTouchEvent(event);
            });
        }
        .width('100%')
        .height(this.high)
        .justifyContent(FlexAlign.Center)
        .animation({ duration: 300 });

        Stack({ alignContent: Alignment.Bottom }) {
          Search({ placeholder: '搜索或输入网址', value: this.url, controller: this.textInputController })
            .width('90%')
            .height('8%')
            .size({ height: 50 })
            .margin({ top: 5, bottom: 10, left: 5, right: 5 })
            .textAlign(this.textAlign)
            .backgroundColor(!this.darkMode ? '#E8E8E8' : '#696969')
            .zIndex(3)
            .animation({ duration: 300 })
            .onClick(() => {
              this.inputMethodController.showSoftKeyboard();
              if (this.isSearched) {
                this.textInputController.setTextSelection(0, this.url.length);
              }
            })
            .onEditChange((isEditing: boolean) => {
              this.isShowMask = isEditing;
            })
            .onSubmit((value) => {
              try {
                this.navigateWithPolicy(value);
              } catch (error) {
                console.log('提交搜索时异常：' + error);
              }
            });

          Progress({ value: this.currentProgress, type: ProgressType.Linear })
            .visibility(this.currentProgress === 100 || this.currentProgress === 0 ? Visibility.None : Visibility.Visible)
            .animation({ duration: 100 });
        }
      }
      .width('100%')
      .layoutWeight(11)
      .justifyContent(FlexAlign.Center);

      FunctionButtons({ isBacked: $isBacked, isForward: $isForwarded })
        .width('100%')
        .margin({ top: 5 })
        .layoutWeight(1);

      if (this.isShowMask) {
        Column()
          .width('100%')
          .height('100%')
          .position({ x: 0, y: 0 })
          .backgroundColor('rgba(0,0,0,0.3)')
          .onClick(() => {
            this.isShowMask = false;
            this.inputMethodController.stopInputSession();
          })
          .zIndex(2);
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(!this.darkMode ? Color.White : '#1C1C1C')
    .animation({ duration: 300 });
  }
}