// view/PagesDialog.ets
import History from '../common/bean/History'
import { HistoryGroup } from '../common/constants/CommonConstants'
import HistoryItem from './HistoryItem'

@CustomDialog
export default struct PagesDialog {
  @Consume("historyMap") historyMap: Map<string, History[]>
  dialogController: CustomDialogController

  @State historyGroups: HistoryGroup[] = []

  async aboutToAppear() {
    await this.loadHistoryData()
  }

  async loadHistoryData() {
    this.historyGroups = Array.from(this.historyMap.entries()).map(
      (item): HistoryGroup => ({   // 注意这里 : HistoryGroup
        date: item[0],
        histories: item[1]
      })
    )
  }

  formatted(date: string) {
    const today = this.getFormattedDate(new Date())
    const yesterday = this.getFormattedDate(new Date(Date.now() - 24 * 60 * 60 * 1000))
    if (date === today) return "今天"
    if (date === yesterday) return "昨天"
    let dateParts = date.split("_")
    return `${dateParts[0]}年${parseInt(dateParts[1])}月${parseInt(dateParts[2])}日`
  }

  getFormattedDate(date: Date) {
    const year = date.getFullYear()
    const month = date.getMonth() + 1
    const day = date.getDate()
    return `${year}_${month.toString().padStart(2, '0')}_${day.toString().padStart(2, '0')}`
  }

  build() {
    Column() {
      Text("浏览记录")
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 10 })
      List() {
        ForEach(this.historyGroups, (group: HistoryGroup) => {
          ListItemGroup({ header: this.ListGroupHeader(group.date) }) {
            ForEach(group.histories, (history: History) => {
              ListItem() {
                HistoryItem({ title: history.title, url: history.url })
              }
            })
          }
        })
      }
      .height("90%")
      .width("100%")
    }
    .width("100%")
    .height("100%")
    .backgroundColor(Color.White)
  }

  @Builder ListGroupHeader(date: string) {
    Text(this.formatted(date))
      .fontSize(17)
      .fontColor("#45A5FF")
      .margin({ left: 20, top: 5, bottom: 5 })
  }
}