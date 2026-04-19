import { ForwardButton } from './ForwardButton'
import { BackButton } from './BackButton'
import { SettingButton } from './SettingButton'
import { PagesButton } from './PagesButton'
import { TabManager } from '../../model/TabManager'
import { ProfileButton } from './ProfileButton'
import emitter from '@ohos.events.emitter'

@Component
export struct FunctionButtons {
  @Link isBacked: boolean
  @Link isForward: boolean

  @Consume('tabManager') tabManager: TabManager

  build() {
    Row() {
      BackButton()
        .opacity(this.isBacked ? 1 : 0.5)
        .enabled(this.isBacked)
        .onClick(() => {
          try {
            const targetUrl = this.tabManager.goBack()
            if (targetUrl) {
              emitter.emit('tabHistoryNavigate', { data: { url: targetUrl } })
            }
          } catch (error) {
            console.log('Back navigation failed: ' + error)
          }
        })
      ForwardButton()
        .opacity(this.isForward ? 1 : 0.5)
        .enabled(this.isForward)
        .onClick(() => {
          try {
            const targetUrl = this.tabManager.goForward()
            if (targetUrl) {
              emitter.emit('tabHistoryNavigate', { data: { url: targetUrl } })
            }
          } catch (error) {
            console.log('Forward navigation failed: ' + error)
          }
        })
      PagesButton()
      ProfileButton()
      SettingButton()
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.SpaceAround)
  }
}
