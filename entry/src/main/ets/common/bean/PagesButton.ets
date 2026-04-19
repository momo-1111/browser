// common/bean/PagesButton.ets
import TabManagerDialog from "../../view/TabManagerDialog"

@Component
export struct PagesButton {
  @State defaultImage: Resource = $r("app.media.clone_regular")
  @State activedImage: Resource = $r("app.media.clone_solid")

  private defaultScale: ScaleOptions = {x: 1, y: 1}
  private activedScale: ScaleOptions = {x: 1.2, y: 1.2}
  @State currentScale: ScaleOptions = this.defaultScale

  dialogController: CustomDialogController = new CustomDialogController({
    builder: TabManagerDialog(),
    alignment: DialogAlignment.Bottom,
    offset: { dx: 0, dy: -20 }
  })

  build() {
    Button({type: ButtonType.Circle, stateEffect: false}) {
      Column() {
        Image(this.defaultImage)
          .width(30)
          .height(30)
      }
    }
    .width(40)
    .height(40)
    .scale(this.currentScale)
    .backgroundColor("#00FFFFFF")
    .onClick(() => {
      this.currentScale = this.activedScale
      setTimeout(() => {
        this.currentScale = this.defaultScale
      }, 100)
      if (this.dialogController) {
        this.dialogController.open()
      }
    })
    .animation({ duration: 50 })
  }
}