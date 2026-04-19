import relationalStore from '@ohos.data.relationalStore'
import History from '../bean/History'

export interface STORE_CONFIG {
  name:string,
  securityLevel:relationalStore.SecurityLevel
}

export interface HISTORY_TABLE {
  tableName:string,
  sqlCreate:string,
  columns:string[]
}

export interface SEARCH_ENGINE {
  engine:string,
  prefix:string
}

export interface HistoryGroup {
  date: string
  histories: History[]
}

class CommonConstants {
  APP_NAME = "小狐狸浏览器"

  VERSION = "v1.0"

  KEY_NAME = "AppStore.db"

  PREFERENCES_NAME = "HistoriesPreference"

  STORE_CONFIG: STORE_CONFIG = {
    name: "Histories.db",
    securityLevel: relationalStore.SecurityLevel.S1
  }

  // 浏览记录存储格式
  HISTORY_TABLE: HISTORY_TABLE = {
    tableName: "HistoryTable",
    sqlCreate: "CREATE TABLE IF NOT EXISTS historyTable(title VARCHAR(50), url VARCHAR(50), date VARCHAR(20), PRIMARY KEY(title, url, date)) DEFAULT CHARSET=utf8",
    columns: ["title", "url", "date"]
  }

  // 搜索引擎
  SEARCH_ENGINES: SEARCH_ENGINE[] = [
    {engine: "Bing", prefix: "https://cn.bing.com/search?q="},
    {engine: "Google", prefix: "https://www.google.com/search?q="},
    {engine: "百度", prefix: "https://www.baidu.com/s?wd="}
  ]

  DEFAULT_STUDY_WHITELIST: string[] = [
    "icourse163.org",
    "coursera.org",
    "edx.org",
    "zhihu.com"
  ]

  DEFAULT_STUDY_WHITELIST_JSON: string = JSON.stringify(this.DEFAULT_STUDY_WHITELIST)

  // ==========================================
  // 学习模式内建辅助规则（不持久化到 storage）
  // ==========================================

  // 允许主框架访问的搜索引擎域名（精确+子域匹配）
  SEARCH_ENGINE_MAINFRAME_ALLOWLIST: string[] = [
    "www.google.com",
    "www.baidu.com",
    "cn.bing.com",
  ]

  // 搜索引擎子资源辅助域名映射（key = 引擎 host，value = 允许作为子资源的域名列表）
  SEARCH_ENGINE_SUBRESOURCE_ALLOWLIST: Record<string, string[]> = {
    "www.google.com": [
      "fonts.googleapis.com", "fonts.gstatic.com", "www.gstatic.com",
      "googleads.g.doubleclick.net", "www.google-analytics.com",
      "apis.google.com", "www.googletagmanager.com", "www.googletagservices.com"
    ],
    "www.baidu.com": [
      "hm.baidu.com", "wn.pos.baidu.com", "nsclick.baidu.com", "eclick.baidu.com",
      "tongji.baidu.com", "gss.baidu.com"
    ],
    "cn.bing.com": [
      "bing.com", "static.bing.com",
      "www.bing.com", "cn.bing.com"
    ],
  }

  // 白名单站点的附属资源域名映射（key = 站点 host，value = 允许作为子资源的域名列表）
  WHITELIST_SITE_SUBRESOURCE_ALLOWLIST: Record<string, string[]> = {
    "www.icourse163.org": ["icourse163.org", "eduimg.cn", "cc.163.com"],
    "www.coursera.org": [
      "d3c7qhgkysabya.cloudfront.net",
      "production-media.paloaltonetworks.com",
      "coursera.org", "coursecache.net"
    ],
    "www.edx.org": ["courses.edx.org", "edx.org", "edxstatic.com"],
    "www.zhihu.com": ["picx.zhimg.com", "zhstatic.zhihu.com", "zhihu.com"],
  }
}

export default new CommonConstants()
