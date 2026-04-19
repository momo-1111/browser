import webview from '@ohos.web.webview'
import pasteboard from '@ohos.pasteboard'
import { Prompt } from '@kit.ArkUI'
import emitter from '@ohos.events.emitter'
import { http } from '@kit.NetworkKit'
import { fileIo as fs, picker, fileUri } from '@kit.CoreFileKit'
import { TabManager } from '../model/TabManager'
import RdbUtils from './RdbUtils'

interface LongPressElementInfo {
  link: string | null
  img: string | null
  text: string | null
  selectedText: string | null
}

interface Position {
  x: number
  y: number
}

export interface WebLongPressMenuItem {
  title: string
  icon: string
  subtitle: string
  tone: string
}

interface SheetItem extends WebLongPressMenuItem {
  action: () => void
}

export class WebLongPressHelper {
  private webController: webview.WebviewController
  private tabManager: TabManager
  private uiContext: UIContext
  private appContext: Context
  private getUserId: () => string
  private onShowMenu?: (items: WebLongPressMenuItem[]) => void
  private onAddToNote?: (sourceType: string, sourceText: string) => void
  private menuActions: (() => void)[] = []

  private touchStartTime: number = 0
  private touchStartX: number = 0
  private touchStartY: number = 0
  private longPressTriggered: boolean = false
  private longPressShouldConsume: boolean = false
  private longPressTimer: number = -1
  private readonly longPressDelay: number = 550
  private readonly moveTolerance: number = 12
  private readonly debugEnabled: boolean = false

  constructor(
    webController: webview.WebviewController,
    tabManager: TabManager,
    uiContext: UIContext,
    appContext: Context,
    getUserId: () => string,
    onShowMenu?: (items: WebLongPressMenuItem[]) => void,
    onAddToNote?: (sourceType: string, sourceText: string) => void
  ) {
    this.webController = webController
    this.tabManager = tabManager
    this.uiContext = uiContext
    this.appContext = appContext
    this.getUserId = getUserId
    this.onShowMenu = onShowMenu
    this.onAddToNote = onAddToNote
  }

  public runMenuAction(index: number): void {
    const action = this.menuActions[index]
    if (action) {
      action()
    }
  }

  public onTouchEvent(event: TouchEvent): boolean {
    if (!event.touches || event.touches.length === 0) {
      this.logDebug('touch empty, cancel')
      this.cancelLongPress()
      return false
    }

    if (event.type === TouchType.Down) {
      this.touchStartTime = Date.now()
      this.touchStartX = event.touches[0].x
      this.touchStartY = event.touches[0].y
      this.longPressTriggered = false
      this.longPressShouldConsume = false
      this.logDebug(`touch down x=${this.touchStartX}, y=${this.touchStartY}`)
      this.startLongPressTimer()
      return false
    }

    if (event.type === TouchType.Move) {
      const moveX: number = event.touches[0].x
      const moveY: number = event.touches[0].y
      const distance: number = Math.hypot(moveX - this.touchStartX, moveY - this.touchStartY)
      if (distance > this.moveTolerance) {
        this.logDebug(`touch move cancel distance=${distance}`)
        this.cancelLongPress()
      }
      return this.longPressShouldConsume
    }

    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      const consumed: boolean = this.longPressShouldConsume
      this.logDebug(`touch end type=${event.type}, consumed=${consumed}`)
      this.cancelLongPress()
      return consumed
    }

