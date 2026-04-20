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

import { TtsReaderService } from '../utils/TtsReaderService';
import ArticleContent from '../common/bean/ArticleContent';

interface SwitchTabEventData {
  index: number;
}

interface ReaderRequestEventData {
  enabled?: boolean;
  token?: number;
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
PersistentStorage.PersistProp('readerFontScale', 1);
PersistentStorage.PersistProp('readerLineHeight', 1.8);
PersistentStorage.PersistProp('readerModeEnabled', false);
PersistentStorage.PersistProp('readerFeatureAvailable', false);
PersistentStorage.PersistProp('readerDetectLoading', false);
PersistentStorage.PersistProp('readerConfidence', 0);
PersistentStorage.PersistProp('readerUnsupportedReason', '');
PersistentStorage.PersistProp('readerModeEnabled', false);
PersistentStorage.PersistProp('ttsRequestToken', 0);
PersistentStorage.PersistProp('tabCount', 1);

@Entry
@Component
struct Index {
  @State url: string = '';
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

  // 阅读器/TTS UI 状态
  @State readerTitle: string = '';
  @State readerParagraphs: string[] = [];
  @StorageLink('readerModeEnabled') @Watch('onReaderModeChanged') isReaderMode: boolean = false;
  @StorageLink('readerFeatureAvailable') readerAvailable: boolean = false;
  @StorageLink('readerConfidence') readerConfidence: number = 0;
  @StorageLink('readerDetectLoading') readerLoading: boolean = false;
  @StorageLink('readerUnsupportedReason') readerUnsupportedReason: string = '';
  @StorageLink('readerRequestToken') @Watch('onReaderRequest') readerRequestToken: number = 0;
  @State ttsPanelVisible: boolean = false;
  @State ttsPlaying: boolean = false;
  @State ttsCurrentIndex: number = 0;
  @State ttsUnits: string[] = [];
  @State ttsUnitParagraphIndex: number[] = [];
  @State ttsPlaySpeed: number = 1.0;
  @State ttsErrorReason: string = '';
  @State ttsOutputMode: string = 'speech';
  @StorageLink('readerFontScale') readerFontScale: number = 1;
  @StorageLink('readerLineHeight') readerLineHeight: number = 1.8;

  private ttsService: TtsReaderService | null = null;

  @StorageLink('userId') @Watch('onUserChanged') userId: string = 'guest';
  @Provide('historyMap') @Watch('onHistoryChange') historyMap: Map<string, History[]> = new Map();

  @Provide webviewController: webview.WebviewController = new webview.WebviewController();
  @Provide('webIsSearched') @Watch('onSearched') isSearched: boolean = false;

  @StorageLink('privateMode') privateMode: boolean = false;
  @StorageLink('darkMode') darkMode: boolean = false;
  @StorageLink('currentEngineIndex') searchEngine: number = 0;
  @StorageLink('studyModeEnabled') studyModeEnabled: boolean = false;
  @StorageLink('studyWhitelistJson') studyWhitelistJson: string = CommonConstants.DEFAULT_STUDY_WHITELIST_JSON;
  @StorageLink('targetUrl') targetUrl: string = '';
  @StorageLink('nickname') nickname: string = '小狐狸用户';
  @StorageLink('avatarPath') avatarPath: string = '';
  @StorageLink('ttsRequestToken') @Watch('onTtsRequest') ttsRequestToken: number = 0;

  delegate: webview.WebDownloadDelegate = new webview.WebDownloadDelegate();
  private windowClass: window.Window | null = null;
  private textInputController: TextInputController = new TextInputController();
  private inputMethodController: inputMethod.InputMethodController = inputMethod.getController();
  private longPressHelper?: WebLongPressHelper;

  private tabManager: TabManager = new TabManager();
  @State tabs: TabModel[] = [];
  @State currentIndex: number = 0;
  @Provide('tabManager') providedTabManager: TabManager = this.tabManager;

