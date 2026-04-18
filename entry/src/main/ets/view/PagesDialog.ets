// view/PagesDialog.ets
import History from '../common/bean/History'
import { HistoryGroup } from '../common/constants/CommonConstants'
import HistoryItem from './HistoryItem'

@CustomDialog
export default struct PagesDialog {
  @Consume("historyMap") historyMap: Map<string, History[]>
  dialogController: CustomDialogController   // 必须存在，但不再使用
  onClose?: () => void                       // 外部传入关闭回调

  @State historyGroups: HistoryGroup[] = []

  async aboutToAppear() {
    await this.loadHistoryData()
  }

  async loadHistoryData() {
    try {
      const groups: HistoryGroup[] = []
      for (let entry of this.historyMap.entries()) {
        groups.push({ date: entry[0], histories: entry[1] })
      }
      this.historyGroups = groups
    } catch (error) {
      console.error('加载历史数据异常:', error)
    }
  }

  formatted(date: string): string {
    const today = this.getFormattedDate(new Date())
    const yesterday = this.getFormattedDate(new Date(Date.now() - 24 * 60 * 60 * 1000))
    if (date === today) return "今天"
    if (date === yesterday) return "昨天"
    let dateParts = date.split("_")
    return `${dateParts[0]}年${parseInt(dateParts[1])}月${parseInt(dateParts[2])}日`
  }

  getFormattedDate(date: Date): string {
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
                HistoryItem({
                  title: history.title,
                  url: history.url,
                  onItemClick: () => {
                    this.onClose?.()   // 点击后关闭对话框
                  }
                })
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