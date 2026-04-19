import { Prompt } from '@kit.ArkUI'
import webview from '@ohos.web.webview'
import emitter from '@ohos.events.emitter'
import { TabManager } from '../model/TabManager'
import { TabModel } from '../model/TabModel'

@CustomDialog
export default struct TabManagerDialog {
  @Consume('tabManager') tabManager: TabManager
  @Consume webviewController: webview.WebviewController

  dialogController: CustomDialogController

  @State tabs: TabModel[] = []
  @State currentIndex: number = 0

  aboutToAppear() {
    this.refreshTabs()
  }

  private refreshTabs() {
    this.tabs = [...this.tabManager.getTabs()]
    this.currentIndex = this.tabManager.getActiveIndex()
    AppStorage.setOrCreate('tabCount', this.tabs.length)
  }

  private getTabTitle(tab: TabModel): string {
    return tab.title && tab.title.trim().length > 0 ? tab.title : '新标签页'
  }

  private getTabSubtitle(tab: TabModel): string {
    return tab.url && tab.url.trim().length > 0 ? tab.url : 'about:blank'
  }

  private newTab() {
    this.tabManager.newTab('about:blank', '新标签页')
    this.refreshTabs()
    const newIndex = this.tabs.length - 1
    emitter.emit('switchTab', { data: { index: newIndex } })
    this.dialogController.close()
  }

  private closeTab(index: number) {
    if (this.tabs.length === 1) {
      Prompt.showToast({ message: '至少保留一个标签页' })
      return
    }

    this.tabManager.closeTab(index)
    this.refreshTabs()
    emitter.emit('switchTab', { data: { index: this.tabManager.getActiveIndex() } })
  }

  @Builder
  private TabItem(tab: TabModel, idx: number) {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(34)
          .height(34)
          .fill(idx === this.currentIndex ? '#2F6BFF' : '#ECEFF4')
        Text(`${idx + 1}`)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(idx === this.currentIndex ? Color.White : '#475467')
      }
      .margin({ right: 12 })

      Column({ space: 4 }) {
        Text(this.getTabTitle(tab))
          .fontSize(16)
          .fontWeight(idx === this.currentIndex ? FontWeight.Medium : FontWeight.Regular)
          .fontColor('#111827')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.getTabSubtitle(tab))
          .fontSize(12)
          .fontColor('#98A2B3')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (idx === this.currentIndex) {
        Text('当前')
          .fontSize(12)
          .fontColor('#2F6BFF')
          .margin({ right: 12 })
      }

      Button({ type: ButtonType.Circle, stateEffect: false }) {
        Text('x')
          .fontSize(18)
          .fontColor('#667085')
      }
      .width(32)
      .height(32)
      .backgroundColor('#F2F4F7')
      .onClick(() => {
        this.closeTab(idx)
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(idx === this.currentIndex ? '#F8FAFF' : Color.White)
    .borderRadius(20)
    .border({
      width: idx === this.currentIndex ? 1.5 : 1,
      color: idx === this.currentIndex ? '#C7D7FE' : '#EAECF0'
    })
    .onClick(() => {
      emitter.emit('switchTab', { data: { index: idx } })
      this.dialogController.close()
    })
  }

  build() {
    Column({ space: 16 }) {
      Column() {
        Row() {
          Text('标签页')
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .fontColor('#111827')
          Text(`${this.tabs.length}`)
            .fontSize(14)
            .fontColor('#475467')
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor('#EEF2FF')
            .borderRadius(999)
            .margin({ left: 10 })
          Blank()
          Button({ type: ButtonType.Circle, stateEffect: false }) {
            Text('x')
              .fontSize(20)
              .fontColor('#344054')
          }
          .width(34)
          .height(34)
          .backgroundColor('#F2F4F7')
          .onClick(() => {
            this.dialogController.close()
          })
        }
        .width('100%')

        Text('像参考图一样，把标签切换做成底部卡片列表。')
          .width('100%')
          .fontSize(12)
          .fontColor('#98A2B3')
          .margin({ top: 6 })
      }
      .width('100%')

      Scroll() {
        Column({ space: 12 }) {
          ForEach(this.tabs, (tab: TabModel, idx: number) => {
            this.TabItem(tab, idx)
          }, (tab: TabModel) => tab.id)
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ minHeight: 120, maxHeight: 360 })

      Column({ space: 10 }) {
        Button({ type: ButtonType.Circle, stateEffect: false }) {
          Text('+')
            .fontSize(30)
            .fontWeight(FontWeight.Lighter)
            .fontColor('#111827')
        }
        .width(54)
        .height(54)
        .backgroundColor(Color.White)
        .border({ width: 1, color: '#EAECF0' })
        .shadow({ radius: 14, color: '#14000000', offsetX: 0, offsetY: 6 })
        .onClick(() => {
          this.newTab()
        })

        Text('新建标签页')
          .fontSize(13)
          .fontColor('#667085')
      }
      .width('100%')
      .padding({ top: 4, bottom: 2 })
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 14, bottom: 24 })
    .backgroundColor('#F7F7FB')
    .borderRadius({ topLeft: 28, topRight: 28 })
  }
}
