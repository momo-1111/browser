import History from '../common/bean/History'
import RdbUtils from '../utils/RdbUtils'
import { Prompt } from '@kit.ArkUI'

@CustomDialog
export default struct BookmarkDialog {
  @State bookmarks: History[] = []
  controller: CustomDialogController
  onOpenBookmark: (url: string) => void = () => {}

  async aboutToAppear() {
    await this.loadBookmarks()
  }

  private async loadBookmarks() {
    try {
      await RdbUtils.createBookmarkTable()
      this.bookmarks = await RdbUtils.queryAllBookmarks()
    } catch (error) {
      console.error('加载书签异常：' + error)
    }
  }

  private async deleteBookmark(id: number) {
    try {
      await RdbUtils.deleteBookmark(id)
      await this.loadBookmarks()
      Prompt.showToast({ message: '已删除书签' })
    } catch (error) {
      console.error('删除书签异常：' + error)
      Prompt.showToast({ message: '删除失败' })
    }
  }

  @Builder BookmarkItem(item: History) {
    Row({ space: 10 }) {
      Column({ space: 4 }) {
        Text(item.title.length > 0 ? item.title : '无标题')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#202124')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.url)
          .fontSize(11)
          .fontColor('#7A7F87')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .onClick(() => {
        this.controller.close()
        this.onOpenBookmark(item.url)
      })

      Button('删除')
        .height(28)
        .fontSize(12)
        .fontColor('#D92D20')
        .backgroundColor('#FFF1F0')
        .borderRadius(14)
        .onClick(async () => {
          await this.deleteBookmark(item.id)
        })
    }
    .width('100%')
    .padding({ left: 14, right: 12, top: 12, bottom: 12 })
    .backgroundColor('#F7F8FA')
    .borderRadius(16)
  }

  build() {
    Column() {
      Row() {
        Text('我的书签')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
        Text(`${this.bookmarks.length} 项`)
          .fontSize(12)
          .fontColor('#45A5FF')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 18, bottom: 14 })

      if (this.bookmarks.length === 0) {
        Column({ space: 8 }) {
          Text('暂无书签')
            .fontSize(16)
            .fontColor('#4B5563')
          Text('浏览网页时添加书签后，会在这里集中展示。')
            .fontSize(12)
            .fontColor('#9CA3AF')
        }
        .width('100%')
        .height(180)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.bookmarks, (item: History) => {
            ListItem() {
              this.BookmarkItem(item)
            }
          }, (item: History) => item.id.toString())
        }
        .width('100%')
        .height(330)
        .edgeEffect(EdgeEffect.Spring)
      }

      Button('关闭')
        .width('100%')
        .height(40)
        .fontSize(14)
        .fontColor('#344054')
        .backgroundColor('#F2F4F7')
        .borderRadius(20)
        .margin({ top: 14, bottom: 12 })
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
