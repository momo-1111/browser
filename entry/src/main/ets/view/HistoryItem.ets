// view/HistoryItem.ets
import webview from '@ohos.web.webview'

@Component
export default struct HistoryItem {
  @State title: string = ""
  @State url: string = ""
  @State translateX: number = 0
  @State deleteIcon: Resource = $r("app.media.trash_icon")
  @State showDeleteIcon: boolean = false

  onItemClick?: () => void   // 新增回调

  @Consume("webIsSearched") isSearched: boolean
  @Consume webviewController: webview.WebviewController

  build() {
    Row() {
      Button({ type: ButtonType.Normal }) {
        Column() {
          Text(this.title === "" ? this.url : this.title)
            .width("100%")
            .margin({ top: 5 })
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .textAlign(TextAlign.Start)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .maxLines(1)
          Text(this.url)
            .width("100%")
            .margin({ top: 5 })
            .fontSize(10)
            .textAlign(TextAlign.Start)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .maxLines(1)
        }
        .padding({ left: 15, right: 15 })
        .margin({ bottom: 5 })
      }
      .margin({ left: 15, right: 15, bottom: 2 })
      .borderRadius("40px")
      .backgroundColor(Color.White)
      .shadow({ radius: 5, color: Color.Gray })
      .layoutWeight(1)
      .onClick(() => {
        this.isSearched = true
        this.webviewController.loadUrl(this.url)
        if (this.onItemClick) {
          this.onItemClick()
        }
      })

      if (this.showDeleteIcon) {
        Button({ type: ButtonType.Circle }) {
          Image(this.deleteIcon)
            .width(20)
            .height(20)
            .fillColor("#E62E31")
        }
        .height(30)
        .width(30)
        .margin({ right: 15 })
        .backgroundColor("#00000000")
        .onClick(() => {
          console.log('删除项目:', this.title)
        })
      }
    }
    .justifyContent(FlexAlign.SpaceBetween)
    .width('100%')
    .offset({ x: this.translateX })
    .gesture(
      SwipeGesture({
        direction: SwipeDirection.Horizontal,
      })
        .onAction((event: GestureEvent) => {
          if (event.offsetX < -30) {
            this.translateX = -80
            this.showDeleteIcon = true
          } else if (event.offsetX > 30) {
            this.translateX = 0
            this.showDeleteIcon = false
          }
        })
    )
  }
}