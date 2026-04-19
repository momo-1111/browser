import { Prompt } from '@kit.ArkUI'
import CommonConstants from '../common/constants/CommonConstants'
import DomainUtils from '../utils/DomainUtils'
import StudyModeRules from '../utils/StudyModeRules'

@Component
export default struct WhitelistDialog {
  @StorageLink("studyWhitelistJson") studyWhitelistJson: string = CommonConstants.DEFAULT_STUDY_WHITELIST_JSON

  @State inputDomain: string = ""
  @State whitelist: string[] = []

  onBack: () => void = () => {}

  aboutToAppear() {
    this.reloadWhitelist()
  }

  private reloadWhitelist() {
    this.whitelist = StudyModeRules.parseWhitelist(this.studyWhitelistJson)
  }

  private persistWhitelist(whitelist: string[]) {
    const normalized = DomainUtils.normalizeRules(whitelist)
    this.studyWhitelistJson = StudyModeRules.stringifyWhitelist(normalized)
    this.whitelist = normalized
  }

  private addDomain() {
    const domain = DomainUtils.normalizeDomainRule(this.inputDomain)
    if (domain.length === 0) {
      Prompt.showToast({
        message: "请输入有效域名"
      })
      return
    }

    if (this.whitelist.indexOf(domain) !== -1) {
      Prompt.showToast({
        message: "该域名已在白名单中"
      })
      return
    }

    this.persistWhitelist([domain, ...this.whitelist])
    this.inputDomain = ""
    Prompt.showToast({
      message: "白名单已更新"
    })
  }

  private removeDomain(domain: string) {
    this.persistWhitelist(this.whitelist.filter((item: string) => item !== domain))
    Prompt.showToast({
      message: "已移除白名单域名"
    })
  }

  build() {
    Column({ space: 12 }) {
      Text("学习模式白名单")
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .margin({ top: 20 })

      Text("仅管理主站访问权限，搜索引擎由系统自动放行，无需手动添加")
        .fontSize(12)
        .fontColor(Color.Gray)

      Row({ space: 8 }) {
        TextInput({ placeholder: "输入域名，如 example.com（自动匹配子域名）", text: this.inputDomain })
          .layoutWeight(1)
          .height(42)
          .borderRadius(12)
          .backgroundColor("#F5F5F5")
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.inputDomain = value
          })
          .onSubmit(() => {
            this.addDomain()
          })

        Button("添加")
        .height(42)
        .borderRadius(12)
        .backgroundColor("#45A5FF")
        .fontColor(Color.White)
        .onClick(() => {
          this.addDomain()
        })
      }
      .width("100%")

      List({ space: 8 }) {
        ForEach(this.whitelist, (domain: string) => {
          ListItem() {
            Row() {
              Text(domain)
                .layoutWeight(1)
                .fontSize(15)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              Button("删除")
                .height(32)
                .backgroundColor("#FFF0F0")
                .fontColor("#E62E31")
                .onClick(() => {
                  this.removeDomain(domain)
                })
            }
            .width("100%")
            .padding({ left: 14, right: 14, top: 12, bottom: 12 })
            .borderRadius(14)
            .backgroundColor(Color.White)
          }
        })
      }
      .width("100%")
      .height(280)
      .divider({ strokeWidth: 0 })

      Button("关闭")
        .width("100%")
        .height(42)
        .margin({ bottom: 20 })
        .borderRadius(12)
        .backgroundColor("#F2F3F5")
        .fontColor("#333333")
        .onClick(() => {
          this.onBack()
        })
    }
    .width("100%")
    .padding({ left: 16, right: 16 })
    .backgroundColor("#FAFAFA")
  }
}