  private ensureTtsService() {
    if (this.ttsService) return;
    this.ttsService = new TtsReaderService(this.webviewController, () => {
      this.syncTtsState();
    });
  }

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
        if (list.length > 0) newMap.set(date, list);
      }
      this.historyMap = newMap;
      AppStorage.setOrCreate('globalHistoryMap', this.historyMap);
    } catch (e) {
      console.error('[Index] 刷新历史失败: ' + e.message);
    }
  }

  onHistoryChange() {
    AppStorage.setOrCreate('globalHistoryMap', this.historyMap);
  }

  private switchToTab(index: number) {
    if (index < 0 || index >= this.tabs.length) return;
    this.tabs = [...this.tabManager.getTabs()];
    AppStorage.setOrCreate('tabCount', this.tabs.length);
    this.currentIndex = index;
    this.tabManager.switchTo(index);
    const currentTab = this.tabManager.getCurrentTab();
    if (currentTab) {
      this.url = currentTab.url;
      this.isBacked = currentTab.canGoBack;
      this.isForwarded = currentTab.canGoForward;
      if (currentTab.url === 'about:blank') {
        this.isSearched = false;
        if (this.webviewController.getUrl() !== 'about:blank') this.webviewController.loadUrl('about:blank');
      } else {
        this.isSearched = true;
        if (this.webviewController.getUrl() !== currentTab.url) this.webviewController.loadUrl(currentTab.url);
      }
    }
  }

  private async exitReaderModeAndStopTts() {
    if (this.isReaderMode) {
      this.isReaderMode = false;
    }
    if (this.ttsService) {
      await this.ttsService.stopTts();
      this.syncTtsState();
    }
  }

  async aboutToAppear() {
    console.debug('项目正在启动');
    this.ensureTtsService();
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
    const firstTab = this.tabManager.newTab('about:blank', '新标签页');
    this.tabs = this.tabManager.getTabs();
    AppStorage.setOrCreate('tabCount', this.tabs.length);
    this.currentIndex = 0;
    this.switchToTab(0);
    window.getLastWindow(getContext(this), (err, data) => {
      if (err) console.log(err.message);
      this.windowClass = data;
      this.windowClass.on('keyboardHeightChange', (data) => { this.keyboardHeight = data; });
    });
    emitter.on('switchTab', (data?: emitter.EventData) => {
      const eventData = data?.data as SwitchTabEventData;
      if (eventData && eventData.index !== undefined) this.switchToTab(eventData.index);
    });
    emitter.on('readerRequest', (data?: emitter.EventData) => {
      const eventData = data?.data as ReaderRequestEventData;
      if (!eventData || !eventData.enabled) return;
      void this.detectAndSetReaderContent();
    });
    this.longPressHelper = new WebLongPressHelper(
      this.webviewController,
      this.tabManager,
      this.getUIContext(),
      getContext(this),
      () => this.userId
    );
    console.debug('项目已启动');
  }

  onPageShow() {
    let target: string = AppStorage.get('targetUrl') || '';
    if (target !== '') {
      this.webviewController.loadUrl(target);
      this.isSearched = true;
      AppStorage.setOrCreate('targetUrl', '');
    }
    if (this.isReaderMode) {
      void this.detectAndSetReaderContent();
      setTimeout(() => {
        if (!this.readerLoading && this.readerParagraphs.length === 0) {
          void this.detectAndSetReaderContent();
        }
      }, 360);
    }
    if (this.historyMap.size === 0) this.refreshHistoryData();
    if (this.targetUrl && this.targetUrl !== '') {
      if (!this.isSearched) { this.isSearched = true; this.onSearched(); }
      setTimeout(() => {
        try { this.webviewController.loadUrl(this.targetUrl); this.url = this.targetUrl; AppStorage.setOrCreate('targetUrl', ''); }
        catch (e) { console.error('加载 URL 失败: ' + e); }
      }, 50);
    }
  }

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

  async onSaveHistory() {
    try {
      const now = new Date();
      const date = `${now.getFullYear()}_${(now.getMonth() + 1).toString().padStart(2, '0')}_${now.getDate().toString().padStart(2, '0')}`;
      await RdbUtils.insertDate(date);
      const timestamp = `${now.getFullYear()}_${(now.getMonth() + 1).toString().padStart(2, '0')}_${now.getDate().toString().padStart(2, '0')} ${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;
      const history = new History(this.webviewController.getTitle(), this.webviewController.getUrl(), timestamp);
      await RdbUtils.insertHistory(date, history, this.userId);
      if (!this.historyMap.has(date)) this.historyMap.set(date, []);
      this.historyMap.get(date)?.unshift(history);
      AppStorage.setOrCreate('globalHistoryMap', this.historyMap);
    } catch (error) { console.error('保存失败: ' + error); }
  }

  async toggleBookmark() {
    const currentTitle = this.webviewController.getTitle();
    const currentUrl = this.webviewController.getUrl();
    const history = new History(currentTitle, currentUrl, '');
    await RdbUtils.insertBookmark(history);
    promptAction.showToast({ message: '已添加到书签' });
  }

  private getPolicyConfig(): PolicyConfig {
    const enginePrefix = CommonConstants.SEARCH_ENGINES[this.searchEngine].prefix;
    const engineHost = DomainUtils.extractHostFromPrefix(enginePrefix);
    return {
      studyModeEnabled: this.studyModeEnabled,
      whitelist: StudyModeRules.parseWhitelist(this.studyWhitelistJson),
      currentSearchEngineHost: engineHost
    };
  }

  private showPolicyToast(message: string) { Prompt.showToast({ message }); }

  private getCurrentTopLevelUrl(): string { return this.pendingTopLevelUrl.length > 0 ? this.pendingTopLevelUrl : this.url; }

  private navigateWithPolicy(content: string) {
    const targetUrl = DomainUtils.resolveInputToUrl(content, CommonConstants.SEARCH_ENGINES[this.searchEngine].prefix);
    const decision = RequestPolicy.evaluateNavigation(targetUrl, this.getPolicyConfig());
    if (decision.action === 'block') { this.showPolicyToast(decision.message); this.inputMethodController.stopInputSession(); return; }
    this.pendingTopLevelUrl = targetUrl;
    this.skipNextHistorySave = false;
    this.lastBlockedMainFrameUrl = '';
    this.webviewController.loadUrl(targetUrl);
    this.url = targetUrl;
    const currentTab = this.tabManager.getCurrentTab();
    if (currentTab) { currentTab.url = targetUrl; currentTab.title = ''; this.tabs = [...this.tabManager.getTabs()]; }
    if (!this.isSearched) this.isSearched = true;
    this.inputMethodController.stopInputSession();
  }

  private buildBlockedPageResponse(message: string): WebResourceResponse {
    const response = new WebResourceResponse();
    response.setResponseData(`<!DOCTYPE html><html><head><meta charset="utf-8"><title>Blocked</title></head><body style="margin:0;font-family:sans-serif;background:#f7f8fa;display:flex;align-items:center;justify-content:center;min-height:100vh;color:#1f2329;"><div style="max-width:280px;padding:24px;border-radius:18px;background:#ffffff;box-shadow:0 10px 30px rgba(0,0,0,0.08);text-align:center;"><div style="font-size:18px;font-weight:600;margin-bottom:12px;">学习模式已拦截</div><div style="font-size:14px;line-height:1.6;">${message}</div></div></body></html>`);
    response.setResponseEncoding('utf-8'); response.setResponseMimeType('text/html'); response.setResponseCode(403); response.setReasonMessage('Blocked'); response.setResponseIsReady(true);
    return response;
  }

  private buildEmptyBlockedResponse(): WebResourceResponse {
    const response = new WebResourceResponse();
    response.setResponseData(''); response.setResponseEncoding('utf-8'); response.setResponseMimeType('text/plain'); response.setResponseCode(403); response.setReasonMessage('Blocked'); response.setResponseIsReady(true);
    return response;
  }

  private syncTtsState() {
    if (!this.ttsService) return;
    this.ttsUnits = this.ttsService.getTtsUnits();
    this.ttsCurrentIndex = this.ttsService.getTtsCurrentIndex();
    this.ttsPlaying = this.ttsService.getTtsPlaying();
    this.ttsPlaySpeed = this.ttsService.getTtsPlaySpeed();
    this.ttsErrorReason = this.ttsService.getTtsErrorReason();
    this.ttsPanelVisible = this.ttsService.isPanelVisible();
    this.ttsOutputMode = this.ttsService.getTtsOutputMode();
    this.ttsUnitParagraphIndex = this.ttsService.getTtsUnitParagraphIndex();
  }

  private async detectAndSetReaderContent() {
    this.ensureTtsService();
    if (!this.ttsService) return;
    this.readerLoading = true;
    this.readerTitle = '';
    this.readerParagraphs = [];
    this.readerAvailable = false;
    this.readerConfidence = 0;
    this.readerUnsupportedReason = '';
    const content: ArticleContent = await this.ttsService.detectReaderContent();
    this.readerTitle = content.title;
    this.readerParagraphs = content.paragraphs;
    this.readerAvailable = content.available;
    this.readerConfidence = content.confidence;
    this.readerUnsupportedReason = content.unsupportedReason;
    this.readerLoading = false;
  }

  private onTtsRequest() {
    if (!this.ttsService) return;
    void (async () => {
      if (this.readerParagraphs.length === 0) {
        await this.detectAndSetReaderContent();
      }
      await this.ttsService!.startTts(this.readerParagraphs, this.isReaderMode, getContext(this));
      this.syncTtsState();
    })();
  }

  private onReaderModeChanged() {
    this.ensureTtsService();
    if (!this.ttsService) return;
    if (this.isReaderMode) void this.detectAndSetReaderContent();
  }

  private onReaderRequest() {
    this.ensureTtsService();
    if (!this.ttsService || !this.isReaderMode) return;
    void this.detectAndSetReaderContent();
  }

  private onToggleReaderMode() {
    if (!this.isReaderMode && !this.readerAvailable) {
      Prompt.showToast({ message: `当前页面不支持阅读器：${this.readerUnsupportedReason || '原因未知'}` });
      return;
    }
    this.isReaderMode = !this.isReaderMode;
  }

  onSearched() {
    this.isShowed = Visibility.Visible;
    this.high = '91%';
    this.textAlign = TextAlign.Center;
  }

  @Builder ReaderContentPanel() {
    Column() {
      Row({ space: 8 }) {
        Button('退出阅读').type(ButtonType.Capsule).height(30).fontSize(12).onClick(() => { void this.exitReaderModeAndStopTts(); })
        Button('-字').type(ButtonType.Capsule).height(30).fontSize(12).onClick(() => { this.readerFontScale = Math.max(0.8, this.readerFontScale - 0.1); })
        Button('+字').type(ButtonType.Capsule).height(30).fontSize(12).onClick(() => { this.readerFontScale = Math.min(1.6, this.readerFontScale + 0.1); })
        Button('-行距').type(ButtonType.Capsule).height(28).fontSize(11).onClick(() => { this.readerLineHeight = Math.max(1.2, this.readerLineHeight - 0.1); })
        Button('+行距').type(ButtonType.Capsule).height(28).fontSize(11).onClick(() => { this.readerLineHeight = Math.min(2.4, this.readerLineHeight + 0.1); })
        Text(`行高 ${this.readerLineHeight.toFixed(1)}`).fontSize(12).fontColor(Color.Gray)
      }
      .width('100%').justifyContent(FlexAlign.SpaceBetween).margin({ top: 18, left: 14, right: 14, bottom: 8 })

      Text(this.readerTitle || '阅读器模式')
        .width('100%')
        .fontSize(24 * this.readerFontScale)
        .fontWeight(FontWeight.Medium)
        .fontColor(!this.darkMode ? Color.Black : Color.White)
        .textAlign(TextAlign.Start)
        .margin({ left: 14, right: 14, bottom: 12 })

      if (this.readerLoading) {
        Column({ space: 8 }) {
          Text('阅读器内容识别中...')
            .fontSize(14)
            .fontColor('#45A5FF')
          Text(this.readerUnsupportedReason.length > 0 ? this.readerUnsupportedReason : '正在提取正文，请稍候')
            .fontSize(12)
            .fontColor(Color.Gray)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 14, right: 14, top: 8, bottom: 20 })
      } else if (this.readerParagraphs.length === 0) {
        Column({ space: 8 }) {
          Text('暂无可显示正文')
            .fontSize(14)
            .fontColor(Color.Gray)
          Text(this.readerUnsupportedReason.length > 0 ? this.readerUnsupportedReason : '请返回网页后重新识别，或刷新页面后再试')
            .fontSize(12)
            .fontColor('#E67E22')
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 14, right: 14, top: 8, bottom: 20 })
      } else {
        Scroll() {
          Column({ space: 14 }) {
            ForEach(this.readerParagraphs, (paragraph: string, index: number) => {
              Text(paragraph)
                .width('100%').textAlign(TextAlign.Start).fontSize(17 * this.readerFontScale).lineHeight(this.readerLineHeight * 30)
                .fontColor(this.ttsUnitParagraphIndex[this.ttsCurrentIndex] === index ? '#0D47A1' : (!this.darkMode ? '#1C1C1C' : '#ECECEC'))
                .backgroundColor(this.ttsUnitParagraphIndex[this.ttsCurrentIndex] === index ? '#E8F2FF' : '#00000000')
                .borderRadius(8).padding({ left: 6, right: 6, top: 4, bottom: 4 })
            })
          }
          .width('100%').padding({ left: 14, right: 14, bottom: 20 })
        }
        .scrollable(ScrollDirection.Vertical).layoutWeight(1)
      }
    }
    .width('100%').height('100%').backgroundColor(!this.darkMode ? '#FDFDFD' : '#121212')
  }

  @Builder TtsControlBar() {
    if (this.ttsPanelVisible) {
      Column({ space: 6 }) {
        Row() {
          Text(`朗读中 ${this.ttsCurrentIndex+1}/${this.ttsUnits.length} x${this.ttsPlaySpeed.toFixed(1)} ${this.ttsOutputMode === 'native' ? '(原生)' : (this.ttsOutputMode === 'audio' ? '(云端)' : '(本机)')}`)
            .fontSize(12).fontColor('#45A5FF').layoutWeight(1)
        }.width('100%')
        Text(this.ttsErrorReason || '状态：准备就绪').fontSize(11).fontColor(this.ttsErrorReason ? '#E67E22' : Color.Gray).maxLines(2).width('100%').height(36)
        Row({ space: 8 }) {
          Button('上一句').type(ButtonType.Capsule).height(32).fontSize(11).onClick(() => this.ttsService?.prevTtsUnit(getContext(this)))
          Button(this.ttsPlaying ? '暂停' : '播放').type(ButtonType.Capsule).height(32).fontSize(11).onClick(() => {
            if (this.ttsPlaying) this.ttsService?.pauseTts(); else this.ttsService?.resumeTts(getContext(this));
            this.syncTtsState();
          })
          Button('下一句').type(ButtonType.Capsule).height(32).fontSize(11).onClick(() => this.ttsService?.nextTtsUnit(getContext(this)))
          Button('停止').type(ButtonType.Capsule).height(32).fontSize(11).onClick(() => { this.ttsService?.stopTts(); this.syncTtsState(); })
        }.width('100%').justifyContent(FlexAlign.SpaceBetween)
      }
      .width('94%').padding(10).backgroundColor(!this.darkMode ? '#F7FBFF' : '#2B2B2B').borderRadius(10).margin({ top: 3, bottom: 8 })
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Flex({ direction: FlexDirection.Column, alignItems: ItemAlign.Center }) {
        Column() {
          Column() {
          if (!this.isSearched) {
            Row() {
              Image($r('app.media.app_icon')).width(30).height(30).margin({ bottom: 25, right: 10 })
              Text(CommonConstants.APP_NAME).fontSize(25).fontColor(!this.darkMode ? Color.Black : Color.White).margin({ bottom: 25 })
            }.width('100%').height('100%').justifyContent(FlexAlign.Center)
          }

          Stack({ alignContent: Alignment.TopStart }) {
            Web({ src: this.url, controller: this.webviewController })
              .width('100%').height('100%').visibility(this.isShowed)
              .opacity(this.isReaderMode ? 0.14 : 1)
              .onInterceptRequest((event) => {
                if (!event) return null;
                const requestUrl = event.request.getRequestUrl();
                const isMainFrame = event.request.isMainFrame();
                const topLevelUrl = isMainFrame ? requestUrl : this.getCurrentTopLevelUrl();
                const decision = RequestPolicy.evaluateRequest(requestUrl, topLevelUrl, this.getPolicyConfig(), isMainFrame);
                if (decision.action === 'allow') { if (isMainFrame) this.pendingTopLevelUrl = requestUrl; return null; }
                if (isMainFrame) {
                  this.pendingTopLevelUrl = requestUrl; this.skipNextHistorySave = true;
                  if (this.lastBlockedMainFrameUrl !== requestUrl) { this.lastBlockedMainFrameUrl = requestUrl; this.showPolicyToast(decision.message); }
                  return this.buildBlockedPageResponse(decision.message);
                }
                return this.buildEmptyBlockedResponse();
              })
              .onProgressChange((event) => { this.currentProgress = event.newProgress; })
              .onPageEnd(async () => {
                try {
                  const previousUrl = this.url;
                  const newUrl = this.webviewController.getUrl();
                  const pageChanged = previousUrl.length > 0 && newUrl.length > 0 && newUrl !== previousUrl;
                  if (this.isReaderMode && pageChanged) {
                    await this.exitReaderModeAndStopTts();
                  }
                  const currentTab = this.tabManager.getCurrentTab();
                  if (currentTab && currentTab.url !== newUrl && newUrl !== 'about:blank') { currentTab.url = newUrl; currentTab.title = this.webviewController.getTitle(); this.url = newUrl; this.tabs = [...this.tabManager.getTabs()]; }
                  this.pendingTopLevelUrl = this.url;
                  if (this.skipNextHistorySave) { this.skipNextHistorySave = false; return; }
                  if (!this.privateMode) await this.onSaveHistory();
                  emitter.emit({ eventId: 10002 });
                  await this.detectAndSetReaderContent();
                } catch (error) { console.log('获取 Url 异常：' + error); }
              })
              .onRefreshAccessedHistory(() => {
                try { this.isBacked = this.webviewController.accessBackward(); this.isForwarded = this.webviewController.accessForward(); const currentTab = this.tabManager.getCurrentTab(); if (currentTab) { currentTab.canGoBack = this.isBacked; currentTab.canGoForward = this.isForwarded; } }
                catch (error) { console.log('更新前进或后退状态异常：' + error); }
              })
              .onTouch((event: TouchEvent) => { this.longPressHelper?.onTouchEvent(event); });

            if (this.isReaderMode) {
              this.ReaderContentPanel()
            }
          }

          }
          .width('100%').height(this.high).justifyContent(FlexAlign.Center).animation({ duration: 300 });

        Stack({ alignContent: Alignment.Bottom }) {
          Search({ placeholder: '搜索或输入网址', value: this.url, controller: this.textInputController })
            .width('90%').height('8%').size({ height: 50 }).margin({ top: 5, bottom: 10, left: 5, right: 5 })
            .textAlign(this.textAlign).backgroundColor(!this.darkMode ? '#E8E8E8' : '#696969').zIndex(3)
            .onClick(() => { this.inputMethodController.showSoftKeyboard(); if (this.isSearched) this.textInputController.setTextSelection(0, this.url.length); })
            .onEditChange((isEditing: boolean) => { this.isShowMask = isEditing; })
            .onSubmit((value) => { try { this.navigateWithPolicy(value); } catch (error) { console.log('提交搜索时异常：' + error); } });
          Progress({ value: this.currentProgress, type: ProgressType.Linear })
            .visibility(this.currentProgress === 100 || this.currentProgress === 0 ? Visibility.None : Visibility.Visible);
        }
        }
        .width('100%').layoutWeight(11).justifyContent(FlexAlign.Center);

        FunctionButtons({ isBacked: $isBacked, isForward: $isForwarded }).width('100%').margin({ top: 5 }).layoutWeight(1);

        if (this.isShowMask) {
          Column().width('100%').height('100%').position({ x: 0, y: 0 }).backgroundColor('rgba(0,0,0,0.3)')
            .onClick(() => { this.isShowMask = false; this.inputMethodController.stopInputSession(); }).zIndex(2);
        }
      }
      .width('100%').height('100%').backgroundColor(!this.darkMode ? Color.White : '#1C1C1C');

      if (this.ttsPanelVisible) {
        Column() {
          this.TtsControlBar();
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: 124 })
        .zIndex(30);
      }
    }
    .width('100%').height('100%').backgroundColor(!this.darkMode ? Color.White : '#1C1C1C');
  }
}