// entry/src/main/ets/common/bean/ArticleContent.ets

export default class ArticleContent {
  title: string = '';
  paragraphs: string[] = [];
  confidence: number = 0;
  available: boolean = false;
  unsupportedReason: string = '';
  paragraphCount: number = 0;
  url: string = '';
  totalLength: number = 0;

  // 构造函数重载：支持无参或传 5 个参数
  constructor();
  constructor(title: string, paragraphs: string[], confidence: number, available: boolean, unsupportedReason: string);
  constructor(title?: string, paragraphs?: string[], confidence?: number, available?: boolean, unsupportedReason?: string) {
    if (title !== undefined) {
      this.title = title;
    }
    if (paragraphs !== undefined) {
      this.paragraphs = paragraphs;
      this.paragraphCount = paragraphs.length;
    }
    if (confidence !== undefined) {
      this.confidence = confidence;
    }
    if (available !== undefined) {
      this.available = available;
    }
    if (unsupportedReason !== undefined) {
      this.unsupportedReason = unsupportedReason;
    }
    // url 和 totalLength 由 ReaderExtractionService 在无参构造后手动赋值
  }
}