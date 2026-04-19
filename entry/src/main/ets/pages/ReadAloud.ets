import { router, Prompt } from '@kit.ArkUI'

@Entry
@Component
struct ReadAloud {
  @StorageLink('darkMode') darkMode: boolean = false
  @StorageLink('ttsArticleTitle') articleTitle: string = ''
  @StorageLink('ttsArticleUrl') articleUrl: string = ''
  @StorageLink('ttsArticleHtml') articleHtml: string = ''
  @StorageLink('ttsArticleParagraphs') paragraphsRaw: string = '[]'
  @StorageLink('ttsCurrentIndex') currentIndex: number = 0
  @StorageLink('ttsAutoPlay') autoPlay: boolean = true
  @StorageLink('ttsPlaySpeed') playSpeed: number = 1
  @StorageLink('ttsDebugReason') debugReason: string = ''

  @State speechUnits: string[] = []
  @State sourceParagraphs: string[] = []
  @State isPlaying: boolean = false
  @State finished: boolean = false

  private playTimer: number = -1

  aboutToAppear() {
    this.prepareSpeechUnits()
    if (this.autoPlay && this.speechUnits.length > 0) {
      this.startPlay()
    }
  }

  aboutToDisappear() {
    this.clearTimer()
  }

  onBackPress(): boolean {
    this.clearTimer()
    return false
  }

  private prepareSpeechUnits() {
    this.speechUnits = []
    this.sourceParagraphs = []
    this.debugReason = ''
    this.currentIndex = Math.max(this.currentIndex, 0)

    let rawParagraphCount = 0
    let filteredCount = 0

    // 主策略：与阅读器模式保持一致，直接消费阅读器已提取的段落缓存。
    try {
      const parsed: string[] = this.parseParagraphCache(this.paragraphsRaw)
      for (const item of parsed) {
        const cleanedParagraph = this.cleanTextForSpeech(item)
        if (cleanedParagraph.length > 0) {
          this.sourceParagraphs.push(cleanedParagraph)
          rawParagraphCount++

          const sentenceUnits = this.splitIntoSpeechUnits(cleanedParagraph)
          for (const sentence of sentenceUnits) {
            if (this.shouldSkipSentence(sentence)) {
              filteredCount++
              continue
            }
            this.speechUnits.push(sentence)
          }
        }
      }
    } catch (error) {
      console.error('解析朗读段落异常：' + error)
      this.speechUnits = []
      this.debugReason = '段落数据解析失败，正文数据格式不是合法 JSON'
    }

    // 备用策略：直接从原始 HTML 提取有效标题与正文，再进行朗读清洗。
    // const extracted = ReaderExtractionService.extractFromHtml(this.articleHtml, this.articleUrl, this.articleTitle)
    // if (extracted.title.length > 0) {
    //   this.articleTitle = extracted.title
    // }
    // for (const paragraph of extracted.paragraphs) {
    //   const cleanedParagraph = this.cleanTextForSpeech(paragraph)
    //   if (cleanedParagraph.length === 0) {
    //     continue
    //   }
    //   this.sourceParagraphs.push(cleanedParagraph)
    //   rawParagraphCount++
    //   const sentenceUnits = this.splitIntoSpeechUnits(cleanedParagraph)
    //   for (const sentence of sentenceUnits) {
    //     if (this.shouldSkipSentence(sentence)) {
    //       filteredCount++
    //       continue
    //     }
    //     this.speechUnits.push(sentence)
    //   }
    // }

    this.speechUnits = this.dedupeUnits(this.speechUnits).slice(0, 240)

    if (this.speechUnits.length === 0) {
      if (this.debugReason.length === 0) {
        this.debugReason = `朗读文本过滤后为空：阅读器未产出可读段落；原始段落 ${rawParagraphCount}，过滤 ${filteredCount}`
      }
      Prompt.showToast({ message: `朗读失败：${this.debugReason}` })
      return
    }

    if (filteredCount > 0) {
      this.debugReason = `已过滤 ${filteredCount} 条疑似导航/符号/代码内容`
    }

    if (this.currentIndex >= this.speechUnits.length) {
      this.currentIndex = this.speechUnits.length - 1
    }
  }

  private parseParagraphCache(raw: string): string[] {
    const parsedObj: Object = JSON.parse(raw) as Object
    if (!Array.isArray(parsedObj)) {
      return []
    }

    const output: string[] = []
    const parsedArray: Object[] = parsedObj as Object[]
    for (const item of parsedArray) {
      if (typeof item === 'string') {
        output.push(item)
      }
    }

    return output
  }

