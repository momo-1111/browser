import { LoginWithHuaweiIDButton, loginComponentManager } from '@kit.AccountKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { router } from '@kit.ArkUI';

@Entry
@Component
struct LoginPage {
  @StorageLink("darkMode") darkMode: boolean = false;

  // 登录按钮参数
  private buttonParams: loginComponentManager.LoginWithHuaweiIDButtonParams = {
    style: this.darkMode ? loginComponentManager.Style.BUTTON_WHITE : loginComponentManager.Style.BUTTON_RED,
    borderRadius: 24,
    loginType: loginComponentManager.LoginType.ID,
    supportDarkMode: true
  };

  private controller: loginComponentManager.LoginWithHuaweiIDButtonController =
    new loginComponentManager.LoginWithHuaweiIDButtonController()
      .onClickLoginWithHuaweiIDButton((error: BusinessError, response: loginComponentManager.HuaweiIDCredential) => {
        if (error) {
          this.handleLoginError(error);
          return;
        }

        if (response) {
          hilog.info(0x0000, 'BrowserTag', 'Login Succeeded');

          // 【正确写法】：在没有对接真实 UnionID 之前，先写死一个固定 ID 测试逻辑
          const stableId = "MY_FIXED_TEST_ID";
          // 1. 更新全局登录状态
          AppStorage.setOrCreate<boolean>('isLogin', true);
          // AppStorage.setOrCreate<string>('nickname', "华为用户_" + response.authorizationCode?.substring(0, 4));
          AppStorage.setOrCreate<string>('userId',stableId);

          // 2. 登录成功后跳转回个人中心或主页
          router.replaceUrl({
            url: 'pages/Index'
          }).catch((err: BusinessError) => {
            hilog.error(0x0000, 'BrowserTag', `Router failed: ${err.message}`);
          });
        }
      });

  aboutToAppear(): void {
    try {
      // 设置协议状态为已同意（实际开发中建议由用户在界面点击勾选框再设置）
      this.controller.setAgreementStatus(loginComponentManager.AgreementStatus.ACCEPTED);
    } catch (err) {
      hilog.error(0x0000, 'BrowserTag', `Set agreement failed`);
    }
  }

  handleLoginError(error: BusinessError): void {
    let msg = "登录失败";
    if (error.code === 1001502012) msg = "用户取消授权";
    else if (error.code === 1001502005) msg = "网络连接异常";

    AlertDialog.show({
      title: '提示',
      message: msg,
      confirm: { value: '确定', action: () => {} }
    });
  }

  build() {
    Column() {
      // 顶部返回
      Row() {
        Image($r('app.media.left_arrow_icon')) // 建议换成 back 图标
          .width(24).height(24)
          .onClick(() => router.back())
      }.width('100%').padding(20)

      // Logo 区域
      Column() {
        Image($r('app.media.app_icon'))
          .width(90).height(90).margin({ top: 60, bottom: 20 })

        Text("小狐狸浏览器")
          .fontSize(24).fontWeight(FontWeight.Bold)
          .fontColor(this.darkMode ? Color.White : Color.Black)

        Text("安全 · 纯净 · 极速")
          .fontSize(14).fontColor(Color.Gray).margin({ top: 10, bottom: 80 })
      }.width('100%')

      // 登录按钮
      Column() {
        LoginWithHuaweiIDButton({
          params: this.buttonParams,
          controller: this.controller
        })
          .width('85%')
          .height(45)
      }.width('100%')

      Blank()

      // 协议层
      Row() {
        Text("登录即代表同意").fontSize(12).fontColor(Color.Gray)
        Text("《隐私协议》").fontSize(12).fontColor("#45A5FF")
      }.margin({ bottom: 50 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.darkMode ? "#1C1C1C" : "#FFFFFF")
  }
}