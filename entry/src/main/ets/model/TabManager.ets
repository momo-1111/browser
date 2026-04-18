// model/TabManager.ets
import { TabModel } from './TabModel'

export class TabManager {
  private tabs: TabModel[] = []
  private activeIndex: number = 0

  getTabs(): TabModel[] {
    return this.tabs
  }

  getActiveIndex(): number {
    return this.activeIndex
  }

  getCurrentTab(): TabModel | null {
    return this.tabs[this.activeIndex] || null
  }

  newTab(url: string = 'about:blank', title?: string): TabModel {
    const newTab = new TabModel(url, title)
    this.tabs.push(newTab)
    this.activeIndex = this.tabs.length - 1
    return newTab
  }

  switchTo(index: number): boolean {
    if (index >= 0 && index < this.tabs.length) {
      this.activeIndex = index
      return true
    }
    return false
  }

  closeTab(index: number): boolean {
    if (this.tabs.length === 1) {
      // 至少保留一个标签页，新建一个空白页
      this.tabs = [new TabModel('about:blank', '新标签页')]
      this.activeIndex = 0
      return true
    }
    this.tabs.splice(index, 1)
    if (this.activeIndex >= this.tabs.length) {
      this.activeIndex = this.tabs.length - 1
    } else if (index < this.activeIndex) {
      this.activeIndex--
    }
    return true
  }

  updateCurrentTabInfo(url: string, title: string) {
    const current = this.getCurrentTab()
    if (current) {
      current.url = url
      current.title = title
    }
  }
}