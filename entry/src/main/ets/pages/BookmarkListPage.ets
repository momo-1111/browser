import History from '../common/bean/History';
import { router, Prompt } from '@kit.ArkUI';
import RdbUtils from '../utils/RdbUtils';

@Entry
@Component
struct BookmarkListPage {
  @StorageLink("darkMode") darkMode: boolean = false;
  @State bookmarks: History[] = [];

  async aboutToAppear() {
    await this.loadBookmarks();
  }

  onPageShow() {
    void this.loadBookmarks();
  }

  private async loadBookmarks() {
    try {
      await RdbUtils.createBookmarkTable();
      this.bookmarks = await RdbUtils.queryAllBookmarks();
    } catch (error) {
      console.error('加载书签异常：' + error);
      Prompt.showToast({ message: '加载书签失败' });
    }
  }

  private async deleteBookmark(id: number) {
    try {
      await RdbUtils.deleteBookmark(id);
      await this.loadBookmarks();
      Prompt.showToast({ message: '已删除书签' });
    } catch (error) {
      console.error('删除书签异常：' + error);
      Prompt.showToast({ message: '删除失败' });
    }
  }

  build() {
    Column() {
      this.Header()

      if (this.bookmarks.length === 0) {
        this.EmptyState()
      } else {
        List({ space: 10 }) {
          ForEach(this.bookmarks, (item: History) => {
            ListItem() {
              this.BookmarkCard(item)
            }
          }, (item: History) => item.id.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 10, bottom: 18 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.darkMode ? '#14171C' : '#F4F7FB')
  }

  @Builder Header() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle, stateEffect: false }) {
          Image($r('app.media.left_arrow_icon'))
            .width(22)
            .height(22)
            .fillColor(this.darkMode ? Color.White : '#101828')
        }
        .width(40)
        .height(40)
        .backgroundColor(this.darkMode ? '#252B33' : Color.White)
        .onClick(() => router.back())

        Column({ space: 3 }) {
          Text('我的书签')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.darkMode ? Color.White : '#101828')
          Text(`共 ${this.bookmarks.length} 个收藏网页`)
            .fontSize(12)
            .fontColor(this.darkMode ? '#98A2B3' : '#667085')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 12 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text('收藏按钮添加的网页会在这里保存')
        .width('100%')
        .fontSize(13)
        .fontColor(this.darkMode ? '#98A2B3' : '#667085')
        .margin({ top: 16 })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 22, bottom: 10 })
  }

  @Builder BookmarkCard(item: History) {
    Row({ space: 12 }) {
      Text((item.title.length > 0 ? item.title : item.url).substring(0, 1).toUpperCase())
        .width(38)
        .height(38)
        .textAlign(TextAlign.Center)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#45A5FF')
        .backgroundColor(this.darkMode ? '#17324A' : '#EAF5FF')
        .borderRadius(14)

      Column({ space: 5 }) {
        Text(item.title.length > 0 ? item.title : '无标题')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.darkMode ? '#F8FAFC' : '#101828')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.url)
          .fontSize(11)
          .fontColor(this.darkMode ? '#98A2B3' : '#667085')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .onClick(() => {
        AppStorage.setOrCreate('targetUrl', item.url);
        router.back();
      })

      Button('删除')
        .height(28)
        .fontSize(12)
        .fontColor('#D92D20')
        .backgroundColor(this.darkMode ? '#3A2024' : '#FFF1F0')
        .borderRadius(14)
        .onClick(async () => {
          await this.deleteBookmark(item.id);
        })
    }
    .width('100%')
    .padding({ left: 14, right: 12, top: 12, bottom: 12 })
    .backgroundColor(this.darkMode ? '#252B33' : Color.White)
    .borderRadius(18)
    .shadow({
      radius: this.darkMode ? 0 : 12,
      color: '#16000000',
      offsetY: 5
    })
  }

  @Builder EmptyState() {
    Column({ space: 10 }) {
      Text('暂无书签')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.darkMode ? Color.White : '#101828')
      Text('打开网页后点击右上角收藏按钮，就能把它保存到这里。')
        .fontSize(13)
        .fontColor(this.darkMode ? '#98A2B3' : '#667085')
        .textAlign(TextAlign.Center)
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: 40, right: 40 })
    .justifyContent(FlexAlign.Center)
  }
}
