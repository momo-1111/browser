import { Prompt } from '@kit.ArkUI'
import WebNote from '../common/bean/WebNote'
import RdbUtils from '../utils/RdbUtils'

@CustomDialog
export default struct WebNoteDialog {
  controller: CustomDialogController
  url: string = ''
  title: string = ''
  initialContent: string = ''
  sourceText: string = ''
  sourceType: string = 'manual'
  userId: string = 'guest'
  onSaved: () => void = () => {}
  @State content: string = ''

  aboutToAppear() {
    this.content = this.initialContent
  }

  private getPageTitle(): string {
    if (this.title && this.title.length > 0) {
      return this.title
    }
    return this.url.length > 0 ? this.url : '当前网页'
  }

  private async saveNote(): Promise<void> {
    const text: string = this.content.trim()
    const source: string = this.sourceText.trim()
    if (text.length === 0 && source.length === 0) {
      Prompt.showToast({ message: '先写点内容再保存' })
      return
    }

    try {
      await RdbUtils.createWebNoteTable()
      await RdbUtils.insertWebNote(new WebNote(this.url, this.getPageTitle(), text, source, this.sourceType), this.userId)
      Prompt.showToast({ message: '网页笔记已保存' })
      this.onSaved()
      this.controller.close()
    } catch (error) {
      console.error('Save web note failed: ' + error)
      Prompt.showToast({ message: '保存笔记失败' })
    }
  }

  build() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Text('网页笔记')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
          Text(this.getPageTitle())
            .fontSize(12)
            .fontColor('#7A7F87')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text('N')
          .width(34)
          .height(34)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#2F6BFF')
          .textAlign(TextAlign.Center)
          .backgroundColor('#EEF5FF')
          .borderRadius(17)
      }
      .width('100%')
      .margin({ top: 18 })

      if (this.sourceText.trim().length > 0) {
        Column({ space: 5 }) {
          Text('已选内容')
            .fontSize(12)
            .fontColor('#45A5FF')
          Text(this.sourceText)
            .fontSize(13)
            .fontColor('#4B5563')
            .lineHeight(20)
            .maxLines(4)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .backgroundColor('#F7F8FA')
        .borderRadius(14)
      }

      TextArea({ placeholder: '写下这页的想法...', text: this.content })
        .width('100%')
        .height(150)
        .fontSize(15)
        .fontColor('#202124')
        .placeholderColor('#A0A6B0')
        .backgroundColor('#F7F8FA')
        .borderRadius(16)
        .padding({ left: 12, right: 12, top: 12, bottom: 12 })
        .onChange((value: string) => {
          this.content = value
        })

      Row({ space: 10 }) {
        Button('取消')
          .layoutWeight(1)
          .height(42)
          .fontSize(14)
          .fontColor('#344054')
          .backgroundColor('#F2F4F7')
          .borderRadius(21)
          .onClick(() => {
            this.controller.close()
          })
        Button('保存')
          .layoutWeight(1)
          .height(42)
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor('#45A5FF')
          .borderRadius(21)
          .onClick(() => {
            void this.saveNote()
          })
      }
      .width('100%')
      .margin({ bottom: 14 })
    }
    .width('100%')
    .padding({ left: 18, right: 18 })
    .backgroundColor(Color.White)
    .borderRadius({ topLeft: 20, topRight: 20 })
  }
}
