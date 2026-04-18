// src/main/ets/common/bean/UserProfile.ets
export default class UserProfile {
  nickname: string = ""
  avatarPath: string = ""

  constructor(nickname: string, avatarPath: string) {
    this.nickname = nickname
    this.avatarPath = avatarPath
  }
}