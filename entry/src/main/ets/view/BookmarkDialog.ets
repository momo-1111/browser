// view/BookmarkDialog.ets
import History from '../common/bean/History'
import RdbUtils from '../utils/RdbUtils'
import { Prompt } from '@kit.ArkUI'
import webview from '@ohos.web.webview'

@CustomDialog
export default struct BookmarkDialog {
  dialogController?: CustomDialogController   // 必须存在以满足装饰器要求
  onClose?: () => void                        // 外部传入的关闭回调

  @Consume webviewController: webview.WebviewController
  @Consume("webIsSearched") isSearched: boolean

  @State bookmarks: History[] = []

  aboutToAppear() {
    this.loadBookmarks()
  }

  async loadBookmarks() {
    try {
      this.bookmarks = await RdbUtils.queryAllBookmarks()
    } catch (error) {
      console.error('加载收藏夹异常:', error)
    }
  }

  async deleteBookmark(id: number) {
    try {
      await RdbUtils.deleteBookmarkById(id)
      await this.loadBookmarks()
      Prompt.showToast({ message: "已删除" })
    } catch (error) {
      console.error('删除收藏异常:', error)
      Prompt.showToast({ message: "删除失败" })
    }
  }

  @Builder BookmarkItem(bookmark: History) {
    Row() {
      Column() {
        Text(bookmark.title || '无标题')
          .fontSize(16)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(bookmark.url)
          .fontSize(12)
          .fontColor('#888')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ right: 10 })

      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r("sys.symbol.xmark_circle"))
          .fontSize(20)
          .fontColor([Color.Gray])
      }
      .width(28)
      .height(28)
      .backgroundColor('#f0f0f0')
      .onClick(() => {
        this.deleteBookmark(bookmark.id)
      })
    }
    .width('100%')
    .padding(10)
    .backgroundColor('#f9f9f9')
    .borderRadius(16)
    .onClick(() => {
      this.webviewController.loadUrl(bookmark.url)
      this.isSearched = true
      if (this.onClose) this.onClose()   // 关闭对话框
    })
  }

  build() {
    Column() {
      Text("我的收藏")
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 16, bottom: 8 })

      if (this.bookmarks.length === 0) {
        Text("暂无收藏")
          .fontSize(14)
          .fontColor('#999')
          .margin({ top: 40 })
      } else {
        List({ space: 10 }) {
          ForEach(this.bookmarks, (bookmark: History) => {
            ListItem() {
              this.BookmarkItem(bookmark)
            }
          }, (bookmark: History) => bookmark.id.toString())
        }
        .height('70%')
        .width('100%')
      }

      Button("关闭")
        .width('90%')
        .height(40)
        .margin({ top: 16, bottom: 20 })
        .onClick(() => {
          if (this.onClose) this.onClose()
        })
    }
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius({ topLeft: 20, topRight: 20 })
    .width('100%')
  }
}