import webview from '@ohos.web.webview'
import CommonConstants from "../common/constants/CommonConstants"
import { FunctionButtons } from '../common/bean/FunctionButtons'
import History from '../common/bean/History'
import window from '@ohos.window'
import { inputMethod } from '@kit.IMEKit'
import media from '@ohos.multimedia.media'
import http from '@ohos.net.http'
import fs from '@ohos.file.fs'
import RdbUtils from '../utils/RdbUtils'
import ReaderExtractionService from '../utils/ReaderExtractionService'
import { Prompt } from '@kit.ArkUI'

class CachePathContext {
  cacheDir: string = ''
}

// 持久化数据
PersistentStorage.PersistProp("privateMode", false)
PersistentStorage.PersistProp("currentEngineIndex", 0)
PersistentStorage.PersistProp("currentEngineName", "Bing")
PersistentStorage.PersistProp("darkMode", false)
PersistentStorage.PersistProp("readerFontScale", 1)
PersistentStorage.PersistProp("readerLineHeight", 1.8)
PersistentStorage.PersistProp("readerModeEnabled", false)
PersistentStorage.PersistProp("readerFeatureAvailable", false)
PersistentStorage.PersistProp("readerDetectLoading", false)
PersistentStorage.PersistProp("readerConfidence", 0)
PersistentStorage.PersistProp("readerUnsupportedReason", "")
PersistentStorage.PersistProp("ttsRequestToken", 0)
PersistentStorage.PersistProp("ttsArticleHtml", "")

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
  // 阅读器错误提示
  @State readerError: string = ""
  // 结构化正文标题
  @State readerTitle: string = ""
  // 结构化正文段落
  @State readerParagraphs: string[] = []
  // 当前页面 HTML（用于朗读页直接抽取）
  @State readerPageHtml: string = ''
  // 朗读单元（句子级）
  @State ttsUnits: string[] = []
  // 句子到段落的映射索引（阅读器高亮用）
  @State ttsUnitParagraphIndex: number[] = []
  // 当前朗读句索引
  @State ttsCurrentIndex: number = 0
  // 当前已加载到播放器的句索引（用于避免恢复时重复旧句）
  @State ttsLoadedUnitIndex: number = -1
  // 是否正在朗读
  @State ttsPlaying: boolean = false
  // 朗读控制条显示
  @State ttsPanelVisible: boolean = false
  // 朗读速度
  @State ttsPlaySpeed: number = 1.0
  // 朗读失败原因
  @State ttsErrorReason: string = ''
  // 朗读调试信息
  @State ttsDebugInfo: string = ''
  // 朗读操作日志（最近一条）
  @State ttsActionLog: string = ''
  // 朗读日志文件路径
  @State ttsLogFilePath: string = ''
  // 朗读日志面板内容（最近多条）
  @State ttsLogDump: string = ''
  // 朗读来源：reader/page
  @State ttsSource: string = 'page'
  // 当前输出模式：speech/audio
  @State ttsOutputMode: string = 'speech'
  // voices=0 熔断标记，避免重复自动重试
  @State ttsVoiceBlocked: boolean = false
  // 云端音频被策略拦截标记
  @State ttsAudioBlocked: boolean = false
  // 手动重试进行中，避免重复点击触发并发重试
  @State ttsManualRetrying: boolean = false
  // 朗读控制自锁，防止连续点击触发并发播放
  @State ttsCommandLocked: boolean = false
  // 原生播放器可用状态
  @State ttsNativeReady: boolean = false
  // 原生兜底失败后禁用，避免反复失败导致无法回退到 Web 音频
  @State ttsNativeFallbackDisabled: boolean = false

  private ttsTimer: number = -1
  private nativeAudioPlayer: media.AVPlayer | null = null
  private nativeTempAudioPath: string = ''
  private nativeAudioFd: number = -1
  // 会话级播放代次，作为进程锁：任何旧代次异步回调都必须被丢弃。
  private ttsPlayGeneration: number = 0
  private ttsRuntimeLogs: string[] = []

  private toAsciiArrayBuffer(text: string): ArrayBuffer {
    const bytes = new Uint8Array(text.length)
    for (let i = 0; i < text.length; i++) {
      bytes[i] = text.charCodeAt(i) & 0xFF
    }
    return bytes.buffer
  }

  private flushTtsRuntimeLogs() {
    // 调试阶段结束后，默认不再频繁落盘，避免影响体验和性能。
  }

  private setTtsActionLog(action: string, detail: string = '') {
    // 简化模式：保留最近一条动作，不再维护大体量调试日志。
    const ts = Date.now() % 100000
    this.ttsActionLog = `[${ts}] ${action}${detail.length > 0 ? '|' + detail : ''}`
  }

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
  // 阅读器字号系数
  @StorageLink("readerFontScale") readerFontScale: number = 1
  // 阅读器行高系数
  @StorageLink("readerLineHeight") readerLineHeight: number = 1.8
  // 阅读器模式开关（设置弹窗联动）
  @StorageLink("readerModeEnabled") isReaderMode: boolean = false
  // 阅读器可用性（设置弹窗展示）
  @StorageLink("readerFeatureAvailable") readerAvailable: boolean = false
  // 阅读器识别中状态（设置弹窗展示）
  @StorageLink("readerDetectLoading") readerLoading: boolean = false
  // 可读性置信度（设置弹窗展示）
  @StorageLink("readerConfidence") readerConfidence: number = 0
  // 阅读器不可用原因（调试展示）
  @StorageLink("readerUnsupportedReason") readerUnsupportedReason: string = ''
  // 朗读请求令牌（设置弹窗触发）
  @StorageLink("ttsRequestToken") @Watch("onTtsRequest") ttsRequestToken: number = 0

  private windowClass: window.Window | null = null

  private textInputController: TextInputController = new TextInputController()

  // 获取输入法实例
  private inputMethodController: inputMethod.InputMethodController = inputMethod.getController()

  private readerHtmlScript: string = `(function() {
    try {
      return document.body ? document.body.outerHTML : '';
    } catch (e) {
      return '';
    }
  })();`

  private readerTitleScript: string = `(function() {
    try {
      return document.title ? document.title : '';
    } catch (e) {
      return '';
    }
  })();`

  private readerTextScript: string = `(function() {
    try {
      return document.body ? document.body.innerText : '';
    } catch (e) {
      return '';
    }
  })();`

  private cancelSpeechScript: string = `(function() {
    try {
      if ('speechSynthesis' in window) {
        window.speechSynthesis.cancel();
      }
      window.__readerAudioActivePlay = 0;
      window.__readerUnlocking = 0;
      window.__readerSentenceEnded = 0;
      if (window.__readerAudio) {
        try {
          window.__readerAudio.pause();
          window.__readerAudio.currentTime = 0;
        } catch (e) {}
        window.__readerAudio = null;
      }
      if (window.__readerMark && window.__readerMark.parentNode) {
        const parent = window.__readerMark.parentNode;
        const text = document.createTextNode(window.__readerMark.textContent || '');
        parent.replaceChild(text, window.__readerMark);
        window.__readerMark = null;
      }
      return 'ok';
    } catch (e) {
      return 'error';
    }
  })();`

  private pauseSpeechScript: string = `(function() {
    try {
      if ('speechSynthesis' in window) {
        window.speechSynthesis.pause();
      }
      window.__readerAudioActivePlay = 0;
      if (window.__readerAudio) {
        try {
          window.__readerAudio.pause();
        } catch (e) {}
      }
      return 'ok';
    } catch (e) {
      return 'error';
    }
  })();`

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

  onBackPress(): boolean {
    if (this.ttsPanelVisible) {
      this.stopTts(true)
      return true
    }
    // 阅读器模式下优先退出阅读器，避免触发页面退出或 Web 重建。
    if (this.isReaderMode) {
      this.isReaderMode = false
      return true
    }
    return false
  }

  private async runScript(script: string): Promise<string> {
    return new Promise((resolve) => {
      try {
        this.webviewController.runJavaScript(script, (error: Error, result: string) => {
          if (error) {
            resolve('')
            return
          }
          resolve(result ?? '')
        })
      } catch (error) {
        console.error('执行页面脚本异常：' + error)
        resolve('')
      }
    })
  }

  private async detectReaderContent() {
    this.readerLoading = true
    this.readerError = ''
    this.readerAvailable = false
    this.readerConfidence = 0
    this.readerUnsupportedReason = ''

    try {
      const rawHtml = await this.runScript(this.readerHtmlScript)
      const html = this.decodeScriptResult(rawHtml)
      this.readerPageHtml = html
      const rawText = await this.runScript(this.readerTextScript)
      const visibleText = this.decodeScriptResult(rawText)

      const rawTitle = await this.runScript(this.readerTitleScript)
      const pageTitle = this.decodeScriptResult(rawTitle)

      const fallbackTitle = pageTitle.length > 0 ? pageTitle : this.webviewController.getTitle()
      let extracted = ReaderExtractionService.extractFromHtml(html, this.webviewController.getUrl(), fallbackTitle)

      // HTML 抽取失败时，回退到渲染后纯文本，覆盖百科类异步注入场景。
      if (!extracted.available && visibleText.length > 0) {
        const fallbackExtracted = ReaderExtractionService.extractFromRenderedText(visibleText,
          this.webviewController.getUrl(), fallbackTitle)
        if (fallbackExtracted.available || fallbackExtracted.paragraphCount > extracted.paragraphCount) {
          extracted = fallbackExtracted
        }
      }

      if (!extracted.available && (!html || html.length < 50) && visibleText.length < 30) {
        extracted.unsupportedReason = '页面正文仍在异步加载，建议稍后重试或下滑页面后再开启阅读器'
      }

      this.readerTitle = extracted.title
      this.readerParagraphs = extracted.paragraphs
      this.readerConfidence = extracted.confidence
      this.readerAvailable = extracted.available
      this.readerUnsupportedReason = extracted.unsupportedReason

      if (!extracted.available) {
        this.readerError = extracted.unsupportedReason.length > 0 ?
          `不支持阅读器：${extracted.unsupportedReason}` :
          '当前页面内容较分散，建议继续网页模式浏览'
      }
    } catch (error) {
      this.readerError = '阅读器解析失败'
      this.readerUnsupportedReason = '阅读器解析异常，请检查页面脚本返回内容'
      console.error('阅读器识别异常：' + error)
    } finally {
      this.readerLoading = false
    }
  }

  private decodeScriptResult(raw: string): string {
    if (!raw) {
      return ''
    }

    let decoded = raw

    // 某些页面会返回带引号包裹的字符串，先手动去壳，避免 JSON.parse 触发 any/unknown 规则。
    if (decoded.length >= 2 && decoded.startsWith('"') && decoded.endsWith('"')) {
      decoded = decoded.substring(1, decoded.length - 1)
    }

    // 兼容常见转义字符，避免 \u003C 这类源码字符串直接渲染。
    return decoded
      .replace(/\\u003C/gi, '<')
      .replace(/\\u003E/gi, '>')
      .replace(/\\u0026/gi, '&')
      .replace(/\\u0022/gi, '"')
      .replace(/\\u0027/gi, "'")
      .replace(/\\n/g, '\n')
      .replace(/\\r/g, '\r')
      .replace(/\\t/g, '\t')
      .replace(/\\\"/g, '"')
  }

  private onToggleReaderMode() {
    if (!this.isReaderMode && !this.readerAvailable) {
      const reason = this.readerUnsupportedReason.length > 0 ? this.readerUnsupportedReason : this.readerError
      Prompt.showToast({ message: `当前页面不支持阅读器：${reason || '原因未知'}` })
      return
    }
    this.isReaderMode = !this.isReaderMode
  }

  private onTtsPlaceholder() {
    Prompt.showToast({ message: '朗读引擎暂未接入，当前版本已预留控制入口' })
  }

  onTtsRequest() {
    this.startTtsFromCurrentPage()
  }

  private async warmupSpeechEngine() {
    const script = `(function() {
      try {
        if (!('speechSynthesis' in window)) {
          return 'warmup|no_api';
        }
        const synth = window.speechSynthesis;
        if (synth.resume) {
          synth.resume();
        }
        const voices = synth.getVoices ? synth.getVoices() : [];
        return 'warmup|voices=' + (voices ? voices.length : 0);
      } catch (e) {
        return 'warmup|error';
      }
    })();`
    const result = await this.runScript(script)
    const decoded = this.decodeScriptResult(result)
    this.ttsDebugInfo = decoded
  }

  private async startTtsFromCurrentPage() {
    if (!this.isSearched) {
      Prompt.showToast({ message: '请先打开网页后再使用朗读' })
      return
    }

    // 必须等待上次会话完整停止，否则代次锁会与新会话并发冲突，导致首击无声。
    await this.stopTts(false)
    this.ttsPlayGeneration = this.ttsPlayGeneration + 1
    this.ttsErrorReason = ''
    this.ttsOutputMode = 'native'
    this.ttsVoiceBlocked = false
    this.ttsAudioBlocked = false
    this.ttsManualRetrying = false
    this.ttsNativeReady = false
    // 默认允许原生兜底，仅在确认不可用后熔断。
    this.ttsNativeFallbackDisabled = false
    this.ttsUnits = []
    this.ttsUnitParagraphIndex = []
    this.ttsCurrentIndex = 0
    this.ttsLoadedUnitIndex = -1

    if (this.isReaderMode && this.readerParagraphs.length > 0) {
      this.ttsSource = 'reader'
      this.buildTtsUnitsFromReader()
    } else {
      this.ttsSource = 'page'
      await this.buildTtsUnitsFromPageText()
    }

    if (this.ttsUnits.length === 0) {
      const reason = this.ttsErrorReason.length > 0 ? this.ttsErrorReason : '未提取到可朗读文本'
      Prompt.showToast({ message: `朗读失败：${reason}` })
      return
    }

    this.ttsPanelVisible = true
    this.ttsPlaying = false
    await this.warmupSpeechEngine()
    this.ttsRuntimeLogs = []
    this.flushTtsRuntimeLogs()
    this.setTtsActionLog('start', `units=${this.ttsUnits.length}`)
    Prompt.showToast({ message: `已准备 ${this.ttsUnits.length} 句，点击播放开始朗读` })
  }

  private buildHighlightOnlyScript(text: string): string {
    const escaped = text
      .replace(/\\/g, '\\\\')
      .replace(/'/g, "\\'")
      .replace(/\n/g, ' ')

    return `(function() {
      try {
        const target = '${escaped}';

        if (window.__readerMark && window.__readerMark.parentNode) {
          const p = window.__readerMark.parentNode;
          const t = document.createTextNode(window.__readerMark.textContent || '');
          p.replaceChild(t, window.__readerMark);
          window.__readerMark = null;
        }

        const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
        let node = null;
        const key = target.length > 26 ? target.substring(0, 26) : target;
        while ((node = walker.nextNode())) {
          if (!node || !node.nodeValue) continue;
          const idx = node.nodeValue.indexOf(key);
          if (idx >= 0) {
            const range = document.createRange();
            range.setStart(node, idx);
            range.setEnd(node, Math.min(node.nodeValue.length, idx + key.length));
            const mark = document.createElement('span');
            mark.style.background = '#FFE58F';
            mark.style.color = '#111';
            range.surroundContents(mark);
            window.__readerMark = mark;
            break;
          }
        }

        return 'ok|highlight';
      } catch (e) {
        return 'error|highlight';
      }
    })();`
  }

  private buildTtsUnitsFromReader() {
    let filtered = 0
    for (let i = 0; i < this.readerParagraphs.length; i++) {
      const paragraph = this.cleanTtsText(this.readerParagraphs[i])
      if (paragraph.length === 0) {
        continue
      }

      const units = this.splitToTtsUnits(paragraph)
      for (const unit of units) {
        if (this.shouldSkipTtsUnit(unit)) {
          filtered++
          continue
        }
        this.ttsUnits.push(unit)
        this.ttsUnitParagraphIndex.push(i)
      }
    }

    if (this.ttsUnits.length === 0) {
      this.ttsErrorReason = `阅读器文本过滤后为空（过滤 ${filtered} 条）`
    }
  }

  private async buildTtsUnitsFromPageText() {
    const rawText = await this.runScript(this.readerTextScript)
    const plain = this.decodeScriptResult(rawText)
    if (plain.length < 20) {
      this.ttsErrorReason = '页面可见文本过少，可能尚未加载完成'
      return
    }

    let filtered = 0
    const blocks = plain
      .split(/\n{2,}/)
      .map(item => item.trim())
      .filter(item => item.length >= 8)

    for (const block of blocks) {
      const cleaned = this.cleanTtsText(block)
      if (cleaned.length === 0) {
        continue
      }

      const units = this.splitToTtsUnits(cleaned)
      for (const unit of units) {
        if (this.shouldSkipTtsUnit(unit)) {
          filtered++
          continue
        }
        this.ttsUnits.push(unit)
        this.ttsUnitParagraphIndex.push(-1)
      }
    }

    this.ttsUnits = this.dedupeTtsUnits(this.ttsUnits).slice(0, 300)
    if (this.ttsUnits.length === 0) {
      this.ttsErrorReason = `页面文本过滤后为空（过滤 ${filtered} 条）`
    }
  }

  private cleanTtsText(input: string): string {
    return input
      .replace(/<[^>]+>/g, ' ')
      .replace(/\s+/g, ' ')
      .trim()
  }

  private splitToTtsUnits(text: string): string[] {
    const units: string[] = []
    const blocks = text
      .split(/[。！？；!?;]|\n{2,}/)
      .map(item => item.trim())
      .filter(item => item.length > 0)

    for (const block of blocks) {
      if (block.length <= 80) {
        units.push(block)
      } else {
        const sub = block.split(/[，,]/).map(item => item.trim()).filter(item => item.length >= 6)
        if (sub.length > 0) {
          for (const item of sub) {
            units.push(item)
          }
        } else {
          units.push(block)
        }
      }
    }

    return units
  }

  private shouldSkipTtsUnit(text: string): boolean {
    if (text.length < 6) {
      return true
    }
    if (/(首页|上一页|下一页|返回顶部|目录|导航|菜单|登录|注册|免责声明|版权|隐私政策|cookie|APP下载|打开APP|分享|编辑|收藏|阅读原文)/.test(text)) {
      return true
    }
    if (/(function\s*\(|=>|\{\s*\}|<\/?[a-z]|console\.|var\s+|let\s+|const\s+|http[s]?:\/\/)/i.test(text)) {
      return true
    }
    const symbolChars = text.replace(/[\u4e00-\u9fa5a-zA-Z0-9]/g, '')
    return symbolChars.length / text.length > 0.45
  }

  private dedupeTtsUnits(units: string[]): string[] {
    const out: string[] = []
    const seen = new Set<string>()
    for (const item of units) {
      const key = item.replace(/\s+/g, ' ').trim()
      if (key.length === 0 || seen.has(key)) {
        continue
      }
      seen.add(key)
      out.push(key)
    }
    return out
  }

  private buildCloudAudioUrlsForNative(text: string): string[] {
    const encoded = encodeURIComponent(text)
    return [
      `https://fanyi.baidu.com/gettts?lan=zh&spd=5&source=web&text=${encoded}`,
      `http://fanyi.baidu.com/gettts?lan=zh&spd=5&source=web&text=${encoded}`,
      `https://tts.baidu.com/text2audio?lan=zh&ie=UTF-8&spd=5&text=${encoded}`,
      `http://tts.baidu.com/text2audio?lan=zh&ie=UTF-8&spd=5&text=${encoded}`,
      `https://dict.youdao.com/dictvoice?type=1&audio=${encoded}`,
      `https://translate.googleapis.com/translate_tts?ie=UTF-8&client=gtx&tl=zh-CN&q=${encoded}`
    ]
  }

  private async releaseNativeAudioPlayer() {
    if (!this.nativeAudioPlayer) {
      if (this.nativeAudioFd >= 0) {
        try {
          fs.closeSync(this.nativeAudioFd)
        } catch (error) {
          console.warn('close native fd failed: ' + error)
        }
        this.nativeAudioFd = -1
      }
      return
    }
    try {
      await this.nativeAudioPlayer.release()
    } catch (error) {
      console.warn('release native player failed: ' + error)
    }
    if (this.nativeAudioFd >= 0) {
      try {
        fs.closeSync(this.nativeAudioFd)
      } catch (error) {
        console.warn('close native fd failed: ' + error)
      }
      this.nativeAudioFd = -1
    }
    this.nativeAudioPlayer = null
    this.ttsNativeReady = false
  }

  private async stopNativeAudioInternal() {
    if (!this.nativeAudioPlayer) {
      return
    }
    try {
      await this.nativeAudioPlayer.stop()
    } catch (error) {
      console.warn('stop native player failed: ' + error)
    }
    await this.releaseNativeAudioPlayer()
  }

  private async waitNativePlayerReady(player: media.AVPlayer, tag: string): Promise<void> {
    // AVPlayer 设置 url/fdSrc 后进入 initialized 是异步过程，过早 prepare 会触发 unsupport prepare。
    for (let i = 0; i < 20; i++) {
      const state = `${player.state}`
      if (state === 'initialized' || state === 'stopped' || state === 'prepared' || state === 'completed') {
        this.ttsDebugInfo = `${this.ttsDebugInfo}; native-state-${tag}=${state}`
        return
      }
      await new Promise<void>((resolve) => {
        setTimeout(() => resolve(), 60)
      })
    }
    this.ttsDebugInfo = `${this.ttsDebugInfo}; native-state-${tag}=timeout:${player.state}`
  }

  private clearNativeTempAudio() {
    if (this.nativeTempAudioPath.length === 0) {
      return
    }
    try {
      fs.unlinkSync(this.nativeTempAudioPath)
    } catch (error) {
      console.warn('unlink native temp failed: ' + error)
    }
    this.nativeTempAudioPath = ''
  }

  private async downloadAudioToCache(url: string): Promise<string> {
    const request = http.createHttp()
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 10000,
        readTimeout: 10000,
        header: {
          'User-Agent': 'Mozilla/5.0 (Linux; HarmonyOS) AppleWebKit/537.36',
          'Referer': 'https://fanyi.baidu.com/'
        }
      })

      const payload = response.result as ArrayBuffer
      const payloadLen = payload ? payload.byteLength : 0
      this.ttsDebugInfo = `${this.ttsDebugInfo}; dl=code${response.responseCode}|len=${payloadLen}`

      if (response.responseCode !== 200 || !payload || payloadLen <= 0) {
        return ''
      }

      const uiContext = getContext(this) as CachePathContext
      const localPath = `${uiContext.cacheDir}/tts_${Date.now()}.mp3`
      const file = fs.openSync(localPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC)
      fs.writeSync(file.fd, payload)
      fs.closeSync(file)
      this.nativeTempAudioPath = localPath
      return localPath
    } catch (error) {
      this.ttsDebugInfo = `${this.ttsDebugInfo}; dl=error|${String(error)}`
      console.warn('download audio failed: ' + error)
      return ''
    } finally {
      request.destroy()
    }
  }

  private async playCurrentUnitWithNativeAudio(text: string): Promise<boolean> {
    const urls = this.buildCloudAudioUrlsForNative(text)
    await this.stopNativeAudioInternal()
    this.clearNativeTempAudio()

    for (let i = 0; i < urls.length; i++) {
      try {
        const player = await media.createAVPlayer()
        this.nativeAudioPlayer = player
        player.url = urls[i]
        await this.waitNativePlayerReady(player, `${i + 1}-direct`)
        await player.prepare()
        await player.play()
        this.ttsNativeReady = true
        this.ttsDebugInfo = `${this.ttsDebugInfo}; native=ok|src=${i + 1}`
        return true
      } catch (error) {
        this.ttsDebugInfo = `${this.ttsDebugInfo}; native=fail|src=${i + 1}|direct|${String(error)}`
        await this.releaseNativeAudioPlayer()

        const localPath = await this.downloadAudioToCache(urls[i])
        if (localPath.length > 0) {
          try {
            const localPlayer = await media.createAVPlayer()
            this.nativeAudioPlayer = localPlayer
            const file = fs.openSync(localPath, fs.OpenMode.READ_ONLY)
            this.nativeAudioFd = file.fd
            const stat = fs.statSync(localPath)
            localPlayer.fdSrc = {
              fd: this.nativeAudioFd,
              offset: 0,
              length: stat.size
            }
            await this.waitNativePlayerReady(localPlayer, `${i + 1}-cache`)
            await localPlayer.prepare()
            await localPlayer.play()
            this.ttsNativeReady = true
            this.ttsDebugInfo = `${this.ttsDebugInfo}; native=ok|src=${i + 1}|cache`
            return true
          } catch (localError) {
            this.ttsDebugInfo = `${this.ttsDebugInfo}; native=fail|src=${i + 1}|cache|${String(localError)}`
            await this.releaseNativeAudioPlayer()
            this.clearNativeTempAudio()
          }
        }
      }
    }

    this.ttsNativeReady = false
    return false
  }

  private buildSpeakScript(text: string, speed: number): string {
    const escaped = text
      .replace(/\\/g, '\\\\')
      .replace(/'/g, "\\'")
      .replace(/\n/g, ' ')

    return `(function() {
      try {
        const target = '${escaped}';
        const rate = ${speed.toFixed(2)};

        if (window.__readerMark && window.__readerMark.parentNode) {
          const p = window.__readerMark.parentNode;
          const t = document.createTextNode(window.__readerMark.textContent || '');
          p.replaceChild(t, window.__readerMark);
          window.__readerMark = null;
        }

        const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
        let node = null;
        const key = target.length > 26 ? target.substring(0, 26) : target;
        while ((node = walker.nextNode())) {
          if (!node || !node.nodeValue) continue;
          const idx = node.nodeValue.indexOf(key);
          if (idx >= 0) {
            const range = document.createRange();
            range.setStart(node, idx);
            range.setEnd(node, Math.min(node.nodeValue.length, idx + key.length));
            const mark = document.createElement('span');
            mark.style.background = '#FFE58F';
            mark.style.color = '#111';
            range.surroundContents(mark);
            window.__readerMark = mark;
            break;
          }
        }

        if ('speechSynthesis' in window) {
          const synth = window.speechSynthesis;
          const voices = synth.getVoices ? synth.getVoices() : [];
          const voiceCount = voices ? voices.length : 0;
          const ua = (navigator && navigator.userActivation && navigator.userActivation.isActive) ? '1' : '0';

          if (window.__readerAudio) {
            try {
              window.__readerAudio.pause();
              window.__readerAudio.currentTime = 0;
            } catch (e) {}
            window.__readerAudio = null;
          }

          synth.cancel();
          const utter = new SpeechSynthesisUtterance(target);
          utter.rate = rate;
          utter.volume = 1;
          utter.pitch = 1;

           if (voiceCount > 0) {
             const zhVoice = voices.find(v => (v.lang || '').toLowerCase().startsWith('zh'));
             if (zhVoice) {
               utter.voice = zhVoice;
               utter.lang = zhVoice.lang || 'zh-CN';
             } else {
               utter.voice = voices[0];
               utter.lang = voices[0].lang || '';
             }
           } else {
             // voices=0 时交给内核默认策略，避免固定中文语种导致拒播。
             utter.lang = '';
           }

          utter.onstart = function() { window.__readerSpeechState = 'start'; };
          utter.onend = function() { window.__readerSpeechState = 'end'; };
          utter.onerror = function(e) { window.__readerSpeechState = 'error:' + (e && e.error ? e.error : 'unknown'); };

          window.__readerSpeechState = 'pending';
          if (synth.resume) {
            synth.resume();
          }
          if (voiceCount > 0) {
            synth.speak(utter);
            return 'ok|mode=speech|voices=' + voiceCount + '|ua=' + ua + '|pending=' + (synth.pending ? '1' : '0') + '|speaking=' + (synth.speaking ? '1' : '0');
          }

          const cloudUrls = [
            'https://fanyi.baidu.com/gettts?lan=zh&spd=5&source=web&text=' + encodeURIComponent(target),
            'https://tts.baidu.com/text2audio?lan=zh&ie=UTF-8&spd=5&text=' + encodeURIComponent(target),
            'https://dict.youdao.com/dictvoice?type=1&audio=' + encodeURIComponent(target),
            'https://translate.googleapis.com/translate_tts?ie=UTF-8&client=gtx&tl=zh-CN&q=' + encodeURIComponent(target)
          ];
          const audio = new Audio(cloudUrls[0]);
          audio.preload = 'auto';
          window.__readerAudioTry = 0;
          window.__readerSentenceEnded = 0;
          window.__readerAudioActivePlay = 0;
          window.__readerUnlocking = 0;
          audio.onloadedmetadata = function() { window.__readerSpeechState = 'audio_loaded'; };
          audio.oncanplay = function() { window.__readerSpeechState = 'audio_canplay'; };
          audio.onplay = function() {
            if (window.__readerUnlocking === 1) {
              window.__readerSpeechState = 'audio_unlock_play';
              return;
            }
            window.__readerSpeechState = 'audio_play';
          };
          audio.onended = function() {
            if (window.__readerUnlocking === 1 || window.__readerAudioActivePlay !== 1) {
              window.__readerSpeechState = 'audio_unlock_end';
              return;
            }
            window.__readerSpeechState = 'audio_end';
            window.__readerSentenceEnded = 1;
            window.__readerAudioActivePlay = 0;
          };
          audio.onerror = function() {
            if (window.__readerAudioTry < cloudUrls.length - 1) {
              window.__readerAudioTry = window.__readerAudioTry + 1;
              window.__readerSpeechState = 'audio_retry';
              audio.src = cloudUrls[window.__readerAudioTry];
              audio.load();
              return;
            }
            window.__readerSpeechState = 'audio_error';
          };
          window.__readerAudio = audio;
          audio.load();
          window.__readerSpeechState = 'audio_prepared';
          return 'ok|mode=audio|voices=' + voiceCount + '|ua=' + ua + '|srcs=' + cloudUrls.length + '|prepared=1';
        }
        return 'no_api|speechSynthesis unavailable';
      } catch (e) {
        return 'error|' + String(e);
      }
    })();`
  }

  private speechProbeScript(): string {
    return `(function() {
      try {
        if (!('speechSynthesis' in window)) {
          return 'probe|no_api';
        }
        const synth = window.speechSynthesis;
        const voices = synth.getVoices ? synth.getVoices() : [];
        const state = window.__readerSpeechState ? String(window.__readerSpeechState) : 'none';
        const hasAudio = window.__readerAudio ? '1' : '0';
        const audioPaused = window.__readerAudio ? (window.__readerAudio.paused ? '1' : '0') : '1';
        const audioTry = (typeof window.__readerAudioTry === 'number') ? String(window.__readerAudioTry) : '0';
        const audioSrc = (window.__readerAudio && window.__readerAudio.src) ? String(window.__readerAudio.src) : '';
        return 'probe|voices=' + (voices ? voices.length : 0) + '|pending=' + (synth.pending ? '1' : '0') + '|speaking=' + (synth.speaking ? '1' : '0') + '|state=' + state + '|audio=' + hasAudio + '|audioPaused=' + audioPaused + '|audioTry=' + audioTry + '|audioSrc=' + audioSrc;
      } catch (e) {
        return 'probe|error';
      }
    })();`
  }

  private async retrySpeakAfterVoiceWarmup() {
    if (this.ttsManualRetrying) {
      return
    }
    this.ttsManualRetrying = true
    this.ttsVoiceBlocked = false
    this.ttsAudioBlocked = false
    this.ttsErrorReason = this.ttsOutputMode === 'audio' ? '音频解锁中，正在重试...' : '语音包加载中，正在重试...'
    this.ttsPlayGeneration = this.ttsPlayGeneration + 1
    this.ttsPlaying = true
    this.clearTtsTimer()

    setTimeout(async () => {
      if (!this.ttsPanelVisible || this.ttsUnits.length === 0) {
        this.ttsManualRetrying = false
        return
      }
      await this.speakAndHighlightCurrentUnit(false)
      if (this.ttsPlaying) {
        this.scheduleNextTts()
      }
      this.ttsManualRetrying = false
    }, 1200)
  }

  private audioUnlockScript(): string {
    return `(function() {
      try {
        if (!window.__readerAudio) {
          return 'unlock|no_audio';
        }
        const audio = window.__readerAudio;
        window.__readerUnlocking = 1;
        window.__readerAudioActivePlay = 0;
        const oldMuted = !!audio.muted;
        const oldVolume = typeof audio.volume === 'number' ? audio.volume : 1;
        audio.muted = true;
        audio.volume = 0;
        const p = audio.play();
        if (p && p.catch) {
          p.catch(function() {
            window.__readerSpeechState = 'audio_blocked';
            window.__readerUnlocking = 0;
          });
        }
        audio.pause();
        audio.currentTime = 0;
        audio.muted = oldMuted;
        audio.volume = oldVolume;
        window.__readerUnlocking = 0;
        window.__readerSpeechState = 'audio_unlock_ready';
        return 'unlock|triggered|paused=' + (audio.paused ? '1' : '0');
      } catch (e) {
        window.__readerUnlocking = 0;
        return 'unlock|error';
      }
    })();`
  }

  private playCurrentAudioScript(): string {
    return `(function() {
      try {
        if (!window.__readerAudio) {
          return 'resume|no_audio';
        }
        const audio = window.__readerAudio;
        window.__readerUnlocking = 0;
        window.__readerAudioActivePlay = 1;
        window.__readerSentenceEnded = 0;
        window.__readerSpeechState = 'audio_play_try';
        const p = audio.play();
        if (p && p.catch) {
          p.catch(function() {
            window.__readerAudioActivePlay = 0;
            window.__readerSpeechState = 'audio_blocked';
          });
        }
        return 'resume|triggered|paused=' + (audio.paused ? '1' : '0');
      } catch (e) {
        window.__readerAudioActivePlay = 0;
        window.__readerSpeechState = 'audio_error';
        return 'resume|error';
      }
    })();`
  }

  private consumeAudioEndedScript(): string {
    return `(function() {
      try {
        if (window.__readerSentenceEnded === 1) {
          window.__readerSentenceEnded = 0;
          return 'ended';
        }
        return window.__readerSpeechState ? String(window.__readerSpeechState) : 'none';
      } catch (e) {
        return 'error';
      }
    })();`
  }

  private armTapResumeScript(): string {
    return `(function() {
      try {
        if (!window.__readerAudio) {
          return 'tap-resume|no_audio';
        }
        if (window.__readerTapResumeArmed === 1) {
          return 'tap-resume|armed';
        }

        window.__readerTapResumeArmed = 1;

        const run = function() {
          try {
            if (!window.__readerAudio) {
              window.__readerTapResumeArmed = 0;
              return;
            }
            window.__readerUnlocking = 0;
            window.__readerAudioActivePlay = 1;
            window.__readerSentenceEnded = 0;
            window.__readerSpeechState = 'audio_play_try';
            const p = window.__readerAudio.play();
            if (p && p.catch) {
              p.catch(function() {
                window.__readerAudioActivePlay = 0;
                window.__readerSpeechState = 'audio_blocked';
              });
            }
          } catch (e) {
            window.__readerAudioActivePlay = 0;
            window.__readerSpeechState = 'audio_error';
          } finally {
            window.__readerTapResumeArmed = 0;
          }
        };

        document.addEventListener('pointerdown', run, { once: true, capture: true });
        document.addEventListener('touchstart', run, { once: true, capture: true });
        document.addEventListener('click', run, { once: true, capture: true });
        return 'tap-resume|ok';
      } catch (e) {
        return 'tap-resume|error';
      }
    })();`
  }

  private async triggerAudioPlayback(triggerFrom: string): Promise<boolean> {
    const unlock = await this.runScript(this.audioUnlockScript())
    const unlockResult = this.decodeScriptResult(unlock)

    const first = await this.runScript(this.playCurrentAudioScript())
    let firstResult = this.decodeScriptResult(first)

    this.ttsDebugInfo = `${this.ttsDebugInfo}; unlock=${unlockResult}; play1=${firstResult}`
    this.setTtsActionLog(triggerFrom, `unlock=${unlockResult}|play1=${firstResult}`)

    let immediateOk = firstResult.includes('resume|ok') || (firstResult.includes('resume|triggered') && !firstResult.includes('paused=1'))

    if (!immediateOk) {
      const second = await this.runScript(this.playCurrentAudioScript())
      const secondResult = this.decodeScriptResult(second)
      this.ttsDebugInfo = `${this.ttsDebugInfo}; play2=${secondResult}`
      immediateOk = secondResult.includes('resume|ok') || (secondResult.includes('resume|triggered') && !secondResult.includes('paused=1'))
    }

    // play() 为异步触发，paused=1 可能是短暂状态；延迟探针再判断最终是否进入播放态。
    await new Promise<void>((resolve) => {
      setTimeout(() => resolve(), 220)
    })
    const probe = await this.runScript(this.speechProbeScript())
    const probeText = this.decodeScriptResult(probe)
    this.ttsDebugInfo = `${this.ttsDebugInfo}; probe=${probeText}`

    const probeOk = probeText.includes('state=audio_play')
      || probeText.includes('state=audio_end')
      || probeText.includes('audioPaused=0')
      || probeText.includes('speaking=1')

    const ok = immediateOk || probeOk
    if (!ok) {
      const armedRaw = await this.runScript(this.armTapResumeScript())
      const armed = this.decodeScriptResult(armedRaw)
      this.setTtsActionLog(`${triggerFrom}-tap-arm`, armed)
      this.ttsDebugInfo = `${this.ttsDebugInfo}; tap=${armed}`
    }
    return ok
  }

  private async tryNativeFallback(scene: string): Promise<boolean> {
    if (this.ttsNativeFallbackDisabled || this.ttsUnits.length === 0 || this.ttsCurrentIndex >= this.ttsUnits.length) {
      return false
    }

    this.setTtsActionLog(`${scene}-native`, `idx=${this.ttsCurrentIndex}`)
    const ok = await this.playCurrentUnitWithNativeAudio(this.ttsUnits[this.ttsCurrentIndex])
    if (ok) {
      await this.runScript(this.pauseSpeechScript)
      this.ttsOutputMode = 'native'
      this.ttsLoadedUnitIndex = this.ttsCurrentIndex
      this.ttsErrorReason = ''
      this.ttsAudioBlocked = false
      this.ttsVoiceBlocked = false
      this.ttsPlaying = true
      this.setTtsActionLog(`${scene}-native-ok`, `idx=${this.ttsCurrentIndex}`)
      this.scheduleNextTts()
      return true
    }

    this.ttsNativeFallbackDisabled = true
    this.setTtsActionLog(`${scene}-native-fail`, `idx=${this.ttsCurrentIndex}`)
    return false
  }

  private markTtsPlaybackFailed(message: string, markAudioBlocked: boolean = true) {
    this.ttsErrorReason = message
    if (markAudioBlocked) {
      this.ttsAudioBlocked = true
    }
    this.ttsPlaying = false
    this.clearTtsTimer()
  }

  private async speakAndHighlightCurrentUnit(allowVoiceRetry: boolean = true) {
    if (this.ttsUnits.length === 0 || this.ttsCurrentIndex >= this.ttsUnits.length) {
      return
    }

    const playGen = this.ttsPlayGeneration

    // 新链路：原生优先。若失败再回退到 Web 链路，保留稳定版可回退能力。
    if (this.ttsOutputMode === 'native') {
      const markRaw = await this.runScript(this.buildHighlightOnlyScript(this.ttsUnits[this.ttsCurrentIndex]))
      const markResult = this.decodeScriptResult(markRaw)
      const nativeOk = await this.playCurrentUnitWithNativeAudio(this.ttsUnits[this.ttsCurrentIndex])
      if (playGen !== this.ttsPlayGeneration) {
        return
      }
      if (nativeOk) {
        this.ttsOutputMode = 'native'
        this.ttsLoadedUnitIndex = this.ttsCurrentIndex
        this.ttsErrorReason = ''
        this.ttsAudioBlocked = false
        this.ttsVoiceBlocked = false
        this.ttsPlaying = true
        this.ttsDebugInfo = `native-main|ok; ${markResult}`
        this.setTtsActionLog('native-main-ok', `idx=${this.ttsCurrentIndex}`)
        return
      }

      this.ttsDebugInfo = `native-main|fail; ${markResult}`
      this.setTtsActionLog('native-main-fail', `idx=${this.ttsCurrentIndex}`)
      this.ttsErrorReason = '原生主通道失败，已自动回退网页语音链路'
    }

    const script = this.buildSpeakScript(this.ttsUnits[this.ttsCurrentIndex], this.ttsPlaySpeed)
    const result = await this.runScript(script)
    if (playGen !== this.ttsPlayGeneration) {
      return
    }
    const decoded = this.decodeScriptResult(result)
    this.ttsOutputMode = decoded.includes('mode=audio') ? 'audio' : 'speech'
    this.ttsDebugInfo = decoded

    if (decoded.includes('mode=audio')) {
      this.ttsOutputMode = 'audio'
    }

    this.ttsLoadedUnitIndex = this.ttsCurrentIndex

    if (decoded.startsWith('no_api|')) {
      this.ttsErrorReason = `当前 Web 内核不支持发声：${decoded.replace('no_api|', '')}`
      this.ttsPlaying = false
      Prompt.showToast({ message: this.ttsErrorReason })
      return
    }

    if (decoded.startsWith('error|')) {
      this.ttsErrorReason = `朗读脚本异常：${decoded.replace('error|', '')}`
      this.ttsPlaying = false
      Prompt.showToast({ message: this.ttsErrorReason })
      return
    }

    if (!decoded.startsWith('ok|')) {
      this.ttsErrorReason = `朗读状态未知：${decoded}`
      this.ttsPlaying = false
      Prompt.showToast({ message: this.ttsErrorReason })
      return
    }

    setTimeout(async () => {
      if (playGen !== this.ttsPlayGeneration) {
        return
      }
      const probe = await this.runScript(this.speechProbeScript())
      if (playGen !== this.ttsPlayGeneration) {
        return
      }
      const probeText = this.decodeScriptResult(probe)
      const modeTip = decoded.includes('mode=audio') ? ' [云端音频兜底]' : ''
      const compactDecoded = decoded.replace(/voices=0/g, 'voices=0(本机缺失)')
      this.ttsDebugInfo = `${compactDecoded}${modeTip}; ${probeText}`

      if (probeText.includes('voices=0') && !decoded.includes('mode=audio')) {
        this.ttsErrorReason = '发声引擎未加载语音包（voices=0），请手动点“重试语音”'
        this.ttsVoiceBlocked = true
        this.ttsAudioBlocked = false
        this.ttsPlaying = false
        this.clearTtsTimer()
      } else if (decoded.includes('mode=audio')) {
        if (probeText.includes('state=audio_error')) {
          let tried = '未知'
          const tryMatch = probeText.match(/audioTry=(\d+)/)
          if (tryMatch && tryMatch.length > 1) {
            tried = String(Number(tryMatch[1]) + 1)
          }
          this.ttsErrorReason = `云端音频加载失败（已尝试 ${tried} 个音源），可能被防盗链/策略拒绝`
          this.ttsPlaying = false
          this.clearTtsTimer()
        } else if (probeText.includes('state=audio_blocked')) {
          this.ttsErrorReason = '云端音频被自动播放策略拦截，请点击“播放/解锁音频”'
          this.ttsAudioBlocked = true
          this.ttsPlaying = false
          this.clearTtsTimer()
        } else if (probeText.includes('state=audio_retry')) {
          this.ttsErrorReason = '云端音频主源失败，正在切换备用音源...'
        } else if (probeText.includes('state=audio_loaded') || probeText.includes('state=audio_canplay')) {
          this.ttsErrorReason = '音频资源已加载，请点击“播放”触发声音'
          this.ttsAudioBlocked = true
        } else {
          this.ttsErrorReason = ''
          this.ttsVoiceBlocked = false
          this.ttsAudioBlocked = false
        }
      } else if (probeText.includes('state=error:')) {
        this.ttsErrorReason = `发声回调报错：${probeText}`
      } else if (probeText.includes('pending=0') && probeText.includes('speaking=0') && probeText.includes('state=pending')) {
        this.ttsErrorReason = '发声可能被策略拦截，请手动点击播放重试'
      } else if (probeText.includes('state=start') || probeText.includes('speaking=1')) {
        this.ttsErrorReason = ''
        this.ttsVoiceBlocked = false
      }
    }, 500)
  }

  private ttsDurationMs(text: string): number {
    const base = Math.max(1300, Math.min(6500, Math.floor(text.length * 55)))
    return Math.floor(base / Math.max(this.ttsPlaySpeed, 0.5))
  }

  private clearTtsTimer() {
    if (this.ttsTimer > 0) {
      clearTimeout(this.ttsTimer)
      this.ttsTimer = -1
    }
  }

  private scheduleNextTts() {
    this.clearTtsTimer()
    if (!this.ttsPlaying || this.ttsUnits.length === 0) {
      return
    }

    if (this.ttsOutputMode === 'native') {
      const playGenNative = this.ttsPlayGeneration
      this.ttsTimer = setTimeout(async () => {
        if (playGenNative !== this.ttsPlayGeneration || !this.ttsPlaying) {
          return
        }

        if (!this.nativeAudioPlayer) {
          this.markTtsPlaybackFailed('原生播放器实例丢失，请重试')
          return
        }

        const nativeState = `${this.nativeAudioPlayer.state}`
        if (nativeState === 'completed') {
          if (this.ttsCurrentIndex >= this.ttsUnits.length - 1) {
            this.ttsPlaying = false
            Prompt.showToast({ message: '朗读完成' })
            return
          }

          this.ttsCurrentIndex = this.ttsCurrentIndex + 1
          await this.speakAndHighlightCurrentUnit()
        } else if (nativeState === 'error') {
          this.markTtsPlaybackFailed('原生播放器状态异常，请重试')
          return
        }

        this.scheduleNextTts()
      }, 260)
      return
    }

    if (this.ttsOutputMode === 'audio') {
      const playGenAudio = this.ttsPlayGeneration
      this.ttsTimer = setTimeout(async () => {
        if (playGenAudio !== this.ttsPlayGeneration || !this.ttsPlaying) {
          return
        }

        const stateRaw = await this.runScript(this.consumeAudioEndedScript())
        const state = this.decodeScriptResult(stateRaw)

        if (state === 'ended') {
          if (this.ttsCurrentIndex >= this.ttsUnits.length - 1) {
            this.ttsPlaying = false
            Prompt.showToast({ message: '朗读完成' })
            return
          }

          this.ttsCurrentIndex = this.ttsCurrentIndex + 1
          await this.speakAndHighlightCurrentUnit()

          const ok = await this.triggerAudioPlayback('auto-next')
          if (!ok) {
            const nativeRecovered = await this.tryNativeFallback('auto-next')
            if (!nativeRecovered) {
              this.markTtsPlaybackFailed('下一句触发失败，网页音频被策略拦截')
            }
            return
          }
        } else if (state === 'audio_blocked' || state === 'error') {
          const nativeRecovered = await this.tryNativeFallback('audio-state')
          if (!nativeRecovered) {
            this.markTtsPlaybackFailed('音频播放被拦截或异常，请点击播放继续')
          }
          return
        }

        this.scheduleNextTts()
      }, 280)
      return
    }

    const text = this.ttsUnits[this.ttsCurrentIndex]
    const delay = this.ttsDurationMs(text)
    const playGen = this.ttsPlayGeneration
    this.ttsTimer = setTimeout(async () => {
      if (playGen !== this.ttsPlayGeneration) {
        return
      }
      if (!this.ttsPlaying) {
        return
      }

      if (this.ttsCurrentIndex >= this.ttsUnits.length - 1) {
        this.ttsPlaying = false
        Prompt.showToast({ message: '朗读完成' })
        return
      }

      this.ttsCurrentIndex = this.ttsCurrentIndex + 1
      await this.speakAndHighlightCurrentUnit()
      this.scheduleNextTts()
    }, delay)
  }

  private async pauseTts() {
    if (this.ttsCommandLocked) {
      return
    }
    this.ttsCommandLocked = true
    this.ttsPlayGeneration = this.ttsPlayGeneration + 1
    this.ttsPlaying = false
    this.clearTtsTimer()
    if (this.nativeAudioPlayer) {
      try {
        await this.nativeAudioPlayer.pause()
      } catch (error) {
        console.warn('pause native player failed: ' + error)
      }
    }
    const result = await this.runScript(this.pauseSpeechScript)
    this.ttsDebugInfo = `pause:${this.decodeScriptResult(result)}`
    this.setTtsActionLog('pause')
    this.ttsCommandLocked = false
  }

  private async resumeTts() {
    if (this.ttsCommandLocked || this.ttsPlaying) {
      return
    }
    this.setTtsActionLog('resume-click', `mode=${this.ttsOutputMode}|idx=${this.ttsCurrentIndex}`)
    this.ttsCommandLocked = true
    this.ttsPlayGeneration = this.ttsPlayGeneration + 1
    if (this.ttsUnits.length === 0) {
      this.ttsCommandLocked = false
      return
    }
    this.ttsPlaying = true
    await this.speakAndHighlightCurrentUnit()

    if (!this.ttsPlaying) {
      this.ttsCommandLocked = false
      return
    }

    const mode = `${this.ttsOutputMode}`
    if (mode === 'audio') {
      const ok = await this.triggerAudioPlayback('resume-audio')
      if (!ok) {
        const nativeRecovered = await this.tryNativeFallback('resume-audio')
        if (!nativeRecovered) {
          this.markTtsPlaybackFailed('当前页面未能触发音频，且原生兜底失败：请点击网页任意位置一次，将自动继续播放')
          this.ttsCommandLocked = false
          return
        }
      }
    }

    this.scheduleNextTts()
    this.setTtsActionLog('resume', `mode=${this.ttsOutputMode}`)
    this.ttsCommandLocked = false
  }

  private async stopTts(hidePanel: boolean) {
    this.ttsCommandLocked = false
    this.ttsPlayGeneration = this.ttsPlayGeneration + 1
    this.ttsPlaying = false
    this.clearTtsTimer()
    this.ttsCurrentIndex = 0
    this.ttsLoadedUnitIndex = -1
    this.ttsVoiceBlocked = false
    this.ttsAudioBlocked = false
    this.ttsManualRetrying = false
    this.ttsCommandLocked = false
    this.ttsNativeFallbackDisabled = true
    await this.stopNativeAudioInternal()
    this.clearNativeTempAudio()
    const result = await this.runScript(this.cancelSpeechScript)
    this.ttsDebugInfo = `stop:${this.decodeScriptResult(result)}`
    this.setTtsActionLog('stop')
    if (hidePanel) {
      this.ttsPanelVisible = false
    }
  }

  private async prevTtsUnit() {
    if (this.ttsUnits.length === 0) {
      return
    }
    this.ttsCurrentIndex = Math.max(this.ttsCurrentIndex - 1, 0)
    this.ttsPlayGeneration = this.ttsPlayGeneration + 1
    if (this.ttsPlaying) {
      await this.speakAndHighlightCurrentUnit()
      if (this.ttsOutputMode === 'audio') {
        const ok = await this.triggerAudioPlayback('prev-audio')
        if (!ok) {
          const nativeRecovered = await this.tryNativeFallback('prev-audio')
          if (!nativeRecovered) {
            this.markTtsPlaybackFailed('上一句触发失败，请点击播放重试', false)
            return
          }
        }
      }
      this.scheduleNextTts()
    }
  }

  private async nextTtsUnit() {
    if (this.ttsUnits.length === 0) {
      return
    }
    this.ttsCurrentIndex = Math.min(this.ttsCurrentIndex + 1, this.ttsUnits.length - 1)
    this.ttsPlayGeneration = this.ttsPlayGeneration + 1
    if (this.ttsPlaying) {
      await this.speakAndHighlightCurrentUnit()
      if (this.ttsOutputMode === 'audio') {
        const ok = await this.triggerAudioPlayback('next-audio')
        if (!ok) {
          const nativeRecovered = await this.tryNativeFallback('next-audio')
          if (!nativeRecovered) {
            this.markTtsPlaybackFailed('下一句触发失败，请点击播放重试', false)
            return
          }
        }
      }
      this.scheduleNextTts()
    }
  }

  private currentTtsProgress(): string {
    if (this.ttsUnits.length === 0) {
      return '0/0'
    }
    return `${this.ttsCurrentIndex + 1}/${this.ttsUnits.length}`
  }

  private currentReaderHighlightIndex(): number {
    if (!this.ttsPanelVisible || this.ttsUnits.length === 0 || this.ttsSource !== 'reader') {
      return -1
    }
    if (this.ttsCurrentIndex < 0 || this.ttsCurrentIndex >= this.ttsUnitParagraphIndex.length) {
      return -1
    }
    return this.ttsUnitParagraphIndex[this.ttsCurrentIndex]
  }

  @Builder TtsControlBar() {
    if (this.ttsPanelVisible) {
      Column({ space: 6 }) {
        Row() {
          Text(`朗读中 ${this.currentTtsProgress()} x${this.ttsPlaySpeed.toFixed(1)} ${this.ttsOutputMode === 'native' ? '(原生播放器)' : (this.ttsOutputMode === 'audio' ? '(云端音频)' : '(本机语音)')}`)
            .fontSize(12)
            .fontColor('#45A5FF')
            .layoutWeight(1)
        }
        .width('100%')

        Text(this.ttsErrorReason.length > 0 ? this.ttsErrorReason : '状态：准备就绪')
          .fontSize(11)
          .fontColor(this.ttsErrorReason.length > 0 ? '#E67E22' : Color.Gray)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .height(36)

        Row({ space: 8 }) {
          Button('上一句')
            .type(ButtonType.Capsule)
            .height(32)
            .fontSize(11)
            .onClick(async () => {
              await this.prevTtsUnit()
            })

          Button(this.ttsPlaying ? '暂停' : '播放')
            .type(ButtonType.Capsule)
            .height(32)
            .fontSize(11)
            .onClick(async () => {
              if (this.ttsPlaying) {
                await this.pauseTts()
              } else {
                await this.resumeTts()
              }
            })

          Button('下一句')
            .type(ButtonType.Capsule)
            .height(32)
            .fontSize(11)
            .onClick(async () => {
              await this.nextTtsUnit()
            })

          Button('停止')
            .type(ButtonType.Capsule)
            .height(32)
            .fontSize(11)
            .onClick(async () => {
              await this.stopTts(true)
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
      }
      .width('94%')
      .padding({ left: 10, right: 10, top: 8, bottom: 10 })
      .backgroundColor(!this.darkMode ? '#F7FBFF' : '#2B2B2B')
      .borderRadius(10)
      .margin({ top: 3, bottom: 8 })
    }
  }

  private increaseFontScale() {
    this.readerFontScale = Math.min(Number((this.readerFontScale + 0.1).toFixed(1)), 1.6)
  }

  private decreaseFontScale() {
    this.readerFontScale = Math.max(Number((this.readerFontScale - 0.1).toFixed(1)), 0.8)
  }

  private increaseLineHeight() {
    this.readerLineHeight = Math.min(Number((this.readerLineHeight + 0.1).toFixed(1)), 2.4)
  }

  private decreaseLineHeight() {
    this.readerLineHeight = Math.max(Number((this.readerLineHeight - 0.1).toFixed(1)), 1.2)
  }

  @Builder ReaderContentPanel() {
    Column() {
      Row({ space: 8 }) {
        Text(this.readerTitle.length > 0 ? this.readerTitle : '阅读器模式')
          .fontSize(24 * this.readerFontScale)
          .fontWeight(FontWeight.Medium)
          .fontColor(!this.darkMode ? Color.Black : Color.White)
          .layoutWeight(1)

        Button('-字')
          .type(ButtonType.Capsule)
          .height(30)
          .fontSize(12)
          .onClick(() => {
            this.decreaseFontScale()
          })

        Button('+字')
          .type(ButtonType.Capsule)
          .height(30)
          .fontSize(12)
          .onClick(() => {
            this.increaseFontScale()
          })

        Button('-行距')
          .type(ButtonType.Capsule)
          .height(28)
          .fontSize(11)
          .onClick(() => {
            this.decreaseLineHeight()
          })

        Button('+行距')
          .type(ButtonType.Capsule)
          .height(28)
          .fontSize(11)
          .onClick(() => {
            this.increaseLineHeight()
          })

        Text(`行高 ${this.readerLineHeight.toFixed(1)}`)
          .fontSize(12)
          .fontColor(Color.Gray)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 18, left: 14, right: 14, bottom: 12 })

      Scroll() {
        Column({ space: 14 }) {
          ForEach(this.readerParagraphs, (paragraph: string, index: number) => {
            Text(paragraph)
              .width('100%')
              .textAlign(TextAlign.Start)
              .fontSize(17 * this.readerFontScale)
              .lineHeight(this.readerLineHeight * 30)
              .fontColor(this.currentReaderHighlightIndex() === index ? '#0D47A1' : (!this.darkMode ? '#1C1C1C' : '#ECECEC'))
              .backgroundColor(this.currentReaderHighlightIndex() === index ? '#E8F2FF' : '#00000000')
              .borderRadius(8)
              .padding({ left: 6, right: 6, top: 4, bottom: 4 })
          })
        }
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 20 })
      }
      .scrollable(ScrollDirection.Vertical)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(!this.darkMode ? '#FDFDFD' : '#121212')
  }

  build() {
    Flex({ direction: FlexDirection.Column , alignItems: ItemAlign.Center}) {
      Column() {
        if (this.ttsPanelVisible) {
          Stack({ alignContent: Alignment.Bottom }) {
            Search({ placeholder: "搜索或输入网址", value: this.url, controller: this.textInputController})
              .width("90%")
              .height("8%")
              .size({ height: 50 })
              .margin({ top: 6, bottom: 8, left: 5, right: 5})
              .textAlign(this.textAlign)
              .backgroundColor(!this.darkMode? "#E8E8E8" : "#696969")
              .zIndex(3)
              .onClick(() => {
                this.inputMethodController.showSoftKeyboard()
                if (this.isSearched) {
                  this.textInputController.setTextSelection(0, this.url.length)
                }
              })
              .onEditChange((isEditing: boolean) => {
                this.isShowMask = isEditing;
              })
              .onSubmit((value) => {
                try {
                  if (this.checkContent(value)) {
                    this.webviewController.loadUrl(value)
                  } else {
                    this.webviewController.loadUrl(CommonConstants.SEARCH_ENGINES[this.searchEngine].prefix + value)
                  }

                  this.url = this.webviewController.getOriginalUrl()
                  if (!this.isSearched) {
                    this.isSearched = true
                  }

                  this.isReaderMode = false
                  this.readerAvailable = false
                  this.readerError = ''
                  this.readerParagraphs = []
                  this.readerTitle = ''
                  this.readerConfidence = 0
                  this.readerLoading = true
                  this.readerUnsupportedReason = ''
                  this.inputMethodController.stopInputSession()
                } catch (error) {
                  console.log("提交搜索时异常：" + error)
                }
              })
            Progress({ value: this.currentProgress, type: ProgressType.Linear })
              .visibility(this.currentProgress === 100 || this.currentProgress === 0 ? Visibility.None : Visibility.Visible)
              .animation({
                duration: 100
              })
          }
          .margin({ top: 2 })
        }

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
          Stack({ alignContent: Alignment.TopStart }) {
            // 网页内容始终保活，避免切换阅读器时丢失历史栈与上下文。
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
                  this.isReaderMode = false
                  await this.detectReaderContent()
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

            if (this.isReaderMode) {
              this.ReaderContentPanel()
            }
          }
          .width("100%")
          .height("100%")
        }
        .width("100%")
        .height(this.high)
        .justifyContent(FlexAlign.Center)
        .animation({
          duration: 300
        })

        if (!this.ttsPanelVisible) {
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

                this.isReaderMode = false
                this.readerAvailable = false
                this.readerError = ''
                this.readerParagraphs = []
                this.readerTitle = ''
                this.readerConfidence = 0
                this.readerLoading = true
                this.readerUnsupportedReason = ''

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

      }
      .width("100%")
      .layoutWeight(11)
      .justifyContent(FlexAlign.Center)

      if (this.ttsPanelVisible) {
        this.TtsControlBar()
      }

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