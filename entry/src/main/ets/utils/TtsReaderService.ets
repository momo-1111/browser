// entry/src/main/ets/utils/TtsReaderService.ets

import webview from '@ohos.web.webview';
import media from '@ohos.multimedia.media';
import http from '@ohos.net.http';
import fs from '@ohos.file.fs';
import { Prompt } from '@kit.ArkUI';
import ReaderExtractionService from './ReaderExtractionService';
import ArticleContent from '../common/bean/ArticleContent';

class CachePathContext {
  cacheDir: string = '';
}

export class TtsReaderService {
  private webviewController: webview.WebviewController;
  private onStateChange: () => void;

  // TTS 内部状态
  private ttsUnits: string[] = [];
  private ttsUnitParagraphIndex: number[] = [];
  private ttsCurrentIndex: number = 0;
  private ttsLoadedUnitIndex: number = -1;
  private ttsPlaying: boolean = false;
  private ttsPanelVisible: boolean = false;
  private ttsPlaySpeed: number = 1.0;
  private ttsErrorReason: string = '';
  private ttsDebugInfo: string = '';
  private ttsActionLog: string = '';
  private ttsSource: string = 'page';
  private ttsOutputMode: string = 'speech';
  private ttsVoiceBlocked: boolean = false;
  private ttsAudioBlocked: boolean = false;
  private ttsManualRetrying: boolean = false;
  private ttsCommandLocked: boolean = false;
  private ttsNativeReady: boolean = false;
  private ttsNativeFallbackDisabled: boolean = false;

  private ttsTimer: number = -1;
  private nativeAudioPlayer: media.AVPlayer | null = null;
  private nativeTempAudioPath: string = '';
  private nativeAudioFd: number = -1;
  private ttsPlayGeneration: number = 0;

  // 脚本常量
  private readonly readerHtmlScript: string = `(function() { try { return document.body ? document.body.outerHTML : ''; } catch (e) { return ''; } })();`;
  private readonly readerTitleScript: string = `(function() { try { return document.title ? document.title : ''; } catch (e) { return ''; } })();`;
  private readonly readerTextScript: string = `(function() { try { return document.body ? document.body.innerText : ''; } catch (e) { return ''; } })();`;
  private readonly cancelSpeechScript: string = `(function() { try { if ('speechSynthesis' in window) { window.speechSynthesis.cancel(); } window.__readerAudioActivePlay = 0; window.__readerUnlocking = 0; window.__readerSentenceEnded = 0; if (window.__readerAudio) { try { window.__readerAudio.pause(); window.__readerAudio.currentTime = 0; } catch (e) {} window.__readerAudio = null; } if (window.__readerMark && window.__readerMark.parentNode) { const parent = window.__readerMark.parentNode; const text = document.createTextNode(window.__readerMark.textContent || ''); parent.replaceChild(text, window.__readerMark); window.__readerMark = null; } return 'ok'; } catch (e) { return 'error'; } })();`;
  private readonly pauseSpeechScript: string = `(function() { try { if ('speechSynthesis' in window) { window.speechSynthesis.pause(); } window.__readerAudioActivePlay = 0; if (window.__readerAudio) { try { window.__readerAudio.pause(); } catch (e) {} } return 'ok'; } catch (e) { return 'error'; } })();`;

  constructor(controller: webview.WebviewController, onStateChange: () => void) {
    this.webviewController = controller;
    this.onStateChange = onStateChange;
  }

  // 通知 UI 刷新
  private notifyChange() {
    this.onStateChange();
  }

  private async sleep(ms: number): Promise<void> {
    await new Promise<void>((resolve) => setTimeout(resolve, ms));
  }

  // 临时无阈值模式：只要能提取出可展示正文，就允许进入阅读器。
  private hasRenderableReaderContent(content: ArticleContent): boolean {
    return content.paragraphCount > 0 && content.totalLength > 0;
  }

  private fallbackParagraphsFromVisibleText(text: string): string[] {
    if (!text || text.length < 30) return [];
    const blocks = text
      .split(/\n{2,}|[。！？；]\s*/)
      .map(item => item.trim())
      .filter(item => item.length >= 18)
      .slice(0, 80);
    return blocks;
  }

  // 工具：脚本结果解码
  private decodeScriptResult(raw: string): string {
    if (!raw) return '';
    let decoded = raw;

    // runJavaScript 常返回 JSON 字符串字面量，优先按 JSON 反序列化更稳健。
    try {
      const parsed = JSON.parse(raw) as Object;
      if (typeof parsed === 'string') {
        decoded = parsed;
      }
    } catch (error) {
      if (decoded.length >= 2 && decoded.startsWith('"') && decoded.endsWith('"')) {
        decoded = decoded.substring(1, decoded.length - 1);
      }
    }

    return decoded
      .replace(/\\u003C/gi, '<')
      .replace(/\\u003E/gi, '>')
      .replace(/\\u0026/gi, '&')
      .replace(/\\u0022/gi, '"')
      .replace(/\\u0027/gi, "'")
      .replace(/\\n/g, '\n')
      .replace(/\\r/g, '\r')
      .replace(/\\t/g, '\t');
  }

