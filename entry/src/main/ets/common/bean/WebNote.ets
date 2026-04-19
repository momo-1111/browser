export default class WebNote {
  id: number = 0
  url: string
  title: string
  content: string
  sourceText: string
  sourceType: string
  timestamp: number

  constructor(
    url: string,
    title: string,
    content: string,
    sourceText: string = '',
    sourceType: string = 'manual',
    timestamp: number = Date.now()
  ) {
    this.url = url
    this.title = title
    this.content = content
    this.sourceText = sourceText
    this.sourceType = sourceType
    this.timestamp = timestamp
  }

  setId(id: number) {
    this.id = id
  }
}
