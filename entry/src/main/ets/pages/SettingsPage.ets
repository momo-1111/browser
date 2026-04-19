import { router, Prompt } from '@kit.ArkUI';
import CommonConstants from '../common/constants/CommonConstants';

@Entry
@Component
struct SettingsPage {
  @StorageLink("darkMode") darkMode: boolean = false;
  @StorageLink("privateMode") privateMode: boolean = false;
  @StorageLink("currentEngineIndex") engineIndex: number = 0;
  @StorageLink("currentEngineName") engineName: string = "Bing";
  @StorageLink("isLogin") isLogin: boolean = false;

  private engineOptions: SelectOption[] = []

  aboutToAppear() {
    for (let item of CommonConstants.SEARCH_ENGINES) {
      this.engineOptions.push({ value: item.engine });
    }
  }

  build() {
    Column() {
      Row() {
        Image($r('app.media.left_arrow_icon')).width(24).onClick(() => router.back())
        Text("设置中心").fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 15 })
      }.width('100%').padding(20)

      List() {
        // 无痕模式
        ListItem() {
          this.SettingRow("无痕浏览", true, this.privateMode, (val) => {
            this.privateMode = val
          })
        }

        // 深色模式
        ListItem() {
          this.SettingRow("深色模式", true, this.darkMode, (val) => {
            this.darkMode = val
          })
        }

        // 搜索引擎切换
        ListItem() {
          Row() {
            Text("搜索引擎").fontSize(16)
            Select(this.engineOptions)
              .selected(this.engineIndex)
              .value(this.engineName)
              .onSelect((index: number, value: string) => {
                // 关键点：显式更新 StorageLink 绑定的数据
                this.engineIndex = index;
                this.engineName = value;
                AppStorage.setOrCreate("currentEngineIndex", index);
                AppStorage.setOrCreate("currentEngineName", value);
              })
          }.width('100%').justifyContent(FlexAlign.SpaceBetween).padding(15)
        }

        // 新增：退出登录按钮（仅在已登录状态下显示）
        if (this.isLogin) {
          ListItem() {
            Row() {
              Text("退出登录")
                .fontSize(16)
                .fontColor("#E62E31") // 红色警告色
                .fontWeight(FontWeight.Medium)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center) // 居中显示
            .padding(15)
            .onClick(() => {
              this.handleLogout();
            })
          }
        }
      }
      .backgroundColor(this.darkMode ? "#2C2C2C" : Color.White)
      .borderRadius(12)
      .margin(15)
      .divider({ strokeWidth: 1, color: "#EEE" })
    }
    .width('100%').height('100%').backgroundColor("#F5F5F7")
  }

  handleLogout(): void {
    AlertDialog.show({
      title: '退出登录',
      message: '确定要退出当前华为账号吗？退出后将停止同步书签与历史。',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '退出',
        fontColor: "#E62E31",
        action: () => {
          AppStorage.setOrCreate('isLogin', false);
          AppStorage.setOrCreate('userId', "guest"); // 切换回 guest ID

          Prompt.showToast({ message: "已退出登录" });
          router.back();
        }
      }
    })
  }

  @Builder SettingRow(title: string, hasSwitch: boolean, value: boolean, onChange: (v: boolean) => void) {
    Row() {
      Text(title).fontSize(16)
      if (hasSwitch) {
        Toggle({ type: ToggleType.Switch, isOn: value }).onChange(onChange)
      }
    }.width('100%').justifyContent(FlexAlign.SpaceBetween).padding(15)
  }
}