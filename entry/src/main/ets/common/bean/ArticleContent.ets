export default class ArticleContent {
  url: string = ''
  title: string = ''
  paragraphs: string[] = []
  confidence: number = 0
  available: boolean = false
  unsupportedReason: string = ''
  paragraphCount: number = 0
  totalLength: number = 0

  constructor(init?: Partial<ArticleContent>) {
    if (!init) {
      return
    }
    this.url = init.url ?? ''
    this.title = init.title ?? ''
    this.paragraphs = init.paragraphs ?? []
    this.confidence = init.confidence ?? 0
    this.available = init.available ?? false
    this.unsupportedReason = init.unsupportedReason ?? ''
    this.paragraphCount = init.paragraphCount ?? 0
    this.totalLength = init.totalLength ?? 0
  }
}