    return this.longPressShouldConsume
  }

  private startLongPressTimer(): void {
    this.clearLongPressTimer()
    this.logDebug(`start timer delay=${this.longPressDelay}`)
    this.longPressTimer = setTimeout(() => {
      if (this.touchStartTime === 0 || this.longPressTriggered) {
        this.logDebug(`timer ignored startTime=${this.touchStartTime}, triggered=${this.longPressTriggered}`)
        return
      }
      this.longPressTriggered = true
      this.longPressShouldConsume = false
      const pos: Position = { x: this.touchStartX, y: this.touchStartY }
      this.logDebug(`timer fired x=${pos.x}, y=${pos.y}`)
      this.handleLongPress(pos).catch((err: Error) => console.error('Long press failed: ' + err.message))
    }, this.longPressDelay)
  }

  private cancelLongPress(): void {
    this.clearLongPressTimer()
    this.touchStartTime = 0
    this.longPressTriggered = false
    this.longPressShouldConsume = false
  }

  private clearLongPressTimer(): void {
    if (this.longPressTimer !== -1) {
      clearTimeout(this.longPressTimer)
      this.logDebug('clear timer')
      this.longPressTimer = -1
    }
  }

  private logDebug(message: string): void {
    if (!this.debugEnabled) {
      return
    }
    console.info('[WebLongPress] ' + message)
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

  public disableNativeImageDrag(): void {
    const js: string = `
      (function() {
        if (window.__webLongPressDragDisabled) return 'ready';
        window.__webLongPressDragDisabled = true;
        function patchImages() {
          var images = document.getElementsByTagName('img');
          for (var i = 0; i < images.length; i++) {
            images[i].draggable = false;
            images[i].style.webkitUserDrag = 'none';
          }
        }
        patchImages();
        document.addEventListener('dragstart', function(event) {
          if (event.target && event.target.tagName === 'IMG') {
            event.preventDefault();
          }
        }, true);
        new MutationObserver(patchImages).observe(document.documentElement, { childList: true, subtree: true });
        return 'ready';
      })();
    `

    this.webController.runJavaScript(js)
      .then((result: string) => this.logDebug('disable image drag result=' + result))
      .catch((error: Error) => this.logDebug('disable image drag failed=' + error.message))
  }

  private async handleLongPress(position: Position): Promise<void> {
    const js: string = `
      (function() {
        function pickElements(x, y) {
          var elements = document.elementsFromPoint(x, y);
          return elements && elements.length > 0 ? elements : [];
        }
        function findBackgroundImage(elem) {
          var style = window.getComputedStyle(elem);
          if (!style || !style.backgroundImage || style.backgroundImage === 'none') return null;
          var match = style.backgroundImage.match(/url\\(["']?(.*?)["']?\\)/);
          return match ? match[1] : null;
        }
        function collect(elements) {
          var link = null;
          var img = null;
          var text = null;
          var selectedText = '';
          try {
            selectedText = (window.getSelection && window.getSelection().toString()) || '';
          } catch (selectionError) {
            selectedText = '';
          }
          for (var i = 0; i < elements.length; i++) {
            var elem = elements[i];
            if (!link && elem.closest) {
              var a = elem.closest('a');
              if (a && a.href) link = a.href;
            }
            if (!img) {
              if (elem.closest) {
                var image = elem.closest('img');
                if (image && image.currentSrc) img = image.currentSrc;
                if (!img && image && image.src) img = image.src;
              }
              if (!img) img = findBackgroundImage(elem);
            }
            if (!text) text = elem.innerText || elem.textContent || '';
            if (link && img && text) break;
          }
          if (text) text = text.trim().replace(/\\s+/g, ' ').substring(0, 200);
          if (selectedText) selectedText = selectedText.trim().replace(/\\s+/g, ' ').substring(0, 1000);
          return { link: link, img: img, text: text, selectedText: selectedText };
        }
        var x = ${position.x};
        var y = ${position.y};
        var dpr = window.devicePixelRatio || 1;
        var info = collect(pickElements(x, y));
        if (!info.link && !info.img && !info.text && dpr !== 1) {
          info = collect(pickElements(x / dpr, y / dpr));
        }
        return JSON.stringify(info);
      })();
    `

    try {
      this.logDebug('runJavaScript start')
      const result: string = await this.webController.runJavaScript(js)
      this.logDebug('runJavaScript result=' + result)
      const info: LongPressElementInfo = JSON.parse(this.decodeScriptResult(result)) as LongPressElementInfo
      this.logDebug(`parsed link=${info.link ? 'yes' : 'no'}, img=${info.img ? 'yes' : 'no'}, text=${info.text ? info.text.length : 0}, selected=${info.selectedText ? info.selectedText.length : 0}`)
      this.showMenu(info)
    } catch (error) {
      console.error('Resolve long press target failed: ' + error)
      this.logDebug('handle failed: ' + error)
      Prompt.showToast({ message: '长按操作失败' })
    }
  }

  private showMenu(info: LongPressElementInfo): void {
    const sheets: SheetItem[] = []
    const selectedText: string = info.selectedText ? info.selectedText.trim() : ''
    const hasSelectedText: boolean = selectedText.length > 0

    if (!info.link && !info.img && !hasSelectedText) {
      this.logDebug('text long press without selection, leave native selection active')
      this.longPressShouldConsume = false
      return
    }

    if (info.link) {
      const link: string = info.link
      sheets.push({
        title: '在新标签页打开',
        icon: '+',
        subtitle: '保留当前页面',
        tone: '#2F6BFF',
        action: (): void => this.openInNewTab(link)
      })
      sheets.push({
        title: '复制链接地址',
        icon: 'C',
        subtitle: '复制到剪贴板',
        tone: '#3D4350',
        action: (): void => this.copyToClipboard(link)
      })
    }
    if (info.img) {
      const img: string = info.img
      sheets.push({
        title: '保存图片',
        icon: 'D',
        subtitle: '选择保存位置',
        tone: '#0F8A5F',
        action: (): void => { void this.saveImage(img) }
      })
      sheets.push({
        title: '复制图片地址',
        icon: 'U',
        subtitle: '复制图片 URL',
        tone: '#3D4350',
        action: (): void => this.copyToClipboard(img)
      })
    }
    if (hasSelectedText) {
      sheets.push({
        title: '复制选中文字',
        icon: 'T',
        subtitle: '复制蓝色选区内容',
        tone: '#7A4CC2',
        action: (): void => this.copyToClipboard(selectedText)
      })
    }

    const noteText: string = this.buildNoteText(info)
    if (noteText.length > 0) {
      sheets.push({
        title: '添加到笔记',
        icon: 'N',
        subtitle: '保存到网页笔记',
        tone: '#2F6BFF',
        action: (): void => this.addToNote(noteText)
      })
    }

    if (sheets.length === 0) {
      this.logDebug('no actionable target')
      this.longPressShouldConsume = false
      return
    }

    this.longPressShouldConsume = true
    this.logDebug('showActionSheet count=' + sheets.length)
    this.menuActions = sheets.map((item: SheetItem) => item.action)
    if (this.onShowMenu) {
      const menuItems: WebLongPressMenuItem[] = []
      for (const item of sheets) {
        const menuItem: WebLongPressMenuItem = {
          title: item.title,
          icon: item.icon,
          subtitle: item.subtitle,
          tone: item.tone
        }
        menuItems.push(menuItem)
      }
      this.onShowMenu(menuItems)
      return
    }

    this.uiContext.showActionSheet({
      title: '网页操作',
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

  private buildNoteText(info: LongPressElementInfo): string {
    let parts: string[] = []
    if (info.selectedText && info.selectedText.trim().length > 0) {
      parts.push(info.selectedText.trim())
    } else if ((info.link || info.img) && info.text && info.text.trim().length > 0) {
      parts.push(info.text.trim())
    }
    if (info.link) {
      parts.push('链接：' + info.link)
    }
    if (info.img) {
      parts.push('图片：' + info.img)
    }
    return parts.join('\n')
  }

  private addToNote(sourceText: string): void {
    if (this.onAddToNote) {
      this.onAddToNote('web-content', sourceText)
      return
    }
    this.copyToClipboard(sourceText)
    Prompt.showToast({ message: '已复制内容，可粘贴到笔记' })
  }

  private getImageExtension(url: string, contentType: string): string {
    const lowerType: string = contentType.toLowerCase()
    if (lowerType.includes('png')) return 'png'
    if (lowerType.includes('webp')) return 'webp'
    if (lowerType.includes('gif')) return 'gif'
    if (lowerType.includes('bmp')) return 'bmp'
    if (lowerType.includes('jpeg') || lowerType.includes('jpg')) return 'jpg'

    const cleanUrl: string = url.split('?')[0].split('#')[0].toLowerCase()
    const match: RegExpMatchArray | null = cleanUrl.match(/\\.([a-z0-9]+)$/)
    if (match && ['png', 'webp', 'gif', 'bmp', 'jpg', 'jpeg'].includes(match[1])) {
      return match[1] === 'jpeg' ? 'jpg' : match[1]
    }
    return 'jpg'
  }

  private getHeaderValue(headers: Object, key: string): string {
    const values = headers as Record<string, Object>
    return values[key] ? `${values[key]}` : ''
  }

  private async saveImage(url: string): Promise<void> {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      this.copyToClipboard(url)
      Prompt.showToast({ message: '当前图片地址暂不支持直接保存，已复制图片地址' })
      return
    }

    const request = http.createHttp()
    try {
      Prompt.showToast({ message: '正在下载图片...' })
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 15000,
        readTimeout: 15000,
        header: { 'User-Agent': 'Mozilla/5.0 (Linux; HarmonyOS) AppleWebKit/537.36' }
      })

      const payload = response.result as ArrayBuffer
      if (response.responseCode < 200 || response.responseCode >= 300 || !payload || payload.byteLength === 0) {
        throw new Error('download failed: ' + response.responseCode)
      }

      const headers: Object = response.header || {}
      const contentType: string = this.getHeaderValue(headers, 'content-type') || this.getHeaderValue(headers, 'Content-Type')
      const extension: string = this.getImageExtension(url, contentType)
      const fileName: string = `WebImage_${Date.now()}.${extension}`
      const localPath: string = `${this.appContext.cacheDir}/${fileName}`
      const localFile = fs.openSync(localPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC)
      fs.writeSync(localFile.fd, payload)
      fs.closeSync(localFile)

      const documentPicker = new picker.DocumentViewPicker()
      const saveOptions = new picker.DocumentSaveOptions()
      saveOptions.newFileNames = [fileName]
      const saveUris = await documentPicker.save(saveOptions)
      if (saveUris.length === 0) {
        return
      }

      const targetPath: string = new fileUri.FileUri(saveUris[0]).path
      const srcFile = fs.openSync(localPath, fs.OpenMode.READ_ONLY)
      const destFile = fs.openSync(targetPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC)
      fs.copyFileSync(srcFile.fd, destFile.fd)
      fs.closeSync(srcFile)
      fs.closeSync(destFile)
      await RdbUtils.createDownloadTable()
      await RdbUtils.insertDownload(fileName, localPath, saveUris[0], 'image', this.getUserId())
      Prompt.showToast({ message: '图片已保存' })
    } catch (error) {
      console.error('Save image failed: ' + error)
      this.copyToClipboard(url)
      Prompt.showToast({ message: '保存图片失败，已复制图片地址' })
    } finally {
      request.destroy()
    }
  }
}
