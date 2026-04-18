import { router } from '@kit.ArkUI';

@Component
export struct ProfileButton {
  @StorageLink("darkMode") darkMode: boolean = false;

  build() {
    Column() {
      // 你可以找一个“人头”形状的图标放入 media
      Image($r('app.media.home_icon'))
        .width(30)
        .height(30)
    }
    .width(40)
    .height(40)
    .height(40)
    .backgroundColor("#00FFFFFF")
    .onClick(() => {
      router.pushUrl({
        url: 'pages/ProfilePage'
      })
    })
  }
}