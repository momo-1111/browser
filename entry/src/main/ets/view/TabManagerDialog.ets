import { Prompt } from '@kit.ArkUI'
import { TabManager } from '../model/TabManager'
import { TabModel } from '../model/TabModel'

@CustomDialog
export default struct TabManagerDialog {
  @Consume('tabManager') tabManager: TabManager
  dialogController: CustomDialogController
  @State tabs: TabModel[] = []
  @State currentIndex: number = 0
  @StorageLink('tabSwitchIndex') tabSwitchIndex: number = 0
  @StorageLink('tabSwitchToken') tabSwitchToken: number = 0

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

  private newTab() {
    this.tabManager.newTab('about:blank', '新标签页')
    this.refreshTabs()
    this.requestSwitchToTab(this.currentIndex)
    this.dialogController.close()
  }

  private selectTab(index: number) {
    if (!this.tabManager.switchTo(index)) return
    this.refreshTabs()
    this.requestSwitchToTab(this.currentIndex)
    this.dialogController.close()
  }

  private closeTab(index: number) {
    if (this.tabs.length === 1) {
      Prompt.showToast({ message: '至少保留一个标签页' })
      return
    }
    this.tabManager.closeTab(index)
    this.refreshTabs()
    this.requestSwitchToTab(this.currentIndex)
  }

  private requestSwitchToTab(index: number) {
    this.tabSwitchIndex = index
    this.tabSwitchToken = this.tabSwitchToken + 1
  }

  @Builder
  private TabIcon(isCurrent: boolean) {
    Stack({ alignContent: Alignment.Center }) {
      Circle()
        .width(18)
        .height(18)
        .fill('#00000000')
        .stroke(isCurrent ? '#4A86D9' : '#444444')
        .strokeWidth(1.4)
      Circle()
        .width(7)
        .height(7)
        .fill('#00000000')
        .stroke(isCurrent ? '#4A86D9' : '#444444')
        .strokeWidth(1)
    }
    .width(26)
    .height(26)
  }

  @Builder
  private TabItem(tab: TabModel, idx: number) {
    Row() {
      Row({ space: 8 }) {
        this.TabIcon(idx === this.currentIndex)
        Text(this.getTabTitle(tab))
          .fontSize(16)
          .fontWeight(idx === this.currentIndex ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(idx === this.currentIndex ? '#4A86D9' : '#222222')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .height(48)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.selectTab(idx)
      })

      Button({ type: ButtonType.Circle, stateEffect: false }) {
        Text('x')
          .fontSize(24)
          .fontColor('#222222')
          .fontWeight(FontWeight.Lighter)
      }
      .width(42)
      .height(42)
      .backgroundColor('#00FFFFFF')
      .onClick(() => {
        this.closeTab(idx)
      })
    }
    .width('100%')
    .height(48)
    .padding({ left: 14, right: 10 })
    .backgroundColor(Color.White)
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          ForEach(this.tabs, (tab: TabModel, idx: number) => {
            this.TabItem(tab, idx)
          }, (tab: TabModel) => tab.id)
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ minHeight: 48, maxHeight: 260 })

      Button({ type: ButtonType.Circle, stateEffect: false }) {
        Text('+')
          .fontSize(30)
          .fontColor('#222222')
          .fontWeight(FontWeight.Lighter)
      }
      .width(54)
      .height(54)
      .backgroundColor('#00FFFFFF')
      .margin({ top: 8, bottom: 8 })
      .onClick(() => {
        this.newTab()
      })
    }
    .width('100%')
    .padding({ left: 0, right: 0, top: 12, bottom: 18 })
    .backgroundColor(Color.White)
    .borderRadius({ topLeft: 8, topRight: 8 })
  }
}
