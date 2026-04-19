import { Prompt } from '@kit.ArkUI'
import History from './History'
import RdbUtils from '../../utils/RdbUtils'

@Component
export struct FavoriteButton {
  @State imageResource: Resource = $r('app.media.favorite')
  @Prop @Watch('onCurrentUrlChanged') currentUrl: string = ''
  @Prop currentTitle: string = ''

  aboutToAppear() {
    void this.checkFavoriteStatus()
  }

  private onCurrentUrlChanged() {
    void this.checkFavoriteStatus()
  }

  private async checkFavoriteStatus() {
    try {
      const url = this.currentUrl
      if (!url || url === 'about:blank') {
        this.imageResource = $r('app.media.favorite')
        return
      }
      await RdbUtils.createBookmarkTable()
      const bookmarks = await RdbUtils.queryAllBookmarks()
      const exists = bookmarks.some((bookmark: History) => bookmark.url === url)
      this.imageResource = exists ? $r('app.media.favorite_selected') : $r('app.media.favorite')
    } catch (error) {
      console.error('检查书签状态失败：' + error)
    }
  }

  private async toggleFavorite() {
    try {
      const url = this.currentUrl
      const title = this.currentTitle || url
      if (!url || url === 'about:blank') {
        Prompt.showToast({ message: '当前页面无法收藏' })
        return
      }

      await RdbUtils.createBookmarkTable()
      const bookmarks = await RdbUtils.queryAllBookmarks()
      const existed = bookmarks.find((bookmark: History) => bookmark.url === url)
      if (existed) {
        await RdbUtils.deleteBookmark(existed.id)
        this.imageResource = $r('app.media.favorite')
        Prompt.showToast({ message: '已取消收藏' })
      } else {
        await RdbUtils.insertBookmark(new History(title || url, url, new Date().getTime().toString()))
        this.imageResource = $r('app.media.favorite_selected')
        Prompt.showToast({ message: '已添加到书签' })
      }
    } catch (error) {
      console.error('切换书签失败：' + error)
      Prompt.showToast({ message: '操作失败' })
    }
  }

  build() {
    Button({ type: ButtonType.Circle, stateEffect: false }) {
      Image(this.imageResource)
        .width(26)
        .height(26)
    }
    .width(40)
    .height(40)
    .backgroundColor('#00FFFFFF')
    .onClick(() => {
      void this.toggleFavorite()
    })
  }
}
