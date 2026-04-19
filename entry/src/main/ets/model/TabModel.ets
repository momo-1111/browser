export class TabModel {
  id: string
  title: string
  url: string
  historyStack: string[] = []
  historyIndex: number = -1
  canGoBack: boolean = false
  canGoForward: boolean = false

  constructor(url: string, title?: string) {
    this.id = Date.now().toString() + Math.random()
    this.url = url
    this.title = title || '新标签页'
    if (url !== 'about:blank') {
      this.historyStack = [url]
      this.historyIndex = 0
    }
  }
}
