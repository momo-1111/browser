import StudyModeRules from './StudyModeRules'
import DomainUtils from './DomainUtils'

export interface PolicyConfig {
  studyModeEnabled: boolean
  whitelist: string[]
  currentSearchEngineHost: string
}

export interface InterceptDecision {
  action: "allow" | "block"
  reason: "allow" | "study_mode" | "invalid_url"
  message: string
}

class RequestPolicy {
  evaluateNavigation(url: string, config: PolicyConfig): InterceptDecision {
    if (url.trim().length === 0) {
      return this.block("invalid_url", "请输入有效的网址或搜索内容")
    }

    if (!config.studyModeEnabled) {
      return this.allow()
    }

    // 搜索引擎主站放行（用户输入搜索词时不应被拦截）
    if (config.currentSearchEngineHost.length > 0 &&
        DomainUtils.isUrlOfSearchEngine(url, config.currentSearchEngineHost)) {
      return this.allow()
    }

    if (!StudyModeRules.isMainFrameAllowed(url, config.whitelist)) {
      return this.block("study_mode", "当前为学习模式，该站点不在白名单内")
    }

    return this.allow()
  }

  evaluateRequest(url: string, topLevelUrl: string, config: PolicyConfig, isMainFrame: boolean): InterceptDecision {
    if (!config.studyModeEnabled) {
      return this.allow()
    }

    if (url.trim().length === 0) {
      return this.block("invalid_url", "请求地址无效")
    }

    if (isMainFrame) {
      // 搜索引擎主站放行
      if (config.currentSearchEngineHost.length > 0 &&
          DomainUtils.isUrlOfSearchEngine(url, config.currentSearchEngineHost)) {
        return this.allow()
      }
      if (!StudyModeRules.isMainFrameAllowed(url, config.whitelist)) {
        return this.block("study_mode", "当前为学习模式，该站点不在白名单内")
      }
      return this.allow()
    }

    if (!StudyModeRules.isSubResourceAllowed(url, topLevelUrl, config.whitelist)) {
      return this.block("study_mode", "学习模式已拦截第三方资源")
    }

    return this.allow()
  }

  private allow(): InterceptDecision {
    return {
      action: "allow",
      reason: "allow",
      message: ""
    }
  }

  private block(reason: "study_mode" | "invalid_url", message: string): InterceptDecision {
    return {
      action: "block",
      reason,
      message
    }
  }
}

export default new RequestPolicy()
