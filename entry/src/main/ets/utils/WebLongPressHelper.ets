// utils/WebLongPressHelper.ets
import webview from '@ohos.web.webview'
import pasteboard from '@ohos.pasteboard'
import abilityAccessCtrl from '@ohos.abilityAccessCtrl'
import { Permissions } from '@kit.AbilityKit'
import { Prompt } from '@kit.ArkUI'
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

  constructor(webController: webview.WebviewController, tabManager: TabManager, uiContext: UIContext) {
    this.webController = webController
    this.tabManager = tabManager
    this.uiContext = uiContext
  }

  public onTouchEvent(event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      this.touchStartTime = Date.now()
      this.touchStartX = event.touches[0].x
      this.touchStartY = event.touches[0].y
      this.longPressTriggered = false
    } else if (event.type === TouchType.Move) {
      const moveX: number = event.touches[0].x
      const moveY: number = event.touches[0].y
      const distance: number = Math.hypot(moveX - this.touchStartX, moveY - this.touchStartY)
      if (distance > 10) {
        this.touchStartTime = 0
      }
    } else if (event.type === TouchType.Up) {
      if (!this.longPressTriggered && this.touchStartTime !== 0 && (Date.now() - this.touchStartTime) >= 500) {
        this.longPressTriggered = true
        const pos: Position = { x: this.touchStartX, y: this.touchStartY }
        this.handleLongPress(pos).catch((err: Error) => console.error("长按处理错误", err))
      }
      this.touchStartTime = 0
    }
  }

  private async handleLongPress(position: Position): Promise<void> {
    const x: number = position.x
    const y: number = position.y

    // 添加调试日志
    console.info(`长按坐标: (${x}, ${y})`)

    const js: string = `
      (function() {
        var x = ${x};
        var y = ${y};
        var elements = document.elementsFromPoint(x, y);
        var link = null;
        var img = null;
        var text = null;
        for (var i = 0; i < elements.length; i++) {
          var elem = elements[i];
          var a = elem.closest('a');
          if (a && !link) link = a.href;
          var image = elem.closest('img');
          if (image && !img) img = image.src;
          if (!text) text = elem.innerText || elem.textContent;
          if (link && img && text) break;
        }
        if (text) text = text.trim().substring(0, 200);
        var result = { link: link, img: img, text: text };
        console.info('长按获取到:', JSON.stringify(result));
        return JSON.stringify(result);
      })();
    `

    try {
      const result: string = await this.webController.runJavaScript(js)
      console.info("JS返回结果:", result)
      const info: LongPressElementInfo = JSON.parse(result)
      this.showMenu(info)
    } catch (e) {
      console.error("获取长按内容失败", e)
    }
  }

  private showMenu(info: LongPressElementInfo): void {
    const sheets: SheetItem[] = []

    if (info.link) {
      const link: string = info.link
      sheets.push({ title: "在新标签页打开链接", action: (): void => this.openInNewTab(link) })
      sheets.push({ title: "复制链接地址", action: (): void => this.copyToClipboard(link) })
    }
    if (info.img) {
      const img: string = info.img
      sheets.push({ title: "保存图片", action: (): void => { void this.saveImage(img); } })
      sheets.push({ title: "复制图片地址", action: (): void => this.copyToClipboard(img) })
    }
    if (info.text && info.text.trim()) {
      const text: string = info.text
      sheets.push({ title: "复制文本", action: (): void => this.copyToClipboard(text) })
    }

    if (sheets.length === 0) {
      Prompt.showToast({ message: "未检测到可操作内容" })
      return
    }

    this.uiContext.showActionSheet({
      title: "选择操作",
      message: "",
      sheets: sheets,
      cancel: (): void => {}
    })
  }

  private openInNewTab(url: string): void {
    this.tabManager.newTab(url, "新标签页")
    Prompt.showToast({ message: "已添加新标签页" })
  }

  private copyToClipboard(text: string): void {
    const pasteData = pasteboard.createPlainTextData(text)
    const systemPasteboard = pasteboard.getSystemPasteboard()
    systemPasteboard.setData(pasteData)
    Prompt.showToast({ message: "已复制" })
  }

  private async saveImage(url: string): Promise<void> {
    const permissions: Array<Permissions> = ['ohos.permission.WRITE_MEDIA']
    const granted: boolean = await this.checkPermissions(permissions)
    if (!granted) {
      Prompt.showToast({ message: "无存储权限，无法保存图片" })
      return
    }
    // TODO: 实现图片下载并保存到相册
    Prompt.showToast({ message: "保存图片功能开发中" })
  }

  private async checkPermissions(permissions: Array<Permissions>): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager()
    let allGranted: boolean = true
    for (const permission of permissions) {
      const result = await atManager.checkAccessToken(getContext().applicationInfo.accessTokenId, permission)
      if (result !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        allGranted = false
        break
      }
    }
    if (!allGranted) {
      const result = await atManager.requestPermissionsFromUser(getContext(), permissions)
      return result.authResults.every((r: number) => r === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED)
    }
    return true
  }
}