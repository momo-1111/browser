import History from '../common/bean/History';
import HistoryItem from '../view/HistoryItem';
import { router, Prompt } from '@kit.ArkUI';
import RdbUtils from '../utils/RdbUtils';

@Entry
@Component
struct HistoryListPage {
  @StorageLink("globalHistoryMap") historyMap: Map<string, History[]> = new Map();
  @StorageLink("darkMode") darkMode: boolean = false;

  private getSortedDates(): string[] {
    return Array.from(this.historyMap.keys()).sort((a: string, b: string) => b.localeCompare(a));
  }

  private getHistoryCount(): number {
    let count = 0;
    this.historyMap.forEach((items: History[]) => {
      count += items.length;
    });
    return count;
  }

  private formatDate(date: string): string {
    const today = this.getDateKey(new Date());
    const yesterday = this.getDateKey(new Date(Date.now() - 24 * 60 * 60 * 1000));
    if (date === today) return '今天';
    if (date === yesterday) return '昨天';
    const parts = date.split('_');
    if (parts.length === 3) {
      return `${parts[0]}年${parseInt(parts[1])}月${parseInt(parts[2])}日`;
    }
    return date;
  }

  private getDateKey(date: Date): string {
    return `${date.getFullYear()}_${(date.getMonth() + 1).toString().padStart(2, '0')}_${date.getDate().toString().padStart(2, '0')}`;
  }

  build() {
    Column() {
      this.Header()

      if (this.getHistoryCount() === 0) {
        this.EmptyState()
      } else {
        List() {
          ForEach(this.getSortedDates(), (date: string) => {
            ListItemGroup({ header: this.DateHeader(date) }) {
              ForEach(this.historyMap.get(date), (item: History) => {
                ListItem() {
                  HistoryItem({
                    title: item.title,
                    url: item.url,
                    onItemSelected: () => {
                      console.info("点击历史项: " + item.url);
                      AppStorage.setOrCreate("targetUrl", item.url);
                      router.back();
                    }
                  })
                }
              })
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ top: 6, bottom: 12 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.darkMode ? "#14171C" : "#F4F7FB")
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
          Text("浏览历史")
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.darkMode ? Color.White : '#101828')
          Text(`共 ${this.getHistoryCount()} 条记录`)
            .fontSize(12)
            .fontColor(this.darkMode ? '#98A2B3' : '#667085')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 12 })

        Button({ type: ButtonType.Circle, stateEffect: false }) {
          Image($r('app.media.trash_icon'))
            .width(20)
            .height(20)
            .fillColor('#E62E31')
        }
        .width(40)
        .height(40)
        .backgroundColor(this.darkMode ? '#3A2024' : '#FFF1F0')
        .onClick(() => this.clearAll())
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text('轻点记录即可回到对应网页')
        .width('100%')
        .fontSize(13)
        .fontColor(this.darkMode ? '#98A2B3' : '#667085')
        .margin({ top: 16 })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 22, bottom: 10 })
  }

  @Builder EmptyState() {
    Column({ space: 10 }) {
      Text('暂无浏览历史')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.darkMode ? Color.White : '#101828')
      Text('访问过的网页会自动出现在这里。')
        .fontSize(13)
        .fontColor(this.darkMode ? '#98A2B3' : '#667085')
    }
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  async clearAll() {
    await RdbUtils.deleteAll();
    this.historyMap.clear();
    AppStorage.setOrCreate("globalHistoryMap", new Map());
    Prompt.showToast({ message: "已清空所有记录" });
  }

  @Builder DateHeader(date: string) {
    Row() {
      Text(this.formatDate(date))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.darkMode ? '#E4E7EC' : '#344054')
      Text(`${this.historyMap.get(date)?.length || 0}`)
        .fontSize(11)
        .fontColor('#45A5FF')
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .backgroundColor(this.darkMode ? '#17324A' : '#EAF5FF')
        .borderRadius(10)
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .padding({ left: 20, right: 20, top: 12, bottom: 8 })
  }
}
