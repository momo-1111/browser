// common/bean/FavoriteButton.ets
import { Prompt } from '@kit.ArkUI'
import RdbUtils from '../../utils/RdbUtils'
import webview from '@ohos.web.webview'
import emitter from '@ohos.events.emitter'

@Component
export struct FavoriteButton {
  @State imageResource: Resource = $r("app.media.favorite")
  @Consume webviewController: webview.WebviewController

  private currentUrl: string = ''

  aboutToAppear() {
    // 监听页面变化事件（由 Index 的 onPageEnd 发送）
    emitter.on({
      eventId: 10002
    }, () => {
      this.checkFavoriteStatus()
    })
    this.checkFavoriteStatus()
  }

  aboutToDisappear() {
    emitter.off(10002)
  }

  // 检查当前页面是否已收藏
  private async checkFavoriteStatus() {
    try {
      const url = this.webviewController.getUrl()
      if (!url || url === 'about:blank') {
        this.imageResource = $r("app.media.favorite")
        return
      }
      this.currentUrl = url
      const bookmarks = await RdbUtils.queryAllBookmarks()
      const exists = bookmarks.some(bookmark => bookmark.url === url)
      this.imageResource = exists ? $r("app.media.favorite_selected") : $r("app.media.favorite")
    } catch (e) {
      console.error("检查收藏状态失败", e)
    }
  }

  // 添加或移除收藏
  private async toggleFavorite() {
    try {
      const title = this.webviewController.getTitle()
      const url = this.webviewController.getUrl()
      if (!url || url === 'about:blank') {
        Prompt.showToast({ message: "当前页面无法收藏" })
        return
      }

      const bookmarks = await RdbUtils.queryAllBookmarks()
      const exists = bookmarks.some(bookmark => bookmark.url === url)

      if (exists) {
        // 已收藏，则删除
        const bookmark = bookmarks.find(b => b.url === url)
        if (bookmark) {
          await RdbUtils.deleteBookmarkById(bookmark.id)
          Prompt.showToast({ message: "已取消收藏" })
          this.imageResource = $r("app.media.favorite")
        }
      } else {
        // 未收藏，则添加
        await RdbUtils.insertBookmark(title, url)
        Prompt.showToast({ message: "已添加到收藏夹" })
        this.imageResource = $r("app.media.favorite_selected")
      }
    } catch (e) {
      console.error("切换收藏失败", e)
      Prompt.showToast({ message: "操作失败" })
    }
  }

  build() {
    Button({ type: ButtonType.Circle }) {
      Column() {
        Image(this.imageResource)
          .width(30)
          .height(30)
      }
    }
    .width(40)
    .height(40)
    .backgroundColor("#00FFFFFF")
    .onClick(() => {
      this.toggleFavorite()
    })
  }
}