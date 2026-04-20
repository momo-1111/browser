import { WebLongPressMenuItem } from '../utils/WebLongPressHelper'

@CustomDialog
export default struct WebLongPressMenuDialog {
  controller: CustomDialogController
  items: WebLongPressMenuItem[] = []
  onSelect: (index: number) => void = () => {}

  @Builder
  private MenuIcon(item: WebLongPressMenuItem) {
    Stack({ alignContent: Alignment.Center }) {
      Circle()
        .width(38)
        .height(38)
        .fill('#F3F4F8')
      Text(item.icon)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(item.tone)
        .textAlign(TextAlign.Center)
    }
    .width(42)
    .height(42)
  }

  @Builder
  private MenuItem(item: WebLongPressMenuItem, index: number) {
    Row({ space: 12 }) {
      this.MenuIcon(item)

      Column({ space: 3 }) {
        Text(item.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#202124')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.subtitle)
          .fontSize(11)
          .fontColor('#8B9099')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('>')
        .fontSize(18)
        .fontColor('#C2C7D0')
        .fontWeight(FontWeight.Lighter)
    }
    .width('100%')
    .height(58)
    .padding({ left: 14, right: 12 })
    .backgroundColor('#F7F8FA')
    .borderRadius(16)
    .onClick(() => {
      this.controller.close()
      this.onSelect(index)
    })
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Text('网页操作')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
        Text(`${this.items.length} 项`)
          .fontSize(12)
          .fontColor('#45A5FF')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 18, bottom: 2 })

      List({ space: 10 }) {
        ForEach(this.items, (item: WebLongPressMenuItem, index: number) => {
          ListItem() {
            this.MenuItem(item, index)
          }
        }, (item: WebLongPressMenuItem) => `${item.title}-${item.subtitle}`)
      }
      .width('100%')
      .constraintSize({ minHeight: 58, maxHeight: 350 })
      .edgeEffect(EdgeEffect.Spring)

      Button('取消')
        .width('100%')
        .height(40)
        .fontSize(14)
        .fontColor('#344054')
        .backgroundColor('#F2F4F7')
        .borderRadius(20)
        .margin({ top: 2, bottom: 12 })
        .onClick(() => {
          this.controller.close()
        })
    }
    .width('100%')
    .padding({ left: 18, right: 18 })
    .backgroundColor(Color.White)
    .borderRadius({ topLeft: 20, topRight: 20 })
  }
}
