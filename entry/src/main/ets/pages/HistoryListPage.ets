import History from '../common/bean/History';
import HistoryItem from '../view/HistoryItem';
import { router, Prompt } from '@kit.ArkUI';
import RdbUtils from '../utils/RdbUtils';

@Entry
@Component
struct HistoryListPage {
  @StorageLink("globalHistoryMap") historyMap: Map<string, History[]> = new Map();
  @StorageLink("darkMode") darkMode: boolean = false;

  build() {
    Column() {
      Row() {
        Row() {
          Image($r('app.media.left_arrow_icon')).width(24).onClick(() => router.back())
          Text("浏览历史").fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 15 })
        }

        // 右上角清空按钮
        Image($r('app.media.trash_icon'))
          .width(22).height(22)
          .fillColor("#E62E31")
          .onClick(() => this.clearAll())
      }
      .width('100%').padding(20).justifyContent(FlexAlign.SpaceBetween)

      List() {
        ForEach(Array.from(this.historyMap.keys()), (date: string) => {
          ListItemGroup({ header: this.DateHeader(date) }) {
            ForEach(this.historyMap.get(date), (item: History) => {
              ListItem() {
                HistoryItem({
                  title: item.title,
                  url: item.url,
                  onItemSelected: () => {
                    console.info("点击历史项: " + item.url);
                    // 1. 写入全局存储
                    AppStorage.setOrCreate("targetUrl", item.url);
                    // 2. 开始回退流程
                    router.back();
                  }
                })
              }
            })
          }
        })
      }.layoutWeight(1)
    }
    .width('100%').height('100%').backgroundColor(this.darkMode ? "#1C1C1C" : "#F5F5F7")
  }

  async clearAll() {
    await RdbUtils.deleteAll();
    this.historyMap.clear();
    AppStorage.setOrCreate("globalHistoryMap", new Map());
    Prompt.showToast({ message: "已清空所有记录" });
  }

  @Builder DateHeader(date: string) {
    Text(date).padding(10).fontSize(14).fontColor("#45A5FF").width('100%')
      .backgroundColor(this.darkMode ? "#2C2C2C" : "#EEEEEE")
  }
}