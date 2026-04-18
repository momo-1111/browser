import relationalStore from '@ohos.data.relationalStore'
import History from '../common/bean/History'
import UserProfile from '../common/bean/UserProfile'

export default class RdbUtils {
  // 关系型数据库
  private static rdbStore: relationalStore.RdbStore

  static setStore(store: relationalStore.RdbStore) {
    RdbUtils.rdbStore = store
  }

  static getStore(): relationalStore.RdbStore {
    return RdbUtils.rdbStore
  }

  static async executeSql(sql: string) {
    return RdbUtils.getStore().executeSql(sql)
  }

  static async createDateTable() {
    const sql = `CREATE TABLE IF NOT EXISTS date_table (
      date TEXT PRIMARY KEY
    )`

    try {
      await RdbUtils.executeSql(sql)
    } catch (error) {
      // TODO: Implement error handling.
      console.error("执行 sql1 语句异常：" + error)
    }
  }

  static async createProfileTable() {
    const sql = `CREATE TABLE IF NOT EXISTS user_profile (
    userId TEXT PRIMARY KEY,
    nickname TEXT,
    avatarPath TEXT
  )`
    await RdbUtils.executeSql(sql)
  }
  // 保存/更新用户信息
  static async updateProfile(userId: string, nickname: string, avatarPath: string) {
    const valueBucket: relationalStore.ValuesBucket = {
      "userId": userId,
      "nickname": nickname,
      "avatarPath": avatarPath
    }
    // 使用 replace 语句，如果存在则更新，不存在则插入
    return RdbUtils.getStore().insert("user_profile", valueBucket, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
  }

  static async queryProfile(userId: string): Promise<UserProfile | null> {
    let predicates = new relationalStore.RdbPredicates("user_profile")
    predicates.equalTo("userId", userId)
    let resultSet = await RdbUtils.getStore().query(predicates)

    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow()
      const nickname = resultSet.getString(resultSet.getColumnIndex("nickname"))
      const avatarPath = resultSet.getString(resultSet.getColumnIndex("avatarPath"))
      resultSet.close()

      // 【修改点】返回显式的类实例，而不是匿名对象 { nickname, avatarPath }
      return new UserProfile(nickname, avatarPath)
    }

    resultSet.close()
    return null
  }


  static async createHistoryTable(tableName: string) {
    tableName = "history_" + tableName
    const sql = `CREATE TABLE IF NOT EXISTS ${tableName} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      url TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      userId TEXT NOT NULL -- 新增字段
    )`

    try {
      await RdbUtils.executeSql(sql)
    } catch (error) {
      // TODO: Implement error handling.
      console.error("执行 sql2 语句异常：" + error.code)
    }
  }

  // --- 新增：书签表逻辑 ---
  static async createBookmarkTable() {
    const sql = `CREATE TABLE IF NOT EXISTS bookmarks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      url TEXT NOT NULL,
      timestamp TEXT NOT NULL
    )`
    try {
      await RdbUtils.executeSql(sql)
      console.info("书签表创建成功")
    } catch (error) {
      console.error("创建书签表异常：" + error)
    }
  }
  // 插入书签
  static async insertBookmark(history: History) {
    const valueBucket: relationalStore.ValuesBucket = {
      "title": history.title,
      "url": history.url,
      "timestamp": new Date().getTime().toString()
    }
    return RdbUtils.getStore().insert("bookmarks", valueBucket)
  }

  // 查询所有书签
  static async queryAllBookmarks(): Promise<History[]> {
    let predicates = new relationalStore.RdbPredicates("bookmarks")
    predicates.orderByDesc("timestamp") // 最新的在前面
    let bookmarks: History[] = []
    try {
      let resultSet = await RdbUtils.getStore().query(predicates)
      while (resultSet.goToNextRow()) {
        const id = resultSet.getLong(resultSet.getColumnIndex("id"))
        const title = resultSet.getString(resultSet.getColumnIndex("title"))
        const url = resultSet.getString(resultSet.getColumnIndex("url"))
        const timestamp = resultSet.getString(resultSet.getColumnIndex("timestamp"))
        let item = new History(title, url, timestamp)
        item.setId(id)
        bookmarks.push(item)
      }
      resultSet.close()
    } catch (error) {
      console.error("查询书签异常：" + error)
    }
    return bookmarks
  }

  // 删除书签
  static async deleteBookmark(id: number) {
    let predicates = new relationalStore.RdbPredicates("bookmarks")
    predicates.equalTo("id", id)
    return RdbUtils.getStore().delete(predicates)
  }


  static async insertDate(date: string) {
    const predicates = new relationalStore.RdbPredicates("date_table")

    predicates.equalTo("date", date);

    let resultSet: relationalStore.ResultSet

    try {
      resultSet = await RdbUtils.getStore().query(predicates, ["date"]);

      if (resultSet.rowCount <= 0) {
        const valueBucket: relationalStore.ValuesBucket = {
          "date": date
        }

        // 在日期表中插入当前日期
        RdbUtils.getStore().insert("date_table", valueBucket)
      }

      resultSet.close()
    } catch (error) {
      console.error("插入日期异常：" + error)
    }

    // 按天分表
    await RdbUtils.createHistoryTable(date)
  }

