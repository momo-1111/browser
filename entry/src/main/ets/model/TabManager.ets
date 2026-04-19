// model/TabManager.ets
import { TabModel } from './TabModel'

export class TabManager {
  private tabs: TabModel[] = [new TabModel('about:blank', '新标签页')]
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
    this.syncNavigationState(newTab)
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
    this.replaceCurrentHistory(url, title)
  }

  pushCurrentHistory(url: string, title?: string) {
    const current = this.getCurrentTab()
    if (!current || !url || url === 'about:blank') return
    if (current.historyIndex >= 0 && current.historyStack[current.historyIndex] === url) {
      current.url = url
      if (title !== undefined) current.title = title
      this.syncNavigationState(current)
      return
    }
    if (current.historyIndex < current.historyStack.length - 1) {
      current.historyStack = current.historyStack.slice(0, current.historyIndex + 1)
    }
    current.historyStack.push(url)
    current.historyIndex = current.historyStack.length - 1
    current.url = url
    if (title !== undefined) current.title = title
    this.syncNavigationState(current)
  }

  replaceCurrentHistory(url: string, title?: string) {
    const current = this.getCurrentTab()
    if (!current || !url || url === 'about:blank') return
    if (current.historyIndex < 0) {
      current.historyStack = [url]
      current.historyIndex = 0
    } else {
      current.historyStack[current.historyIndex] = url
    }
    current.url = url
    if (title !== undefined && title.length > 0) current.title = title
    this.syncNavigationState(current)
  }

  goBack(): string | null {
    const current = this.getCurrentTab()
    if (!current || current.historyIndex <= 0) return null
    current.historyIndex--
    current.url = current.historyStack[current.historyIndex]
    this.syncNavigationState(current)
    return current.url
  }

  goForward(): string | null {
    const current = this.getCurrentTab()
    if (!current || current.historyIndex >= current.historyStack.length - 1) return null
    current.historyIndex++
    current.url = current.historyStack[current.historyIndex]
    this.syncNavigationState(current)
    return current.url
  }

  private syncNavigationState(tab: TabModel) {
    tab.canGoBack = tab.historyIndex > 0
    tab.canGoForward = tab.historyIndex >= 0 && tab.historyIndex < tab.historyStack.length - 1
  }
}
