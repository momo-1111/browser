// view/TabManagerDialog.ets
import { TabManager } from '../model/TabManager'
import { TabModel } from '../model/TabModel'
import { Prompt } from '@kit.ArkUI'
import webview from '@ohos.web.webview'

@CustomDialog
export default struct TabManagerDialog {
  @Consume('tabManager') tabManager: TabManager
  @Consume webviewController: webview.WebviewController
  @Consume("webIsSearched") isSearched: boolean

  dialogController: CustomDialogController

  @State tabs: TabModel[] = []
  @State currentIndex: number = 0

  aboutToAppear() {
    this.refreshTabs()
  }

  refreshTabs() {
    this.tabs = this.tabManager.getTabs()
    this.currentIndex = this.tabManager.getActiveIndex()
  }

  newTab() {
    // 新建标签页，打开空白页
    const newTab = this.tabManager.newTab('about:blank', '新标签页')
    this.refreshTabs()
    // 自动切换到新标签页
    this.tabManager.switchTo(this.tabs.length - 1)
    this.currentIndex = this.tabManager.getActiveIndex()
    // 加载空白页
    this.webviewController.loadUrl('about:blank')
    // 更新 Index 中的 url 状态（通过 webviewController 的 onPageEnd 会自动同步）
    this.dialogController.close()
    Prompt.showToast({ message: '已创建新标签页' })
  }

  closeTab(index: number) {
    if (this.tabs.length === 1) {
      Prompt.showToast({ message: '至少保留一个标签页' })
      return
    }
    this.tabManager.closeTab(index)
    this.refreshTabs()
    // 如果关闭的是当前标签页，需要重新加载新当前标签页的 URL
    const current = this.tabManager.getCurrentTab()
    if (current) {
      this.webviewController.loadUrl(current.url)
    }
  }

  switchToTab(index: number) {
    this.tabManager.switchTo(index)
    const current = this.tabManager.getCurrentTab()
    if (current) {
      this.webviewController.loadUrl(current.url)
      // 如果当前 URL 不是空白页，标记已搜索
      if (current.url && current.url !== 'about:blank') {
        this.isSearched = true
      }
    }
    this.dialogController.close()
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('标签页管理')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
        Blank()
        Button('完成')
          .onClick(() => {
            this.dialogController.close()
          })
      }
      .width('100%')
      .padding(12)

      // 标签页列表
      List({ space: 10 }) {
        ForEach(this.tabs, (tab: TabModel, idx: number) => {
          ListItem() {
            Row() {
              Image($r('app.media.clone_regular'))
                .width(24)
                .height(24)
                .margin({ right: 12 })

              Column() {
                Text(tab.title || '新标签页')
                  .fontSize(16)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(tab.url || 'about:blank')
                  .fontSize(12)
                  .fontColor('#888')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              if (idx === this.currentIndex) {
                Text('当前')
                  .fontSize(12)
                  .fontColor('#45A5FF')
                  .margin({ right: 10 })
              }

              Button({ type: ButtonType.Circle }) {
                SymbolGlyph($r("sys.symbol.xmark_circle"))
                  .fontSize(20)
                  .fontColor([Color.Gray])
              }
              .width(28)
              .height(28)
              .backgroundColor('#f0f0f0')
              .onClick(() => {
                this.closeTab(idx)
              })
            }
            .padding(10)
            .width('100%')
            .backgroundColor('#f9f9f9')
            .borderRadius(16)
            .onClick(() => {
              this.switchToTab(idx)
            })
          }
        }, (tab: TabModel) => tab.id)
      }
      .height('70%')
      .width('100%')

      Button() {
        Row() {
          Image($r('app.media.add_icon'))
            .width(20)
            .height(20)
          Text('新建标签页')
            .fontSize(16)
            .margin({ left: 8 })
        }
      }
      .width('90%')
      .height(44)
      .backgroundColor('#45A5FF')
      .borderRadius(22)
      .margin({ top: 16, bottom: 20 })
      .onClick(() => {
        this.newTab()
      })
    }
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius({ topLeft: 20, topRight: 20 })
  }
}