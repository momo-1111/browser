import webview from '@ohos.web.webview'
import pasteboard from '@ohos.pasteboard'
import { Prompt } from '@kit.ArkUI'
import emitter from '@ohos.events.emitter'
import { TabManager } from '../model/TabManager'

interface LongPressElementInfo {
  link: string | null
  img: string | null
  text: string | null
}

interface Position {
  x: number
  y: number
}

interface SheetItem {
  title: string
  action: () => void
}

export class WebLongPressHelper {
  private webController: webview.WebviewController
  private tabManager: TabManager
  private uiContext: UIContext

  private touchStartTime: number = 0
  private touchStartX: number = 0
  private touchStartY: number = 0
  private longPressTriggered: boolean = false
  private longPressTimer: number = -1
  private readonly longPressDelay: number = 550
  private readonly moveTolerance: number = 12

  constructor(webController: webview.WebviewController, tabManager: TabManager, uiContext: UIContext) {
    this.webController = webController
    this.tabManager = tabManager
    this.uiContext = uiContext
  }

  public onTouchEvent(event: TouchEvent): void {
    if (!event.touches || event.touches.length === 0) {
      this.cancelLongPress()
      return
    }

    if (event.type === TouchType.Down) {
      this.touchStartTime = Date.now()
      this.touchStartX = event.touches[0].x
      this.touchStartY = event.touches[0].y
      this.longPressTriggered = false
      this.startLongPressTimer()
    } else if (event.type === TouchType.Move) {
      const moveX: number = event.touches[0].x
      const moveY: number = event.touches[0].y
      const distance: number = Math.hypot(moveX - this.touchStartX, moveY - this.touchStartY)
      if (distance > this.moveTolerance) {
        this.cancelLongPress()
      }
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.cancelLongPress()
    }
  }

  private startLongPressTimer(): void {
    this.clearLongPressTimer()
    this.longPressTimer = setTimeout(() => {
      if (this.touchStartTime === 0 || this.longPressTriggered) {
        return
      }
      this.longPressTriggered = true
      const pos: Position = { x: this.touchStartX, y: this.touchStartY }
      this.handleLongPress(pos).catch((err: Error) => console.error('长按处理错误：' + err.message))
    }, this.longPressDelay)
  }

  private cancelLongPress(): void {
    this.clearLongPressTimer()
    this.touchStartTime = 0
  }

  private clearLongPressTimer(): void {
    if (this.longPressTimer !== -1) {
      clearTimeout(this.longPressTimer)
      this.longPressTimer = -1
    }
  }

  private decodeScriptResult(raw: string): string {
    if (!raw) return ''
    try {
      const parsed = JSON.parse(raw) as Object
      if (typeof parsed === 'string') {
        return parsed
      }
    } catch (error) {
      if (raw.length >= 2 && raw.startsWith('"') && raw.endsWith('"')) {
        return raw.substring(1, raw.length - 1)
      }
    }
    return raw
  }

  private async handleLongPress(position: Position): Promise<void> {
    const js: string = `
      (function() {
        var x = ${position.x};
        var y = ${position.y};
        var dpr = window.devicePixelRatio || 1;
        var cssX = x / dpr;
        var cssY = y / dpr;
        var elements = document.elementsFromPoint(cssX, cssY);
        var link = null;
        var img = null;
        var text = null;
        for (var i = 0; i < elements.length; i++) {
          var elem = elements[i];
          if (!link && elem.closest) {
            var a = elem.closest('a');
            if (a && a.href) link = a.href;
          }
          if (!img && elem.closest) {
            var image = elem.closest('img');
            if (image && image.src) img = image.src;
          }
          if (!text) text = elem.innerText || elem.textContent || '';
          if (link && img && text) break;
        }
        if (text) text = text.trim().replace(/\\s+/g, ' ').substring(0, 200);
        return JSON.stringify({ link: link, img: img, text: text });
      })();
    `

    try {
      const result: string = await this.webController.runJavaScript(js)
      const info: LongPressElementInfo = JSON.parse(this.decodeScriptResult(result))
      this.showMenu(info)
    } catch (error) {
      console.error('获取长按内容失败：' + error)
      Prompt.showToast({ message: '长按内容识别失败' })
    }
  }

  private showMenu(info: LongPressElementInfo): void {
    const sheets: SheetItem[] = []

    if (info.link) {
      const link: string = info.link
      sheets.push({ title: '在新标签页打开链接', action: (): void => this.openInNewTab(link) })
      sheets.push({ title: '复制链接地址', action: (): void => this.copyToClipboard(link) })
    }
    if (info.img) {
      const img: string = info.img
      sheets.push({ title: '保存图片', action: (): void => { void this.saveImage(img) } })
      sheets.push({ title: '复制图片地址', action: (): void => this.copyToClipboard(img) })
    }
    if (info.text && info.text.trim().length > 0) {
      const text: string = info.text
      sheets.push({ title: '复制文本', action: (): void => this.copyToClipboard(text) })
    }

    if (sheets.length === 0) {
      Prompt.showToast({ message: '未检测到可操作内容' })
      return
    }

    this.uiContext.showActionSheet({
      title: '选择操作',
      message: '',
      sheets: sheets,
      cancel: (): void => {}
    })
  }

  private openInNewTab(url: string): void {
    this.tabManager.newTab(url, '新标签页')
    AppStorage.setOrCreate('tabCount', this.tabManager.getTabs().length)
    emitter.emit('switchTab', { data: { index: this.tabManager.getActiveIndex() } })
    Prompt.showToast({ message: '已在新标签页打开' })
  }

  private copyToClipboard(text: string): void {
    const pasteData = pasteboard.createPlainTextData(text)
    const systemPasteboard = pasteboard.getSystemPasteboard()
    systemPasteboard.setData(pasteData)
    Prompt.showToast({ message: '已复制' })
  }

  private async saveImage(url: string): Promise<void> {
    this.copyToClipboard(url)
    Prompt.showToast({ message: '图片保存暂未接入，已复制图片地址' })
  }
}
