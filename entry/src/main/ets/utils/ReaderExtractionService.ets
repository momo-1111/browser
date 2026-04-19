import ArticleContent from '../common/bean/ArticleContent'

class ReaderExtractionService {
  extractFromHtml(rawHtml: string, url: string, fallbackTitle: string): ArticleContent {
    const normalizedHtml = this.normalizeHtml(rawHtml)

    if (!normalizedHtml || normalizedHtml.trim().length === 0) {
      return this.buildArticleContent(url, fallbackTitle, [], 0, false,
        '页面返回为空，可能被站点脚本限制或尚未完成渲染')
    }

    const title = this.extractTitle(normalizedHtml, fallbackTitle)
    const contentScope = this.pickPrimaryScope(normalizedHtml)
    const paragraphs = this.extractParagraphs(contentScope)
    const confidence = this.calculateConfidence(paragraphs)
    const totalLength = this.totalTextLength(paragraphs)
    const encyclopediaHint = this.isEncyclopediaUrl(url)
    const available = encyclopediaHint ?
      ((paragraphs.length >= 1 && totalLength >= 50) || (paragraphs.length >= 2 && confidence >= 0.2)) :
      ((paragraphs.length >= 2 && totalLength >= 100) || (paragraphs.length >= 3 && confidence >= 0.3))

    const unsupportedReason = available ? '' : this.buildUnsupportedReason(paragraphs.length, totalLength, confidence,
      encyclopediaHint)

    return this.buildArticleContent(url, title, paragraphs, confidence, available, unsupportedReason)
  }

  extractFromRenderedText(rawText: string, url: string, fallbackTitle: string): ArticleContent {
    const normalized = this.normalizePlainText(rawText)
    const encyclopediaHint = this.isEncyclopediaUrl(url)

    if (!normalized || normalized.length < 30) {
      return this.buildArticleContent(url, fallbackTitle, [], 0, false,
        '页面可见文本过少，可能仍在异步加载或正文被脚本保护')
    }

    const paragraphs = this.extractFromPlainText(normalized)
    const confidence = this.calculateConfidence(paragraphs)
    const totalLength = this.totalTextLength(paragraphs)
    const available = encyclopediaHint ?
      ((paragraphs.length >= 1 && totalLength >= 40) || (paragraphs.length >= 2 && confidence >= 0.18)) :
      ((paragraphs.length >= 2 && totalLength >= 80) || (paragraphs.length >= 3 && confidence >= 0.25))

    const unsupportedReason = available ? '' : this.buildUnsupportedReason(paragraphs.length, totalLength, confidence,
      encyclopediaHint)

    return this.buildArticleContent(url, fallbackTitle, paragraphs, confidence, available, unsupportedReason)
  }

  private buildArticleContent(url: string, title: string, paragraphs: string[], confidence: number,
    available: boolean, unsupportedReason: string): ArticleContent {
    const article = new ArticleContent()
    article.url = url
    article.title = title
    article.paragraphs = paragraphs
    article.confidence = confidence
    article.available = available
    article.unsupportedReason = unsupportedReason
    article.paragraphCount = paragraphs.length
    article.totalLength = this.totalTextLength(paragraphs)
    return article
  }

  private buildUnsupportedReason(paragraphCount: number, totalLength: number, confidence: number,
    encyclopediaHint: boolean): string {
    if (paragraphCount === 0) {
      return encyclopediaHint ?
        '百科页面未提取到正文段落，可能是站点模板变更或正文由脚本异步注入' :
        '未提取到正文段落，页面可能是搜索结果/导航页或内容由动态脚本延迟加载'
    }
    if (totalLength < (encyclopediaHint ? 50 : 100)) {
      return encyclopediaHint ?
        `正文总字数偏少(${totalLength})，百科页面阈值需至少 50` :
        `正文总字数偏少(${totalLength})，当前阈值需至少 100`
    }
    if (confidence < (encyclopediaHint ? 0.2 : 0.3)) {
      return encyclopediaHint ?
        `百科页面可读性评分偏低(${confidence.toFixed(2)})，低于 0.20` :
        `内容可读性评分偏低(${confidence.toFixed(2)})，低于 0.30`
    }
    return '页面结构与正文规则匹配度不足'
  }

