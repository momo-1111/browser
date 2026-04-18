import { router, Prompt } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import RdbUtils from '../utils/RdbUtils'

@Entry
@Component
struct ProfileEditPage {
  @StorageLink("darkMode") darkMode: boolean = false;

  // 直接绑定全局状态，修改后自动同步
  @StorageLink('nickname') nickname: string = '';
  @StorageLink('avatarPath') avatarPath: string = '';

  // 局部变量，用于在页面展示（避免未点保存就改变了全局）
  @State tempName: string = '';
  @State tempAvatar: string = '';

  aboutToAppear(): void {
    this.tempName = this.nickname;
    this.tempAvatar = this.avatarPath;
  }

  /**
   * 调用系统相册选择头像
   */
  async selectImage(): Promise<void> {
    try {
      const photoSelectOptions: picker.PhotoSelectOptions = new picker.PhotoSelectOptions();
      photoSelectOptions.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;

      const photoPicker: picker.PhotoViewPicker = new picker.PhotoViewPicker();
      const photoSelectResult: picker.PhotoSelectResult = await photoPicker.select(photoSelectOptions);

      if (photoSelectResult && photoSelectResult.photoUris.length > 0) {
        const selectedUri: string = photoSelectResult.photoUris[0];

        // 【关键】将相册图片拷贝到应用私有目录，确保永久有效
        const context = getContext(this);
        const fileName = `avatar_${new Date().getTime()}.jpg`;
        const destPath = `${context.filesDir}/${fileName}`;

        const file = fs.openSync(selectedUri, fs.OpenMode.READ_ONLY);
        const destFile = fs.openSync(destPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
        fs.copyFileSync(file.fd, destFile.fd);
        fs.closeSync(file.fd);
        fs.closeSync(destFile.fd);

        this.tempAvatar = destPath; // 先存入临时路径
      }
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      console.error(`PhotoPicker failed: ${error.code}, ${error.message}`);
    }
  }

  /**
   * 保存修改并回退
   */
  // 在 ProfileEditPage.ets 的 saveChanges 方法中
  async saveChanges() {
    const name = this.tempName.trim()
    if (!name) {
      Prompt.showToast({ message: '昵称不能为空' })
      return
    }

    // 1. 更新内存和持久化
    this.nickname = name
    this.avatarPath = this.tempAvatar

    // 2. 同步到数据库，关联当前的 userId
    const currentUserId = AppStorage.get<string>("userId") || "guest"
    await RdbUtils.updateProfile(currentUserId, name, this.tempAvatar)

    Prompt.showToast({ message: '保存成功' })
    router.back()
  }

  build() {
    Column() {
      // 1. 导航栏
      Row() {
        Image($r('app.media.left_arrow_icon')).width(24)
          .onClick(() => router.back())
        Text('修改个人资料')
          .fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 15 })
          .fontColor(this.darkMode ? Color.White : Color.Black)
      }
      .width('100%').padding(20)

      // 2. 头像编辑
      Column() {
        Stack({ alignContent: Alignment.BottomEnd }) {
          Image(this.tempAvatar !== "" ? "file://" + this.tempAvatar : $r('app.media.app_icon'))
            .width(120).height(120).borderRadius(60)
            .border({ width: 3, color: '#45A5FF' })
            .objectFit(ImageFit.Cover)
            .onClick(() => this.selectImage())

          // 右下角编辑图标
          Circle({ width: 32, height: 32 }).fill("#45A5FF")
          Text("✎").fontColor(Color.White).fontSize(18).textAlign(TextAlign.Center).width(32)
        }
        .margin({ top: 40 })

        Text('点击更换头像')
          .fontSize(14).margin({ top: 10 }).fontColor(Color.Gray)
          .onClick(() => this.selectImage())
      }
      .width('100%')

      // 3. 昵称编辑
      Column() {
        Text('我的昵称')
          .fontSize(14).fontColor(Color.Gray).margin({ bottom: 10 })

        TextInput({ text: this.tempName, placeholder: '请输入新昵称' })
          .height(55)
          .borderRadius(12)
          .backgroundColor(this.darkMode ? "#2C2C2C" : Color.White)
          .fontColor(this.darkMode ? Color.White : Color.Black)
          .onChange((value: string) => {
            this.tempName = value;
          })
      }
      .width('90%').margin({ top: 40 }).alignItems(HorizontalAlign.Start)

      Blank()

      // 4. 保存
      Button('保存修改')
        .width('90%').height(50).margin({ bottom: 40 })
        .backgroundColor("#45A5FF")
        .onClick(() => this.saveChanges())
    }
    .width('100%').height('100%')
    .backgroundColor(this.darkMode ? "#1C1C1C" : "#F5F5F7")
  }
}