  static async insertHistory(tableName: string, history: History, userId: string) {
    tableName = "history_" + tableName
    const valueBucket: relationalStore.ValuesBucket = {
      "title": history.title,
      "url": history.url,
      "timestamp": history.timestamp,
      "userId": userId // 保存当前用户ID
    }
    return RdbUtils.getStore().insert(tableName, valueBucket)
  }

  static async queryAllDate() {
    const predicates = new relationalStore.RdbPredicates("date_table")

    let dateList: string[] = []

    let resultSet: relationalStore.ResultSet

    try {
      resultSet = await RdbUtils.getStore().query(predicates)

      console.info(`ResultSet column names: ${resultSet.columnNames}, column count: ${resultSet.columnCount}`)

      while (resultSet.goToNextRow()) {
        dateList.unshift(resultSet.getString(resultSet.getColumnIndex("date")))
      }

      // 释放数据集的内存，若不释放可能会引起 fd 泄露与内存泄露
      resultSet.close()
    } catch (error) {
      console.error(`查询异常，失败代码： ${error.code}，失败信息： ${error.message}`);
    }

    return dateList
  }

  static async queryHistoriesByDate(date: string, userId: string) {
    const tableName = "history_" + date;
    let predicates = new relationalStore.RdbPredicates(tableName);
    predicates.equalTo("userId", userId); // 增加过滤条件

    let histories: History[] = [];
    let resultSet: relationalStore.ResultSet | null = null;

    try {
      // 【关键修复】使用 await 等待查询结果，不要用 .then()
      resultSet = await RdbUtils.getStore().query(predicates);
      console.info(`[RDB] 正在查询表:${tableName} 用户:${userId} 记录数:${resultSet.rowCount}`);

      while (resultSet.goToNextRow()) {
        const id = resultSet.getLong(resultSet.getColumnIndex("id"));
        const title = resultSet.getString(resultSet.getColumnIndex("title"));
        const url = resultSet.getString(resultSet.getColumnIndex("url"));
        const timestamp = resultSet.getString(resultSet.getColumnIndex("timestamp"));

        let history = new History(title, url, timestamp);
        history.setId(id);
        histories.unshift(history);
      }
    } catch (error) {
      console.error(`[RDB] 查询失败: ${error.message}`);
    } finally {
      if (resultSet) {
        resultSet.close();
      }
    }
    // 【关键修复】确保在循环结束后再返回数据
    return histories;
  }

  // 根据 id 删除对应数据表中的记录
  static async deleteById(date: string, id: number) {
    let predicates = new relationalStore.RdbPredicates(date);
    predicates.equalTo("id", id)
    return RdbUtils.getStore().delete(predicates);
  }

  static async deleteByDate(date: string) {
    let predicates = new relationalStore.RdbPredicates(date);
    return RdbUtils.getStore().delete(predicates);
  }

  static async deleteAll() {
    const dateList: string[] = await RdbUtils.queryAllDate()
    dateList.forEach((date: string) => {
      const sql = `DROP TABLE IF EXISTS ${date}`
      RdbUtils.executeSql(sql)
    })

    RdbUtils.executeSql(`DROP TABLE IF EXISTS date_table`)
  }


  // --- 下载表初始化 ---
  static async createDownloadTable() {
    const sql = `CREATE TABLE IF NOT EXISTS downloads (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      fileName TEXT,
      filePath TEXT,
      fileUri TEXT,
      fileType TEXT,
      timestamp INTEGER,
      userId TEXT
    )`;
    try {
      await RdbUtils.executeSql(sql);
      console.info("[Rdb] 下载表创建/核对成功");
    } catch (e) {
      console.error("[Rdb] 创建下载表失败: " + e.message);
    }
  }

  // --- 插入下载记录 ---
  static async insertDownload(name: string, path: string, uri: string, type: string, userId: string) {
    const valueBucket: relationalStore.ValuesBucket = {
      "fileName": name,
      "filePath": path,
      "fileUri": uri,
      "fileType": type,
      "timestamp": new Date().getTime(),
      "userId": userId
    };
    console.info(`[Rdb] 正在插入下载记录: ${name}, 用户: ${userId}`);
    return RdbUtils.getStore().insert("downloads", valueBucket);
  }

  // --- 查询下载记录 ---
  static async queryDownloads(userId: string): Promise<Array<Record<string, Object>>> {
    let predicates = new relationalStore.RdbPredicates("downloads");
    predicates.equalTo("userId", userId).orderByDesc("timestamp");
    let list: Array<Record<string, Object>> = [];
    try {
      let resultSet = await RdbUtils.getStore().query(predicates);
      while (resultSet.goToNextRow()) {
        list.push({
          "id": resultSet.getLong(resultSet.getColumnIndex("id")),
          "fileName": resultSet.getString(resultSet.getColumnIndex("fileName")),
          "filePath": resultSet.getString(resultSet.getColumnIndex("filePath")),
          "fileUri": resultSet.getString(resultSet.getColumnIndex("fileUri")),
          "fileType": resultSet.getString(resultSet.getColumnIndex("fileType")),
          "timestamp": resultSet.getLong(resultSet.getColumnIndex("timestamp"))
        });
      }
      resultSet.close();
    } catch (e) {
      console.error("[Rdb] 查询下载失败: " + e.message);
    }
    return list;
  }


}