  private cleanTextForSpeech(input: string): string {
    return input
      .replace(/<[^>]+>/g, ' ')
      .replace(/\\u003C/gi, '<')
      .replace(/\\u003E/gi, '>')
      .replace(/\\u0026/gi, '&')
      .replace(/\\u0022/gi, '"')
      .replace(/\\u0027/gi, "'")
      .replace(/&nbsp;/gi, ' ')
      .replace(/&amp;/gi, '&')
      .replace(/&lt;/gi, '<')
      .replace(/&gt;/gi, '>')
      .replace(/&quot;/gi, '"')
      .replace(/&#39;/gi, "'")
      .replace(/\s+/g, ' ')
      .trim()
  }

  private splitIntoSpeechUnits(paragraph: string): string[] {
    const blocks = paragraph
      .split(/[。！？；!?;]|\n{2,}/)
      .map(item => item.trim())
      .filter(item => item.length > 0)

    const units: string[] = []
    for (const block of blocks) {
      if (block.length <= 80) {
        units.push(block)
        continue
      }

      // 对超长句再按逗号切分，减少断句生硬感。
      const subUnits = block
        .split(/[，,]/)
        .map(item => item.trim())
        .filter(item => item.length >= 6)

      if (subUnits.length > 0) {
        for (const sub of subUnits) {
          units.push(sub)
        }
      } else {
        units.push(block)
      }
    }

    return units
  }

  private shouldSkipSentence(text: string): boolean {
    if (text.length < 6) {
      return true
    }

    const lower = text.toLowerCase()
    if (/(function\s*\(|=>|\{\s*\}|<\/?[a-z]|console\.|var\s+|let\s+|const\s+|http[s]?:\/\/)/i.test(text)) {
      return true
    }

    if (/(首页|上一页|下一页|返回顶部|目录|导航|菜单|登录|注册|免责声明|版权|隐私政策|cookie|APP下载|打开APP|分享|编辑|收藏|阅读原文)/.test(text)) {
      return true
    }

    if (/[\u0000-\u001F]/.test(text)) {
      return true
    }

    if (/\u003C|\u003E|\\n|\\t|\\r/.test(text)) {
      return true
    }

    const symbolChars = text.replace(/[\u4e00-\u9fa5a-zA-Z0-9]/g, '')
    const symbolRatio = symbolChars.length / text.length
    if (symbolRatio > 0.45) {
      return true
    }

    const englishRatio = lower.replace(/[^a-z]/g, '').length / text.length
    if (englishRatio > 0.9 && text.length < 18) {
      return true
    }

    return false
  }

  private dedupeUnits(units: string[]): string[] {
    const out: string[] = []
    const seen = new Set<string>()

    for (const unit of units) {
      const normalized = unit.replace(/\s+/g, ' ').trim()
      if (normalized.length === 0 || seen.has(normalized)) {
        continue
      }
      seen.add(normalized)
      out.push(normalized)
    }

    return out
  }

  private clearTimer() {
    if (this.playTimer > 0) {
      clearTimeout(this.playTimer)
      this.playTimer = -1
    }
  }

  private nextDurationMs(): number {
    const text = this.speechUnits[this.currentIndex] ?? ''
    const speedFactor = Math.max(this.playSpeed, 0.5)
    const base = Math.max(1400, Math.min(7000, Math.floor(text.length * 55)))
    return Math.floor(base / speedFactor)
  }

  private scheduleNext() {
    this.clearTimer()

    if (!this.isPlaying || this.speechUnits.length === 0) {
      return
    }

    const duration = this.nextDurationMs()
    this.playTimer = setTimeout(() => {
      if (!this.isPlaying) {
        return
      }

      if (this.currentIndex >= this.speechUnits.length - 1) {
        this.isPlaying = false
        this.finished = true
        this.playTimer = -1
        Prompt.showToast({ message: '朗读完成' })
        return
      }

      this.currentIndex = this.currentIndex + 1
      this.scheduleNext()
    }, duration)
  }

  private startPlay() {
    if (this.speechUnits.length === 0) {
      Prompt.showToast({ message: `暂无可朗读内容：${this.debugReason || '文本清洗后为空'}` })
      return
    }

    if (this.finished && this.currentIndex >= this.speechUnits.length - 1) {
      this.currentIndex = 0
      this.finished = false
    }

    this.isPlaying = true
    this.finished = false
    this.scheduleNext()
  }

  private pausePlay() {
    this.isPlaying = false
    this.clearTimer()
  }

  private stopPlay() {
    this.isPlaying = false
    this.finished = false
    this.currentIndex = 0
    this.clearTimer()
  }

  private prevParagraph() {
    if (this.speechUnits.length === 0) {
      return
    }

    this.currentIndex = Math.max(this.currentIndex - 1, 0)
    this.finished = false

    if (this.isPlaying) {
      this.scheduleNext()
    }
  }

  private nextParagraph() {
    if (this.speechUnits.length === 0) {
      return
    }

    this.currentIndex = Math.min(this.currentIndex + 1, this.speechUnits.length - 1)
    this.finished = false

    if (this.isPlaying) {
      this.scheduleNext()
    }
  }

  private setPlaySpeed(value: number) {
    this.playSpeed = value
    if (this.isPlaying) {
      this.scheduleNext()
    }
  }

  private progressText(): string {
    if (this.speechUnits.length === 0) {
      return '0/0'
    }
    return `${this.currentIndex + 1}/${this.speechUnits.length}`
  }

  @Builder HeaderBuilder() {
    Column({ space: 6 }) {
      Text('朗读页面')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(!this.darkMode ? Color.Black : Color.White)

      Text(this.articleTitle.length > 0 ? this.articleTitle : '未命名正文')
        .fontSize(14)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .fontColor(!this.darkMode ? '#404040' : '#D9D9D9')

      Text(`进度 ${this.progressText()}  语速 x${this.playSpeed.toFixed(1)}`)
        .fontSize(12)
        .fontColor('#45A5FF')

      if (this.debugReason.length > 0) {
        Text(`调试信息：${this.debugReason}`)
          .fontSize(11)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor('#E67E22')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 14, right: 14, top: 14, bottom: 8 })
  }

  @Builder ControlsBuilder() {
    Row({ space: 8 }) {
      Button('上一段')
        .type(ButtonType.Capsule)
        .height(34)
        .fontSize(12)
        .onClick(() => {
          this.prevParagraph()
        })

      Button(this.isPlaying ? '暂停' : '播放')
        .type(ButtonType.Capsule)
        .height(34)
        .fontSize(12)
        .onClick(() => {
          if (this.isPlaying) {
            this.pausePlay()
          } else {
            this.startPlay()
          }
        })

      Button('下一段')
        .type(ButtonType.Capsule)
        .height(34)
        .fontSize(12)
        .onClick(() => {
          this.nextParagraph()
        })

      Button('停止')
        .type(ButtonType.Capsule)
        .height(34)
        .fontSize(12)
        .onClick(() => {
          this.stopPlay()
        })
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .padding({ left: 14, right: 14, top: 4, bottom: 6 })

    Row({ space: 8 }) {
      Text('语速')
        .fontSize(12)
        .fontColor(Color.Gray)

      Button('x0.8')
        .type(ButtonType.Capsule)
        .height(30)
        .fontSize(11)
        .onClick(() => {
          this.setPlaySpeed(0.8)
        })

      Button('x1.0')
        .type(ButtonType.Capsule)
        .height(30)
        .fontSize(11)
        .onClick(() => {
          this.setPlaySpeed(1.0)
        })

      Button('x1.2')
        .type(ButtonType.Capsule)
        .height(30)
        .fontSize(11)
        .onClick(() => {
          this.setPlaySpeed(1.2)
        })

      Button('x1.5')
        .type(ButtonType.Capsule)
        .height(30)
        .fontSize(11)
        .onClick(() => {
          this.setPlaySpeed(1.5)
        })
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .padding({ left: 14, right: 14, bottom: 8 })
  }

  @Builder ParagraphBuilder(paragraph: string, index: number) {
    Column() {
      Text(paragraph)
        .width('100%')
        .fontSize(16)
        .lineHeight(30)
        .textAlign(TextAlign.Start)
        .fontColor(index === this.currentIndex ? '#0D47A1' : (!this.darkMode ? '#1C1C1C' : '#ECECEC'))
        .fontWeight(index === this.currentIndex ? FontWeight.Medium : FontWeight.Regular)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor(index === this.currentIndex ? '#E8F2FF' : '#00000000')
    .borderRadius(8)
  }

  build() {
    Column() {
      this.HeaderBuilder()
      this.ControlsBuilder()

      Scroll() {
        Column({ space: 8 }) {
          ForEach(this.speechUnits, (paragraph: string, index: number) => {
            this.ParagraphBuilder(paragraph, index)
          })
        }
        .width('100%')
        .padding({ bottom: 12 })
      }
      .scrollable(ScrollDirection.Vertical)
      .layoutWeight(1)

      Row({ space: 10 }) {
        Button('返回网页')
          .type(ButtonType.Capsule)
          .height(36)
          .fontSize(13)
          .onClick(() => {
            this.clearTimer()
            router.back()
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .padding({ left: 14, right: 14, top: 8, bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(!this.darkMode ? Color.White : '#121212')
  }
}
