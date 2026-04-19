import TabManagerDialog from "../../view/TabManagerDialog"
@Component
export struct PagesButton {
  @StorageLink('tabCount') tabCount: number = 1
  private defaultScale: ScaleOptions = { x: 1, y: 1 }
  private activedScale: ScaleOptions = { x: 1.2, y: 1.2 }
  @State currentScale: ScaleOptions = this.defaultScale
  dialogController: CustomDialogController = new CustomDialogController({
    builder: TabManagerDialog(),
    alignment: DialogAlignment.Bottom,
    offset: { dx: 0, dy: -20 }
  })
  build() {
    Button({ type: ButtonType.Circle, stateEffect: false }) {
      Text(`${this.tabCount}`)
        .width(28)
        .height(24)
        .textAlign(TextAlign.Center)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor('#101828')
        .backgroundColor('#FFFFFF')
        .borderRadius(6)
        .border({ width: 1.5, color: '#101828' })
    }
    .width(40)
    .height(40)
    .scale(this.currentScale)
    .backgroundColor('#00FFFFFF')
    .onClick(() => {
      this.currentScale = this.activedScale
      setTimeout(() => {
        this.currentScale = this.defaultScale
      }, 100)
      this.dialogController.open()
    })
    .animation({ duration: 50 })
  }
}