  private normalizeHtml(input: string): string {
    if (!input) {
      return ''
    }

    return input
      .replace(/\\u003C/gi, '<')
      .replace(/\\u003E/gi, '>')
      .replace(/\\u0026/gi, '&')
      .replace(/\\u0022/gi, '"')
      .replace(/\\u0027/gi, "'")
      .replace(/\\n/g, '\n')
      .replace(/\\r/g, '\r')
      .replace(/\\t/g, '\t')
      
  }

  private extractTitle(html: string, fallbackTitle: string): string {
    const h1Match = html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i)
    if (h1Match && h1Match[1]) {
      const cleaned = this.cleanText(h1Match[1])
      if (cleaned.length > 0) {
        return cleaned
      }
    }

    const titleMatch = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i)
    if (titleMatch && titleMatch[1]) {
      const cleaned = this.cleanText(titleMatch[1])
      if (cleaned.length > 0) {
        return cleaned
      }
    }

    return fallbackTitle
  }

  private pickPrimaryScope(html: string): string {
    // 优先匹配常见内容主容器，适配百科/资讯类页面。
    const contentBlockMatch = html.match(/<(article|main|div|section)[^>]*(content|article|main|markdown|rich|text|wiki|lemma|para)[^>]*>([\s\S]*?)<\/\1>/i)
    const articleMatch = html.match(/<article[^>]*>([\s\S]*?)<\/article>/i)
    const mainMatch = html.match(/<main[^>]*>([\s\S]*?)<\/main>/i)

    let scope = html
    if (contentBlockMatch && contentBlockMatch[3]) {
      scope = contentBlockMatch[3]
    } else if (articleMatch && articleMatch[1]) {
      scope = articleMatch[1]
    } else if (mainMatch && mainMatch[1]) {
      scope = mainMatch[1]
    }

    // 先做粗过滤，降低噪音标签对段落抽取的干扰
    return scope
      .replace(/<script[\s\S]*?<\/script>/gi, ' ')
      .replace(/<style[\s\S]*?<\/style>/gi, ' ')
      .replace(/<nav[\s\S]*?<\/nav>/gi, ' ')
      .replace(/<header[\s\S]*?<\/header>/gi, ' ')
      .replace(/<footer[\s\S]*?<\/footer>/gi, ' ')
      .replace(/<aside[\s\S]*?<\/aside>/gi, ' ')
  }

  private extractParagraphs(scopeHtml: string): string[] {
    const targeted = this.extractTargetedBlocks(scopeHtml)

    const paragraphRegex = /<(p|div|section|li)[^>]*>([\s\S]*?)<\/\1>/gi
    const result: string[] = []
    let match: RegExpExecArray | null

    while ((match = paragraphRegex.exec(scopeHtml)) !== null) {
      const candidateBlock = match[0]
      const tag = (match[1] ?? '').toLowerCase()
      const body = match[2] ?? ''
      const looksLikeContent = this.isLikelyContentBlock(candidateBlock, tag)
      if (!looksLikeContent && tag !== 'p') {
        continue
      }

      const cleaned = this.cleanText(body)
      if (cleaned.length >= 28 || (cleaned.length >= 18 && this.hasReadablePunctuation(cleaned))) {
        result.push(cleaned)
      }
    }

    for (const item of targeted) {
      result.push(item)
    }

    const deduped = this.dedupeParagraphs(result)

    if (deduped.length >= 2) {
      return deduped.slice(0, 120)
    }

    // 兜底：保留换行再切分纯文本
    const plainText = this.cleanTextWithBreaks(scopeHtml)
    const blocks = plainText
      .split(/\n{2,}|[。！？；]\s*/)
      .map(item => item.trim())
      .filter(item => item.length >= 20)

    return this.dedupeParagraphs(blocks).slice(0, 120)
  }

  private extractTargetedBlocks(scopeHtml: string): string[] {
    const result: string[] = []
    const targetRegex = /<(p|div|section|li)[^>]*(class|id)=["'][^"']*(para|lemma|summary|content|article|text|main|rich|detail|introduction)[^"']*["'][^>]*>([\s\S]*?)<\/\1>/gi
    let match: RegExpExecArray | null

    while ((match = targetRegex.exec(scopeHtml)) !== null) {
      const block = match[4] ?? ''
      const cleaned = this.cleanText(block)
      if (cleaned.length >= 12) {
        result.push(cleaned)
      }
    }

    return this.dedupeParagraphs(result)
  }

  private calculateConfidence(paragraphs: string[]): number {
    if (paragraphs.length === 0) {
      return 0
    }

    const totalLength = this.totalTextLength(paragraphs)
    const avgLength = totalLength / paragraphs.length
    const punctuationScore = this.punctuationScore(paragraphs)

    const countScore = Math.min(paragraphs.length / 8, 1)
    const lengthScore = Math.min(avgLength / 160, 1)

    return Number((countScore * 0.45 + lengthScore * 0.4 + punctuationScore * 0.15).toFixed(2))
  }

  private cleanText(input: string): string {
    return input
      .replace(/<[^>]+>/g, ' ')
      .replace(/&nbsp;/gi, ' ')
      .replace(/&amp;/gi, '&')
      .replace(/&lt;/gi, '<')
      .replace(/&gt;/gi, '>')
      .replace(/&quot;/gi, '"')
      .replace(/&#39;/gi, "'")
      .replace(/\s+/g, ' ')
      .trim()
  }

  private cleanTextWithBreaks(input: string): string {
    return input
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<\/(p|div|section|li|h1|h2|h3|article|main)>/gi, '\n')
      .replace(/<script[\s\S]*?<\/script>/gi, ' ')
      .replace(/<style[\s\S]*?<\/style>/gi, ' ')
      .replace(/<[^>]+>/g, ' ')
      .replace(/&nbsp;/gi, ' ')
      .replace(/&amp;/gi, '&')
      .replace(/&lt;/gi, '<')
      .replace(/&gt;/gi, '>')
      .replace(/&quot;/gi, '"')
      .replace(/&#39;/gi, "'")
      .replace(/[ \t\f\v]+/g, ' ')
      .replace(/\n\s+/g, '\n')
      .replace(/\n{3,}/g, '\n\n')
      .trim()
  }

  private normalizePlainText(input: string): string {
    if (!input) {
      return ''
    }

    return input
      .replace(/\r/g, '\n')
      .replace(/[ \t\f\v]+/g, ' ')
      .replace(/\n\s+/g, '\n')
      .replace(/\n{3,}/g, '\n\n')
      .trim()
  }

  private extractFromPlainText(text: string): string[] {
    const blocks = text
      .split(/\n{2,}|[。！？；]\s*/)
      .map(item => item.trim())
      .filter(item => item.length >= 12)

    return this.dedupeParagraphs(blocks).slice(0, 160)
  }

  private isLikelyContentBlock(blockHtml: string, tag: string): boolean {
    if (tag === 'p') {
      return true
    }
    return /(para|paragraph|content|article|text|lemma|summary|main|rich|detail)/i.test(blockHtml)
  }

  private hasReadablePunctuation(text: string): boolean {
    return /[，。！？；：,.!?;:]/.test(text)
  }

  private dedupeParagraphs(paragraphs: string[]): string[] {
    const deduped: string[] = []
    const seen = new Set<string>()

    for (const item of paragraphs) {
      const normalized = item.replace(/\s+/g, ' ').trim()
      if (normalized.length === 0 || seen.has(normalized)) {
        continue
      }
      seen.add(normalized)
      deduped.push(normalized)
    }

    return deduped
  }

  private totalTextLength(paragraphs: string[]): number {
    return paragraphs.reduce((sum, item) => sum + item.length, 0)
  }

  private punctuationScore(paragraphs: string[]): number {
    if (paragraphs.length === 0) {
      return 0
    }

    let matchedCount = 0
    for (const paragraph of paragraphs) {
      if (this.hasReadablePunctuation(paragraph)) {
        matchedCount++
      }
    }

    return matchedCount / paragraphs.length
  }

  private isEncyclopediaUrl(url: string): boolean {
    return /(baike|wiki|encyclopedia|lemma)/i.test(url)
  }
}

export default new ReaderExtractionService()