  private async runScript(script: string): Promise<string> {
    try {
      // Prefer Promise-style API to avoid callback signature drift across SDK versions.
      const result = await this.webviewController.runJavaScript(script);
      return result ?? '';
    } catch (error) {
      return '';
    }
  }

  // 检测阅读器内容
  async detectReaderContent(): Promise<ArticleContent> {
    try {
      const url = this.webviewController.getUrl();
      let best = new ArticleContent('', [], 0, false, '阅读器未命中');
      let bestDiag = '';
      const diagLogs: string[] = [];

      this.ttsDebugInfo = `reader-detect|start|url=${url}`;

      // 动态站点常在 onPageEnd 后继续注入正文，做短延迟重试可显著提升命中率。
      for (let attempt = 1; attempt <= 3; attempt++) {
        const attemptLogs: string[] = [`attempt=${attempt}`, `url=${url}`];
        const rawHtml = await this.runScript(this.readerHtmlScript);
        const html = this.decodeScriptResult(rawHtml);
        attemptLogs.push(`htmlLen=${html.length}`);
        const rawText = await this.runScript(this.readerTextScript);
        const visibleText = this.decodeScriptResult(rawText);
        attemptLogs.push(`textLen=${visibleText.length}`);
        const rawTitle = await this.runScript(this.readerTitleScript);
        const pageTitle = this.decodeScriptResult(rawTitle);
        const fallbackTitle = pageTitle.length > 0 ? pageTitle : this.webviewController.getTitle();
        attemptLogs.push(`titleLen=${fallbackTitle.length}`);

        let extracted = ReaderExtractionService.extractFromHtml(html, url, fallbackTitle);
        let source = 'html';
        attemptLogs.push(`htmlAvailable=${extracted.available}`);
        attemptLogs.push(`htmlP=${extracted.paragraphCount}`);
        attemptLogs.push(`htmlTotal=${extracted.totalLength}`);
        attemptLogs.push(`htmlConf=${extracted.confidence.toFixed(2)}`);
        if (!extracted.available && visibleText.length > 0) {
          const fallbackExtracted = ReaderExtractionService.extractFromRenderedText(visibleText, url, fallbackTitle);
          attemptLogs.push(`textAvailable=${fallbackExtracted.available}`);
          attemptLogs.push(`textP=${fallbackExtracted.paragraphCount}`);
          attemptLogs.push(`textTotal=${fallbackExtracted.totalLength}`);
          attemptLogs.push(`textConf=${fallbackExtracted.confidence.toFixed(2)}`);
          if (fallbackExtracted.available || fallbackExtracted.paragraphCount > extracted.paragraphCount) {
            extracted = fallbackExtracted;
            source = 'text';
          }
        }

        if (extracted.paragraphCount === 0 && visibleText.length >= 40) {
          const fallbackParagraphs = this.fallbackParagraphsFromVisibleText(visibleText);
          attemptLogs.push(`fallbackParagraphs=${fallbackParagraphs.length}`);
          if (fallbackParagraphs.length > 0) {
            extracted.paragraphs = fallbackParagraphs;
            extracted.paragraphCount = fallbackParagraphs.length;
            extracted.totalLength = fallbackParagraphs.reduce((sum, item) => sum + item.length, 0);
            if (extracted.title.length === 0) {
              extracted.title = fallbackTitle;
            }
            source = 'visible-text';
          }
        }

        if (!extracted.available && (!html || html.length < 50) && visibleText.length < 30) {
          extracted.unsupportedReason = '页面正文仍在异步加载，建议稍后重试或下滑页面后再开启阅读器';
        }

        attemptLogs.push(`finalSource=${source}`);
        attemptLogs.push(`finalAvailable=${extracted.available}`);
        attemptLogs.push(`finalP=${extracted.paragraphCount}`);
        attemptLogs.push(`finalTotal=${extracted.totalLength}`);
        attemptLogs.push(`finalConf=${extracted.confidence.toFixed(2)}`);

        const diag = attemptLogs.join('|');
        diagLogs.push(diag);

        if (this.hasRenderableReaderContent(extracted)) {
          this.ttsDebugInfo = `reader-detect|ok|${diag}`;
          const result = new ArticleContent(extracted.title, extracted.paragraphs, extracted.confidence, true,
            `阅读器日志：${diag}`);
          return result;
        }

        if (extracted.paragraphCount > best.paragraphCount || (extracted.paragraphCount === best.paragraphCount && extracted.confidence > best.confidence)) {
          best = extracted;
          bestDiag = diag;
        }

        if (attempt < 3) {
          await this.sleep(attempt * 260);
        }
      }

      const reason = best.unsupportedReason && best.unsupportedReason.length > 0 ? best.unsupportedReason : '页面未提取到可展示正文';
      const briefLog = diagLogs.length > 0 ? diagLogs.join(' || ') : bestDiag;
      const withDiag = `${reason}；阅读器日志：${briefLog}`;
      this.ttsDebugInfo = `reader-detect|failed|${briefLog}`;
      return new ArticleContent(best.title, best.paragraphs, best.confidence, false, withDiag);
    } catch (error) {
      this.ttsDebugInfo = `reader-detect|error|${String(error)}`;
      return new ArticleContent('', [], 0, false, `阅读器解析异常：${String(error)}`);
    }
  }

