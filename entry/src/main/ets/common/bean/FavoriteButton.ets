// common/bean/FavoriteButton.ets
import { Prompt } from '@kit.ArkUI'
import RdbUtils from '../../utils/RdbUtils'
import webview from '@ohos.web.webview'

@Component
export struct FavoriteButton {
  @State defaultImage: Resource = $r("app.media.left_arrow_icon")   // 你需要准备 star_icon 图片
  @Consume webviewController: webview.WebviewController

  build() {
    Button({ type: ButtonType.Circle }) {
      Column() {
        Image(this.defaultImage)
          .width(30)
          .height(30)
      }
    }
    .width(40)
    .height(40)
    .backgroundColor("#00FFFFFF")
    .onClick(async () => {
      try {
        const title = this.webviewController.getTitle()
        const url = this.webviewController.getUrl()
        if (url && url !== 'about:blank') {
          await RdbUtils.insertBookmark(title, url)
          Prompt.showToast({ message: "已添加到收藏夹" })
        } else {
          Prompt.showToast({ message: "当前页面无法收藏" })
        }
      } catch (e) {
        console.error("收藏失败", e)
        Prompt.showToast({ message: "收藏失败" })
      }
    })
  }
}