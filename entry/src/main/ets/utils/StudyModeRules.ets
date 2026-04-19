import CommonConstants from '../common/constants/CommonConstants'
import DomainUtils from './DomainUtils'

class StudyModeRules {
  parseWhitelist(json: string): string[] {
    if (json.trim().length === 0) {
      return [...CommonConstants.DEFAULT_STUDY_WHITELIST]
    }

    try {
      const parsed = JSON.parse(json) as string[]
      if (!Array.isArray(parsed)) {
        return [...CommonConstants.DEFAULT_STUDY_WHITELIST]
      }
      return DomainUtils.normalizeRules(parsed)
    } catch (error) {
      console.error(`解析学习模式白名单失败: ${error}`)
      return [...CommonConstants.DEFAULT_STUDY_WHITELIST]
    }
  }

  stringifyWhitelist(whitelist: string[]): string {
    return JSON.stringify(DomainUtils.normalizeRules(whitelist))
  }

  /**
   * 判断主框架请求是否允许访问
   * 规则：用户白名单命中 OR 搜索引擎主站命中 → 放行
   */
  isMainFrameAllowed(url: string, whitelist: string[]): boolean {
    const host = DomainUtils.tryGetHost(url)
    if (host === null) {
      return false
    }

    // 1. 用户白名单命中
    if (DomainUtils.matchHost(host, whitelist)) {
      return true
    }

    // 2. 搜索引擎主站命中（不需要用户手动添加）
    if (DomainUtils.isSearchEngineHost(host)) {
      return true
    }

    return false
  }

  /**
   * 判断子资源请求是否允许加载
   * 按顶层页面上下文做最小放行：
   *   - 白名单站点 → 同域/子域 + 附属资源白名单
   *   - 搜索引擎 → 同域/子域 + 搜索引擎辅助资源白名单
   *   - 其余 → 拦截
   */
  isSubResourceAllowed(url: string, topLevelUrl: string, whitelist: string[]): boolean {
    const host = DomainUtils.tryGetHost(url)
    const topLevelHost = DomainUtils.tryGetHost(topLevelUrl)
    if (host === null || topLevelHost === null) {
      return false
    }

    // 1. 同域或子域 → 放行
    if (DomainUtils.isSameDomainOrSubdomain(host, topLevelHost)) {
      return true
    }

    // 2. 顶层页面属于白名单站点 → 查附属资源白名单
    const matchedRule = DomainUtils.findMatchedRule(topLevelHost, whitelist)
    if (matchedRule !== null) {
      // 查该站点的附属资源映射（可能 key 是 www.xxx.org 而规则是 xxx.org，两种都查）
      const auxRules1 = CommonConstants.WHITELIST_SITE_SUBRESOURCE_ALLOWLIST[topLevelHost] ?? []
      const auxRules2 = CommonConstants.WHITELIST_SITE_SUBRESOURCE_ALLOWLIST[matchedRule] ?? []
      const auxRules = auxRules1.length > 0 ? auxRules1 : auxRules2
      if (DomainUtils.matchAnyRule(host, auxRules)) {
        return true
      }
    }

    // 3. 顶层页面属于搜索引擎 → 查搜索引擎辅助资源白名单
    for (const engineHost of DomainUtils.getSearchEngineHosts()) {
      if (DomainUtils.isUrlOfSearchEngine(topLevelUrl, engineHost)) {
        const engineRules = CommonConstants.SEARCH_ENGINE_SUBRESOURCE_ALLOWLIST[engineHost] ?? []
        if (DomainUtils.matchAnyRule(host, engineRules)) {
          return true
        }
        // 也查搜索引擎的顶级域（如 "www.google.com" 和 "google.com"）
        const parentEngineHost = engineHost.startsWith("www.") ? engineHost.slice(4) : engineHost
        const engineRules2 = CommonConstants.SEARCH_ENGINE_SUBRESOURCE_ALLOWLIST[parentEngineHost] ?? []
        if (DomainUtils.matchAnyRule(host, engineRules2)) {
          return true
        }
      }
    }

    return false
  }
}

export default new StudyModeRules()
