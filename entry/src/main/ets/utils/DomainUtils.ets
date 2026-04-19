import CommonConstants from '../common/constants/CommonConstants'

class DomainUtils {
  normalizeUrl(input: string): string {
    return input.trim()
  }

  resolveInputToUrl(input: string, searchPrefix: string): string {
    const value = this.normalizeUrl(input)
    if (value.length === 0) {
      return ""
    }

    if (this.hasHttpScheme(value)) {
      return value
    }

    if (this.isLikelyDomain(value)) {
      return `https://${value}`
    }

    return `${searchPrefix}${encodeURIComponent(value)}`
  }

  normalizeDomainRule(input: string): string {
    const value = this.normalizeUrl(input).toLowerCase()
    if (value.length === 0) {
      return ""
    }

    let normalized = value
    if (this.hasHttpScheme(normalized)) {
      normalized = normalized.replace(/^https?:\/\//i, "")
    }

    normalized = normalized.split("/")[0]
    normalized = normalized.split("?")[0]
    normalized = normalized.split("#")[0]
    normalized = normalized.split("@").pop() ?? ""
    normalized = normalized.split(":")[0]

    while (normalized.startsWith(".")) {
      normalized = normalized.slice(1)
    }

    return normalized.trim()
  }

  normalizeRules(rules: string[]): string[] {
    const normalizedRules: string[] = []
    for (let rule of rules) {
      const normalized = this.normalizeDomainRule(rule)
      if (normalized.length > 0 && normalizedRules.indexOf(normalized) === -1) {
        normalizedRules.push(normalized)
      }
    }
    return normalizedRules
  }

  tryGetHost(url: string): string | null {
    const value = this.normalizeUrl(url)
    if (value.length === 0) {
      return null
    }

    if (this.hasHttpScheme(value)) {
      return this.normalizeDomainRule(value)
    }

    if (this.isLikelyDomain(value)) {
      return this.normalizeDomainRule(value)
    }

    return null
  }

  isSameDomainOrSubdomain(host: string, rule: string): boolean {
    const normalizedHost = this.normalizeDomainRule(host)
    const normalizedRule = this.normalizeDomainRule(rule)

    if (normalizedHost.length === 0 || normalizedRule.length === 0) {
      return false
    }

    return normalizedHost === normalizedRule || normalizedHost.endsWith(`.${normalizedRule}`)
  }

  matchHost(host: string, rules: string[]): boolean {
    return this.findMatchedRule(host, rules) !== null
  }

  findMatchedRule(host: string, rules: string[]): string | null {
    const normalizedHost = this.normalizeDomainRule(host)
    if (normalizedHost.length === 0) {
      return null
    }

    for (let rule of rules) {
      if (this.isSameDomainOrSubdomain(normalizedHost, rule)) {
        return this.normalizeDomainRule(rule)
      }
    }

    return null
  }

  private hasHttpScheme(value: string): boolean {
    return value.startsWith("http://") || value.startsWith("https://")
  }

  private isLikelyDomain(value: string): boolean {
    if (value.includes(" ")) {
      return false
    }

    const candidate = this.normalizeDomainRule(value)
    return /^[a-z0-9-]+(\.[a-z0-9-]+)+$/i.test(candidate)
  }

  /**
   * 从搜索引擎前缀中提取 host（如 "https://www.google.com/search?q=" → "www.google.com"）
   */
  extractHostFromPrefix(prefix: string): string {
    return this.normalizeDomainRule(prefix)
  }

  /**
   * 判断给定 URL 是否属于指定的搜索引擎
   */
  isUrlOfSearchEngine(url: string, engineHost: string): boolean {
    const host = this.tryGetHost(url)
    if (host === null) return false
    return this.isSameDomainOrSubdomain(host, engineHost) || host === engineHost
  }

  /**
   * 获取所有搜索引擎主框架允许域名
   */
  getSearchEngineHosts(): string[] {
    return CommonConstants.SEARCH_ENGINE_MAINFRAME_ALLOWLIST
  }

  /**
   * 判断 host 是否属于任意搜索引擎主框架域名
   */
  isSearchEngineHost(host: string): boolean {
    return this.matchAnyRule(host, CommonConstants.SEARCH_ENGINE_MAINFRAME_ALLOWLIST)
  }

  /**
   * 批量规则匹配：判断 host 是否命中任意一条规则（精确匹配或后缀子域匹配）
   */
  matchAnyRule(host: string, rules: string[]): boolean {
    const normalizedHost = this.normalizeDomainRule(host)
    if (normalizedHost.length === 0) return false
    for (const rule of rules) {
      if (this.isSameDomainOrSubdomain(normalizedHost, rule)) {
        return true
      }
    }
    return false
  }
}

export default new DomainUtils()