  // ------------------- TTS 核心方法 -------------------
  private cleanTtsText(input: string): string {
    return input.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
  }

  private splitToTtsUnits(text: string): string[] {
    const units: string[] = [];
    const blocks = text.split(/[。！？；!?;]|\n{2,}/).map(item => item.trim()).filter(item => item.length > 0);
    for (const block of blocks) {
      if (block.length <= 80) {
        units.push(block);
      } else {
        const sub = block.split(/[，,]/).map(item => item.trim()).filter(item => item.length >= 6);
        if (sub.length > 0) {
          for (const item of sub) { units.push(item); }
        } else {
          units.push(block);
        }
      }
    }
    return units;
  }

  private shouldSkipTtsUnit(text: string): boolean {
    if (text.length < 6) return true;
    if (/(首页|上一页|下一页|返回顶部|目录|导航|菜单|登录|注册|免责声明|版权|隐私政策|cookie|APP下载|打开APP|分享|编辑|收藏|阅读原文)/.test(text)) return true;
    if (/(function\s*\(|=>|\{\s*\}|<\/?[a-z]|console\.|var\s+|let\s+|const\s+|http[s]?:\/\/)/i.test(text)) return true;
    const symbolChars = text.replace(/[\u4e00-\u9fa5a-zA-Z0-9]/g, '');
    return symbolChars.length / text.length > 0.45;
  }

  private dedupeTtsUnits(units: string[]): string[] {
    const out: string[] = [];
    const seen = new Set<string>();
    for (const item of units) {
      const key = item.replace(/\s+/g, ' ').trim();
      if (key.length === 0 || seen.has(key)) continue;
      seen.add(key);
      out.push(key);
    }
    return out;
  }

  private buildTtsUnitsFromReader(paragraphs: string[]) {
    let filtered = 0;
    for (let i = 0; i < paragraphs.length; i++) {
      const paragraph = this.cleanTtsText(paragraphs[i]);
      if (paragraph.length === 0) continue;
      const units = this.splitToTtsUnits(paragraph);
      for (const unit of units) {
        if (this.shouldSkipTtsUnit(unit)) {
          filtered++;
          continue;
        }
        this.ttsUnits.push(unit);
        this.ttsUnitParagraphIndex.push(i);
      }
    }
    if (this.ttsUnits.length === 0) {
      this.ttsErrorReason = `阅读器文本过滤后为空（过滤 ${filtered} 条）`;
    }
  }

  private async buildTtsUnitsFromPageText() {
    const rawText = await this.runScript(this.readerTextScript);
    const plain = this.decodeScriptResult(rawText);
    if (plain.length < 20) {
      this.ttsErrorReason = `页面可见文本过少(${plain.length})，可能尚未加载完成`;
      return;
    }
    let filtered = 0;
    const blocks = plain.split(/\n{2,}/).map(item => item.trim()).filter(item => item.length >= 8);
    for (const block of blocks) {
      const cleaned = this.cleanTtsText(block);
      if (cleaned.length === 0) continue;
      const units = this.splitToTtsUnits(cleaned);
      for (const unit of units) {
        if (this.shouldSkipTtsUnit(unit)) {
          filtered++;
          continue;
        }
        this.ttsUnits.push(unit);
        this.ttsUnitParagraphIndex.push(-1);
      }
    }
    this.ttsUnits = this.dedupeTtsUnits(this.ttsUnits).slice(0, 300);
    if (this.ttsUnits.length === 0) {
      this.ttsErrorReason = `页面文本过滤后为空（原始长度 ${plain.length}，过滤 ${filtered} 条）`;
    }
  }

  private buildCloudAudioUrlsForNative(text: string): string[] {
    const encoded = encodeURIComponent(text);
    return [
      `https://fanyi.baidu.com/gettts?lan=zh&spd=5&source=web&text=${encoded}`,
      `http://fanyi.baidu.com/gettts?lan=zh&spd=5&source=web&text=${encoded}`,
      `https://tts.baidu.com/text2audio?lan=zh&ie=UTF-8&spd=5&text=${encoded}`,
      `http://tts.baidu.com/text2audio?lan=zh&ie=UTF-8&spd=5&text=${encoded}`,
      `https://dict.youdao.com/dictvoice?type=1&audio=${encoded}`,
      `https://translate.googleapis.com/translate_tts?ie=UTF-8&client=gtx&tl=zh-CN&q=${encoded}`
    ];
  }

  private async releaseNativeAudioPlayer() {
    if (this.nativeAudioPlayer) {
      try { await this.nativeAudioPlayer.release(); } catch (e) {}
      this.nativeAudioPlayer = null;
    }
    if (this.nativeAudioFd >= 0) {
      try { fs.closeSync(this.nativeAudioFd); } catch (e) {}
      this.nativeAudioFd = -1;
    }
    this.ttsNativeReady = false;
  }

  private async stopNativeAudioInternal() {
    if (!this.nativeAudioPlayer) return;
    try { await this.nativeAudioPlayer.stop(); } catch (e) {}
    await this.releaseNativeAudioPlayer();
  }

  private async waitNativePlayerReady(player: media.AVPlayer, tag: string): Promise<void> {
    for (let i = 0; i < 20; i++) {
      const state = `${player.state}`;
      if (state === 'initialized' || state === 'stopped' || state === 'prepared' || state === 'completed') {
        this.ttsDebugInfo = `${this.ttsDebugInfo}; native-state-${tag}=${state}`;
        return;
      }
      await new Promise<void>((resolve) => setTimeout(resolve, 60));
    }
    this.ttsDebugInfo = `${this.ttsDebugInfo}; native-state-${tag}=timeout:${player.state}`;
  }

  private clearNativeTempAudio() {
    if (this.nativeTempAudioPath.length === 0) return;
    try { fs.unlinkSync(this.nativeTempAudioPath); } catch (e) {}
    this.nativeTempAudioPath = '';
  }

  private async downloadAudioToCache(url: string, context: Context): Promise<string> {
    const request = http.createHttp();
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 10000,
        readTimeout: 10000,
        header: { 'User-Agent': 'Mozilla/5.0 (Linux; HarmonyOS) AppleWebKit/537.36', 'Referer': 'https://fanyi.baidu.com/' }
      });
      const payload = response.result as ArrayBuffer;
      if (response.responseCode !== 200 || !payload || payload.byteLength <= 0) return '';
      const localPath = `${context.cacheDir}/tts_${Date.now()}.mp3`;
      const file = fs.openSync(localPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, payload);
      fs.closeSync(file);
      this.nativeTempAudioPath = localPath;
      return localPath;
    } catch (error) {
      return '';
    } finally {
      request.destroy();
    }
  }

  private async playCurrentUnitWithNativeAudio(text: string, context: Context): Promise<boolean> {
    const urls = this.buildCloudAudioUrlsForNative(text);
    await this.stopNativeAudioInternal();
    this.clearNativeTempAudio();
    for (let i = 0; i < urls.length; i++) {
      try {
        const player = await media.createAVPlayer();
        this.nativeAudioPlayer = player;
        player.url = urls[i];
        await this.waitNativePlayerReady(player, `${i + 1}-direct`);
        await player.prepare();
        await player.play();
        this.ttsNativeReady = true;
        return true;
      } catch (error) {
        await this.releaseNativeAudioPlayer();
        const localPath = await this.downloadAudioToCache(urls[i], context);
        if (localPath.length > 0) {
          try {
            const localPlayer = await media.createAVPlayer();
            this.nativeAudioPlayer = localPlayer;
            const file = fs.openSync(localPath, fs.OpenMode.READ_ONLY);
            this.nativeAudioFd = file.fd;
            const stat = fs.statSync(localPath);
            localPlayer.fdSrc = { fd: this.nativeAudioFd, offset: 0, length: stat.size };
            await this.waitNativePlayerReady(localPlayer, `${i + 1}-cache`);
            await localPlayer.prepare();
            await localPlayer.play();
            this.ttsNativeReady = true;
            return true;
          } catch (localError) {
            await this.releaseNativeAudioPlayer();
            this.clearNativeTempAudio();
          }
        }
      }
    }
    this.ttsNativeReady = false;
    return false;
  }

  private buildHighlightOnlyScript(text: string): string {
    const escaped = text.replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\n/g, ' ');
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
    })();`;
  }

  private buildSpeakScript(text: string, speed: number): string {
    const escaped = text.replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\n/g, ' ');
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
            try { window.__readerAudio.pause(); window.__readerAudio.currentTime = 0; } catch (e) {}
            window.__readerAudio = null;
          }
          synth.cancel();
          const utter = new SpeechSynthesisUtterance(target);
          utter.rate = rate;
          utter.volume = 1;
          utter.pitch = 1;
          if (voiceCount > 0) {
            const zhVoice = voices.find(v => (v.lang || '').toLowerCase().startsWith('zh'));
            if (zhVoice) { utter.voice = zhVoice; utter.lang = zhVoice.lang || 'zh-CN'; }
            else { utter.voice = voices[0]; utter.lang = voices[0].lang || ''; }
          } else { utter.lang = ''; }
          utter.onstart = function() { window.__readerSpeechState = 'start'; };
          utter.onend = function() { window.__readerSpeechState = 'end'; };
          utter.onerror = function(e) { window.__readerSpeechState = 'error:' + (e && e.error ? e.error : 'unknown'); };
          window.__readerSpeechState = 'pending';
          if (synth.resume) synth.resume();
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
            if (window.__readerUnlocking === 1) { window.__readerSpeechState = 'audio_unlock_play'; return; }
            window.__readerSpeechState = 'audio_play';
          };
          audio.onended = function() {
            if (window.__readerUnlocking === 1 || window.__readerAudioActivePlay !== 1) { window.__readerSpeechState = 'audio_unlock_end'; return; }
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
    })();`;
  }

  private speechProbeScript(): string {
    return `(function() {
      try {
        if (!('speechSynthesis' in window)) return 'probe|no_api';
        const synth = window.speechSynthesis;
        const voices = synth.getVoices ? synth.getVoices() : [];
        const state = window.__readerSpeechState ? String(window.__readerSpeechState) : 'none';
        const hasAudio = window.__readerAudio ? '1' : '0';
        const audioPaused = window.__readerAudio ? (window.__readerAudio.paused ? '1' : '0') : '1';
        const audioTry = (typeof window.__readerAudioTry === 'number') ? String(window.__readerAudioTry) : '0';
        const audioSrc = (window.__readerAudio && window.__readerAudio.src) ? String(window.__readerAudio.src) : '';
        return 'probe|voices=' + (voices ? voices.length : 0) + '|pending=' + (synth.pending ? '1' : '0') + '|speaking=' + (synth.speaking ? '1' : '0') + '|state=' + state + '|audio=' + hasAudio + '|audioPaused=' + audioPaused + '|audioTry=' + audioTry + '|audioSrc=' + audioSrc;
      } catch (e) { return 'probe|error'; }
    })();`;
  }

  private audioUnlockScript(): string {
    return `(function() {
      try {
        if (!window.__readerAudio) return 'unlock|no_audio';
        const audio = window.__readerAudio;
        window.__readerUnlocking = 1;
        window.__readerAudioActivePlay = 0;
        const oldMuted = !!audio.muted;
        const oldVolume = typeof audio.volume === 'number' ? audio.volume : 1;
        audio.muted = true;
        audio.volume = 0;
        const p = audio.play();
        if (p && p.catch) { p.catch(function() { window.__readerSpeechState = 'audio_blocked'; window.__readerUnlocking = 0; }); }
        audio.pause();
        audio.currentTime = 0;
        audio.muted = oldMuted;
        audio.volume = oldVolume;
        window.__readerUnlocking = 0;
        window.__readerSpeechState = 'audio_unlock_ready';
        return 'unlock|triggered|paused=' + (audio.paused ? '1' : '0');
      } catch (e) { window.__readerUnlocking = 0; return 'unlock|error'; }
    })();`;
  }

  private playCurrentAudioScript(): string {
    return `(function() {
      try {
        if (!window.__readerAudio) return 'resume|no_audio';
        const audio = window.__readerAudio;
        window.__readerUnlocking = 0;
        window.__readerAudioActivePlay = 1;
        window.__readerSentenceEnded = 0;
        window.__readerSpeechState = 'audio_play_try';
        const p = audio.play();
        if (p && p.catch) { p.catch(function() { window.__readerAudioActivePlay = 0; window.__readerSpeechState = 'audio_blocked'; }); }
        return 'resume|triggered|paused=' + (audio.paused ? '1' : '0');
      } catch (e) { window.__readerAudioActivePlay = 0; window.__readerSpeechState = 'audio_error'; return 'resume|error'; }
    })();`;
  }

  private consumeAudioEndedScript(): string {
    return `(function() {
      try {
        if (window.__readerSentenceEnded === 1) { window.__readerSentenceEnded = 0; return 'ended'; }
        return window.__readerSpeechState ? String(window.__readerSpeechState) : 'none';
      } catch (e) { return 'error'; }
    })();`;
  }

  private armTapResumeScript(): string {
    return `(function() {
      try {
        if (!window.__readerAudio) return 'tap-resume|no_audio';
        if (window.__readerTapResumeArmed === 1) return 'tap-resume|armed';
        window.__readerTapResumeArmed = 1;
        const run = function() {
          try {
            if (!window.__readerAudio) { window.__readerTapResumeArmed = 0; return; }
            window.__readerUnlocking = 0;
            window.__readerAudioActivePlay = 1;
            window.__readerSentenceEnded = 0;
            window.__readerSpeechState = 'audio_play_try';
            const p = window.__readerAudio.play();
            if (p && p.catch) { p.catch(function() { window.__readerAudioActivePlay = 0; window.__readerSpeechState = 'audio_blocked'; }); }
          } catch (e) { window.__readerAudioActivePlay = 0; window.__readerSpeechState = 'audio_error'; } finally { window.__readerTapResumeArmed = 0; }
        };
        document.addEventListener('pointerdown', run, { once: true, capture: true });
        document.addEventListener('touchstart', run, { once: true, capture: true });
        document.addEventListener('click', run, { once: true, capture: true });
        return 'tap-resume|ok';
      } catch (e) { return 'tap-resume|error'; }
    })();`;
  }

  private async triggerAudioPlayback(triggerFrom: string): Promise<boolean> {
    const unlock = await this.runScript(this.audioUnlockScript());
    const unlockResult = this.decodeScriptResult(unlock);
    const first = await this.runScript(this.playCurrentAudioScript());
    let firstResult = this.decodeScriptResult(first);
    let immediateOk = firstResult.includes('resume|ok') || (firstResult.includes('resume|triggered') && !firstResult.includes('paused=1'));
    if (!immediateOk) {
      const second = await this.runScript(this.playCurrentAudioScript());
      const secondResult = this.decodeScriptResult(second);
      immediateOk = secondResult.includes('resume|ok') || (secondResult.includes('resume|triggered') && !secondResult.includes('paused=1'));
    }
    await new Promise<void>((resolve) => setTimeout(resolve, 220));
    const probe = await this.runScript(this.speechProbeScript());
    const probeText = this.decodeScriptResult(probe);
    const probeOk = probeText.includes('state=audio_play') || probeText.includes('state=audio_end') || probeText.includes('audioPaused=0') || probeText.includes('speaking=1');
    const ok = immediateOk || probeOk;
    if (!ok) {
      await this.runScript(this.armTapResumeScript());
    }
    return ok;
  }

  private async tryNativeFallback(scene: string, context: Context): Promise<boolean> {
    if (this.ttsNativeFallbackDisabled || this.ttsUnits.length === 0 || this.ttsCurrentIndex >= this.ttsUnits.length) return false;
    const ok = await this.playCurrentUnitWithNativeAudio(this.ttsUnits[this.ttsCurrentIndex], context);
    if (ok) {
      await this.runScript(this.pauseSpeechScript);
      this.ttsOutputMode = 'native';
      this.ttsLoadedUnitIndex = this.ttsCurrentIndex;
      this.ttsErrorReason = '';
      this.ttsAudioBlocked = false;
      this.ttsVoiceBlocked = false;
      this.ttsPlaying = true;
      this.scheduleNextTts(context);
      return true;
    }
    this.ttsNativeFallbackDisabled = true;
    return false;
  }

  private clearTtsTimer() {
    if (this.ttsTimer > 0) {
      clearTimeout(this.ttsTimer);
      this.ttsTimer = -1;
    }
  }

  private ttsDurationMs(text: string): number {
    const base = Math.max(1300, Math.min(6500, Math.floor(text.length * 55)));
    return Math.floor(base / Math.max(this.ttsPlaySpeed, 0.5));
  }

  private async speakAndHighlightCurrentUnit(context: Context) {
    if (this.ttsUnits.length === 0 || this.ttsCurrentIndex >= this.ttsUnits.length) return;
    const playGen = this.ttsPlayGeneration;

    if (this.ttsOutputMode === 'native') {
      await this.runScript(this.buildHighlightOnlyScript(this.ttsUnits[this.ttsCurrentIndex]));
      const nativeOk = await this.playCurrentUnitWithNativeAudio(this.ttsUnits[this.ttsCurrentIndex], context);
      if (playGen !== this.ttsPlayGeneration) return;
      if (nativeOk) {
        this.ttsOutputMode = 'native';
        this.ttsLoadedUnitIndex = this.ttsCurrentIndex;
        this.ttsErrorReason = '';
        this.ttsAudioBlocked = false;
        this.ttsVoiceBlocked = false;
        this.ttsPlaying = true;
        return;
      }
      this.ttsErrorReason = '原生主通道失败，已自动回退网页语音链路';
    }

    const script = this.buildSpeakScript(this.ttsUnits[this.ttsCurrentIndex], this.ttsPlaySpeed);
    const result = await this.runScript(script);
    if (playGen !== this.ttsPlayGeneration) return;
    const decoded = this.decodeScriptResult(result);
    this.ttsOutputMode = decoded.includes('mode=audio') ? 'audio' : 'speech';
    this.ttsDebugInfo = decoded;
    this.ttsLoadedUnitIndex = this.ttsCurrentIndex;

    if (decoded.startsWith('no_api|')) {
      this.ttsErrorReason = `当前 Web 内核不支持发声：${decoded.replace('no_api|', '')}`;
      this.ttsPlaying = false;
      Prompt.showToast({ message: this.ttsErrorReason });
      return;
    }
    if (decoded.startsWith('error|')) {
      this.ttsErrorReason = `朗读脚本异常：${decoded.replace('error|', '')}`;
      this.ttsPlaying = false;
      Prompt.showToast({ message: this.ttsErrorReason });
      return;
    }
    if (!decoded.startsWith('ok|')) {
      this.ttsErrorReason = `朗读状态未知：${decoded}`;
      this.ttsPlaying = false;
      Prompt.showToast({ message: this.ttsErrorReason });
      return;
    }

    setTimeout(async () => {
      if (playGen !== this.ttsPlayGeneration) return;
      const probe = await this.runScript(this.speechProbeScript());
      if (playGen !== this.ttsPlayGeneration) return;
      const probeText = this.decodeScriptResult(probe);
      if (probeText.includes('voices=0') && !decoded.includes('mode=audio')) {
        this.ttsErrorReason = '发声引擎未加载语音包（voices=0），请手动点“重试语音”';
        this.ttsVoiceBlocked = true;
        this.ttsPlaying = false;
        this.clearTtsTimer();
      } else if (decoded.includes('mode=audio')) {
        if (probeText.includes('state=audio_error')) {
          this.ttsErrorReason = `云端音频加载失败，可能被防盗链/策略拒绝`;
          this.ttsPlaying = false;
          this.clearTtsTimer();
        } else if (probeText.includes('state=audio_blocked')) {
          this.ttsErrorReason = '云端音频被自动播放策略拦截，请点击“播放/解锁音频”';
          this.ttsAudioBlocked = true;
          this.ttsPlaying = false;
          this.clearTtsTimer();
        } else if (probeText.includes('state=audio_loaded') || probeText.includes('state=audio_canplay')) {
          this.ttsErrorReason = '音频资源已加载，请点击“播放”触发声音';
          this.ttsAudioBlocked = true;
        } else {
          this.ttsErrorReason = '';
          this.ttsVoiceBlocked = false;
          this.ttsAudioBlocked = false;
        }
      } else if (probeText.includes('state=error:')) {
        this.ttsErrorReason = `发声回调报错：${probeText}`;
      } else if (probeText.includes('pending=0') && probeText.includes('speaking=0') && probeText.includes('state=pending')) {
        this.ttsErrorReason = '发声可能被策略拦截，请手动点击播放重试';
      } else if (probeText.includes('state=start') || probeText.includes('speaking=1')) {
        this.ttsErrorReason = '';
        this.ttsVoiceBlocked = false;
      }
    }, 500);
  }

  private scheduleNextTts(context: Context) {
    this.clearTtsTimer();
    if (!this.ttsPlaying || this.ttsUnits.length === 0) return;

    if (this.ttsOutputMode === 'native') {
      const playGenNative = this.ttsPlayGeneration;
      this.ttsTimer = setTimeout(async () => {
        if (playGenNative !== this.ttsPlayGeneration || !this.ttsPlaying) return;
        if (!this.nativeAudioPlayer) { this.ttsErrorReason = '原生播放器实例丢失，请重试'; this.ttsPlaying = false; return; }
        const nativeState = `${this.nativeAudioPlayer.state}`;
        if (nativeState === 'completed') {
          if (this.ttsCurrentIndex >= this.ttsUnits.length - 1) { this.ttsPlaying = false; Prompt.showToast({ message: '朗读完成' }); return; }
          this.ttsCurrentIndex++;
          await this.speakAndHighlightCurrentUnit(context);
        } else if (nativeState === 'error') {
          this.ttsErrorReason = '原生播放器状态异常，请重试';
          this.ttsPlaying = false;
          return;
        }
        this.scheduleNextTts(context);
      }, 260);
      return;
    }

    if (this.ttsOutputMode === 'audio') {
      const playGenAudio = this.ttsPlayGeneration;
      this.ttsTimer = setTimeout(async () => {
        if (playGenAudio !== this.ttsPlayGeneration || !this.ttsPlaying) return;
        const stateRaw = await this.runScript(this.consumeAudioEndedScript());
        const state = this.decodeScriptResult(stateRaw);
        if (state === 'ended') {
          if (this.ttsCurrentIndex >= this.ttsUnits.length - 1) { this.ttsPlaying = false; Prompt.showToast({ message: '朗读完成' }); return; }
          this.ttsCurrentIndex++;
          await this.speakAndHighlightCurrentUnit(context);
          const ok = await this.triggerAudioPlayback('auto-next');
          if (!ok) {
            const nativeRecovered = await this.tryNativeFallback('auto-next', context);
            if (!nativeRecovered) { this.ttsErrorReason = '下一句触发失败，网页音频被策略拦截'; this.ttsPlaying = false; }
            return;
          }
        } else if (state === 'audio_blocked' || state === 'error') {
          const nativeRecovered = await this.tryNativeFallback('audio-state', context);
          if (!nativeRecovered) { this.ttsErrorReason = '音频播放被拦截或异常，请点击播放继续'; this.ttsPlaying = false; }
          return;
        }
        this.scheduleNextTts(context);
      }, 280);
      return;
    }

    const text = this.ttsUnits[this.ttsCurrentIndex];
    const delay = this.ttsDurationMs(text);
    const playGen = this.ttsPlayGeneration;
    this.ttsTimer = setTimeout(async () => {
      if (playGen !== this.ttsPlayGeneration || !this.ttsPlaying) return;
      if (this.ttsCurrentIndex >= this.ttsUnits.length - 1) { this.ttsPlaying = false; Prompt.showToast({ message: '朗读完成' }); return; }
      this.ttsCurrentIndex++;
      await this.speakAndHighlightCurrentUnit(context);
      this.scheduleNextTts(context);
    }, delay);
  }

  // ---------- 公开 API ----------
  async startTts(paragraphs: string[], isReaderMode: boolean, context: Context) {
    await this.stopTts(false);
    this.ttsPlayGeneration++;
    this.ttsErrorReason = '';
    this.ttsOutputMode = 'native';
    this.ttsVoiceBlocked = false;
    this.ttsAudioBlocked = false;
    this.ttsNativeFallbackDisabled = false;
    this.ttsUnits = [];
    this.ttsUnitParagraphIndex = [];
    this.ttsCurrentIndex = 0;
    this.ttsLoadedUnitIndex = -1;

    if (isReaderMode && paragraphs.length > 0) {
      this.ttsSource = 'reader';
      this.buildTtsUnitsFromReader(paragraphs);
    } else {
      this.ttsSource = 'page';
      await this.buildTtsUnitsFromPageText();
    }

    if (this.ttsUnits.length === 0) {
      const reason = this.ttsErrorReason || '未提取到可朗读文本';
      Prompt.showToast({ message: `朗读失败：${reason}` });
      return;
    }

    this.ttsPanelVisible = true;
    this.ttsPlaying = false;
    await this.warmupSpeechEngine();
    Prompt.showToast({ message: `已准备 ${this.ttsUnits.length} 句，点击播放开始朗读` });
    this.notifyChange();
  }

  private async warmupSpeechEngine() {
    const script = `(function() { try { if (!('speechSynthesis' in window)) return 'warmup|no_api'; const synth = window.speechSynthesis; if (synth.resume) synth.resume(); const voices = synth.getVoices ? synth.getVoices() : []; return 'warmup|voices=' + (voices ? voices.length : 0); } catch (e) { return 'warmup|error'; } })();`;
    await this.runScript(script);
  }

  async pauseTts() {
    if (this.ttsCommandLocked) return;
    this.ttsCommandLocked = true;
    this.ttsPlayGeneration++;
    this.ttsPlaying = false;
    this.clearTtsTimer();
    if (this.nativeAudioPlayer) {
      try { await this.nativeAudioPlayer.pause(); } catch (e) {}
    }
    await this.runScript(this.pauseSpeechScript);
    this.ttsCommandLocked = false;
    this.notifyChange();
  }

  async resumeTts(context: Context) {
    if (this.ttsCommandLocked || this.ttsPlaying) return;
    this.ttsCommandLocked = true;
    this.ttsPlayGeneration++;
    if (this.ttsUnits.length === 0) { this.ttsCommandLocked = false; return; }
    this.ttsPlaying = true;
    await this.speakAndHighlightCurrentUnit(context);
    if (!this.ttsPlaying) { this.ttsCommandLocked = false; return; }
    if (this.ttsOutputMode === 'audio') {
      const ok = await this.triggerAudioPlayback('resume-audio');
      if (!ok) {
        const nativeRecovered = await this.tryNativeFallback('resume-audio', context);
        if (!nativeRecovered) {
          this.ttsErrorReason = '当前页面未能触发音频，且原生兜底失败：请点击网页任意位置一次，将自动继续播放';
          this.ttsCommandLocked = false;
          this.notifyChange();
          return;
        }
      }
    }
    this.scheduleNextTts(context);
    this.ttsCommandLocked = false;
    this.notifyChange();
  }

  async stopTts(hidePanel: boolean = true) {
    this.ttsCommandLocked = false;
    this.ttsPlayGeneration++;
    this.ttsPlaying = false;
    this.clearTtsTimer();
    this.ttsCurrentIndex = 0;
    this.ttsLoadedUnitIndex = -1;
    this.ttsVoiceBlocked = false;
    this.ttsAudioBlocked = false;
    this.ttsNativeFallbackDisabled = true;
    await this.stopNativeAudioInternal();
    this.clearNativeTempAudio();
    await this.runScript(this.cancelSpeechScript);
    if (hidePanel) this.ttsPanelVisible = false;
    this.notifyChange();
  }

  async nextTtsUnit(context: Context) {
    if (this.ttsUnits.length === 0) return;
    this.ttsCurrentIndex = Math.min(this.ttsCurrentIndex + 1, this.ttsUnits.length - 1);
    this.ttsPlayGeneration++;
    if (this.ttsPlaying) {
      await this.speakAndHighlightCurrentUnit(context);
      if (this.ttsOutputMode === 'audio') {
        const ok = await this.triggerAudioPlayback('next-audio');
        if (!ok) await this.tryNativeFallback('next-audio', context);
      }
      this.scheduleNextTts(context);
    }
    this.notifyChange();
  }

  async prevTtsUnit(context: Context) {
    if (this.ttsUnits.length === 0) return;
    this.ttsCurrentIndex = Math.max(this.ttsCurrentIndex - 1, 0);
    this.ttsPlayGeneration++;
    if (this.ttsPlaying) {
      await this.speakAndHighlightCurrentUnit(context);
      if (this.ttsOutputMode === 'audio') {
        const ok = await this.triggerAudioPlayback('prev-audio');
        if (!ok) await this.tryNativeFallback('prev-audio', context);
      }
      this.scheduleNextTts(context);
    }
    this.notifyChange();
  }

  // Getter 方法
  getTtsUnits(): string[] { return this.ttsUnits; }
  getTtsCurrentIndex(): number { return this.ttsCurrentIndex; }
  getTtsPlaying(): boolean { return this.ttsPlaying; }
  getTtsPlaySpeed(): number { return this.ttsPlaySpeed; }
  getTtsErrorReason(): string { return this.ttsErrorReason; }
  isPanelVisible(): boolean { return this.ttsPanelVisible; }
  getTtsOutputMode(): string { return this.ttsOutputMode; }
  getTtsUnitParagraphIndex(): number[] { return this.ttsUnitParagraphIndex; }
  getTtsSource(): string { return this.ttsSource; }
  getTtsDebugInfo(): string { return this.ttsDebugInfo; }
}