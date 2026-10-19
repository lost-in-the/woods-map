// Woods Map entry module: starts Stimulus and registers the engine's
// controllers. Third-party libraries are vendored under vendor/javascript and
// pinned in lib/woods_map/importmap.rb; relative imports resolve because the
// whole asset set shares one content digest.
import { Application } from "@hotwired/stimulus"
import CliffController from "./controllers/cliff_controller.js"
import TooltipController from "./controllers/tooltip_controller.js"
import RowsController from "./controllers/rows_controller.js"
import TreeController from "./controllers/tree_controller.js"
import SheetController from "./controllers/sheet_controller.js"
import CopyController from "./controllers/copy_controller.js"

const application = Application.start()
application.register("cliff", CliffController)
application.register("tooltip", TooltipController)
application.register("rows", RowsController)
application.register("tree", TreeController)
application.register("sheet", SheetController)
application.register("copy", CopyController)

document.documentElement.dataset.woodsMap = "ready"
