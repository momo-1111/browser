import History from '../common/bean/History'
import RdbUtils from '../utils/RdbUtils'
import webview from '@ohos.web.webview'

@CustomDialog
export default struct BookmarkDialog {
  @State bookmarks: History[] = []
  controller: CustomDialogController
  @Consume webviewController: webview.WebviewController
  @Consume("webIsSearched") isSearched: boolean

  async aboutToAppear() {
    this.bookmarks = await RdbUtils.queryAllBookmarks()
  }

  build() {
    Column() {
      Text("我的书签")
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 10 })

      if (this.bookmarks.length === 0) {
        Text("暂无书签").margin({ top: 50 }).fontColor(Color.Gray)
      } else {
        List({ space: 10 }) {
          ForEach(this.bookmarks, (item: History) => {
            ListItem() {
              Row() {
                Column() {
                  Text(item.title).fontSize(14).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(item.url).fontSize(10).fontColor(Color.Gray).maxLines(1)
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)

                Button("删除").fontSize(12).backgroundColor(Color.Red).height(25)
                  .onClick(async () => {
                    await RdbUtils.deleteBookmark(item.id)
                    this.bookmarks = await RdbUtils.queryAllBookmarks()
                  })
              }
              .width('100%')
              .padding(10)
              .backgroundColor('#F0F0F0')
              .borderRadius(10)
              .onClick(() => {
                this.webviewController.loadUrl(item.url)
                this.isSearched = true
                this.controller.close()
              })
            }
          })
        }.width('90%').height('70%')
      }
    }
    .width('100%')
    .height('60%')
    .backgroundColor(Color.White)
    .borderRadius({ topLeft: 20, topRight: 20 })
  }
}