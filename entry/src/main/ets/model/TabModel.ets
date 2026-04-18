// model/TabModel.ets
export class TabModel {
  id: string
  title: string
  url: string

  constructor(url: string, title?: string) {
    this.id = Date.now().toString() + Math.random()
    this.url = url
    this.title = title || '新标签页'
  }
}