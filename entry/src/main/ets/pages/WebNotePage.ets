import { router, Prompt } from '@kit.ArkUI'
import WebNote from '../common/bean/WebNote'
import RdbUtils from '../utils/RdbUtils'

@Entry
@Component
struct WebNotePage {
  @StorageLink('darkMode') darkMode: boolean = false
  @StorageLink('userId') userId: string = 'guest'
  @State notes: WebNote[] = []
  @State editingId: number = -1
  @State editingContent: string = ''

  async onPageShow() {
    await this.loadNotes()
  }

  private async loadNotes(): Promise<void> {
    try {
      await RdbUtils.createWebNoteTable()
      this.notes = await RdbUtils.queryWebNotes(this.userId)
    } catch (error) {
      console.error('Load web notes failed: ' + error)
      Prompt.showToast({ message: '加载网页笔记失败' })
    }
  }

  private formatTime(timestamp: number): string {
    return new Date(timestamp).toLocaleString()
  }

  private beginEdit(note: WebNote): void {
    this.editingId = note.id
    this.editingContent = note.content
  }

  private async saveEdit(note: WebNote): Promise<void> {
    const content: string = this.editingContent.trim()
    if (content.length === 0 && note.sourceText.trim().length === 0) {
      Prompt.showToast({ message: '笔记内容不能为空' })
      return
    }
    try {
      await RdbUtils.updateWebNote(note.id, content)
      this.editingId = -1
      this.editingContent = ''
      await this.loadNotes()
      Prompt.showToast({ message: '笔记已更新' })
    } catch (error) {
      console.error('Update web note failed: ' + error)
      Prompt.showToast({ message: '更新笔记失败' })
    }
  }

  private async deleteNote(id: number): Promise<void> {
    try {
      await RdbUtils.deleteWebNote(id)
      await this.loadNotes()
      Prompt.showToast({ message: '笔记已删除' })
    } catch (error) {
      console.error('Delete web note failed: ' + error)
      Prompt.showToast({ message: '删除笔记失败' })
    }
  }

  @Builder
  private NoteCard(note: WebNote) {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 4 }) {
          Text(note.title.length > 0 ? note.title : '未命名网页')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.darkMode ? Color.White : '#202124')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(note.url)
            .fontSize(11)
            .fontColor('#7A7F87')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(this.formatTime(note.timestamp))
          .fontSize(11)
          .fontColor('#9CA3AF')
      }
      .width('100%')

      if (note.sourceText.length > 0) {
        Text(note.sourceText)
          .width('100%')
          .fontSize(13)
          .fontColor('#4B5563')
          .lineHeight(20)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: 10, right: 10, top: 8, bottom: 8 })
          .backgroundColor(this.darkMode ? '#303030' : '#EEF5FF')
          .borderRadius(12)
      }

      if (this.editingId === note.id) {
        TextArea({ placeholder: '修改笔记内容...', text: this.editingContent })
          .width('100%')
          .height(120)
          .fontSize(14)
          .fontColor(this.darkMode ? Color.White : '#202124')
          .placeholderColor('#A0A6B0')
          .backgroundColor(this.darkMode ? '#303030' : '#F7F8FA')
          .borderRadius(12)
          .padding({ left: 10, right: 10, top: 10, bottom: 10 })
          .onChange((value: string) => {
            this.editingContent = value
          })

        Row({ space: 8 }) {
          Button('取消')
            .height(32)
            .fontSize(12)
            .fontColor('#344054')
            .backgroundColor('#F2F4F7')
            .borderRadius(16)
            .onClick(() => {
              this.editingId = -1
              this.editingContent = ''
            })
          Button('保存')
            .height(32)
            .fontSize(12)
            .fontColor(Color.White)
            .backgroundColor('#45A5FF')
            .borderRadius(16)
            .onClick(() => {
              void this.saveEdit(note)
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
      } else {
        if (note.content.length > 0) {
          Text(note.content)
            .width('100%')
            .fontSize(14)
            .fontColor(this.darkMode ? '#ECECEC' : '#30343B')
            .lineHeight(22)
        }

        Row({ space: 8 }) {
          Button('编辑')
            .height(32)
            .fontSize(12)
            .fontColor('#45A5FF')
            .backgroundColor(this.darkMode ? '#263648' : '#EEF5FF')
            .borderRadius(16)
            .onClick(() => {
              this.beginEdit(note)
            })
          Button('删除')
            .height(32)
            .fontSize(12)
            .fontColor('#D92D20')
            .backgroundColor(this.darkMode ? '#3A2626' : '#FFF1F0')
            .borderRadius(16)
            .onClick(() => {
              void this.deleteNote(note.id)
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
      }
    }
    .width('100%')
    .padding({ left: 15, right: 15, top: 14, bottom: 14 })
    .backgroundColor(this.darkMode ? '#2C2C2C' : Color.White)
    .borderRadius(16)
  }

  build() {
    Column() {
      Row() {
        Image($r('app.media.left_arrow_icon'))
          .width(24)
          .onClick(() => router.back())
        Text('网页笔记')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 15 })
          .fontColor(this.darkMode ? Color.White : Color.Black)
        Blank()
        Text(`${this.notes.length} 条`)
          .fontSize(12)
          .fontColor('#45A5FF')
      }
      .width('100%')
      .padding(20)

      if (this.notes.length === 0) {
        Column({ space: 8 }) {
          Image($r('app.media.note'))
            .width(42)
            .height(42)
            .opacity(0.55)
          Text('还没有网页笔记')
            .fontSize(16)
            .fontColor(this.darkMode ? '#ECECEC' : '#4B5563')
          Text('浏览网页时点左上角笔记图标，或长按内容添加。')
            .fontSize(12)
            .fontColor('#9CA3AF')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 12 }) {
          ForEach(this.notes, (note: WebNote) => {
            ListItem() {
              this.NoteCard(note)
            }
          }, (note: WebNote) => note.id.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 15, right: 15, bottom: 16 })
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.darkMode ? '#1C1C1C' : '#F5F5F7')
  }
}
