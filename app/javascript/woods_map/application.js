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
import ShareController from "./controllers/share_controller.js"
import PaletteController from "./controllers/palette_controller.js"
import PeekController from "./controllers/peek_controller.js"
import CardController from "./controllers/card_controller.js"
import TrailController from "./controllers/trail_controller.js"
import KeysController from "./controllers/keys_controller.js"
import HelpController from "./controllers/help_controller.js"
import SettingsController from "./controllers/settings_controller.js"
import DiagramController from "./controllers/diagram_controller.js"
import GraphController from "./controllers/graph_controller.js"
import DisambiguationController from "./controllers/disambiguation_controller.js"
import GuideController from "./controllers/guide_controller.js"
import PinboardController from "./controllers/pinboard_controller.js"

const application = Application.start()
application.register("cliff", CliffController)
application.register("tooltip", TooltipController)
application.register("rows", RowsController)
application.register("tree", TreeController)
application.register("sheet", SheetController)
application.register("copy", CopyController)
application.register("share", ShareController)
application.register("palette", PaletteController)
application.register("peek", PeekController)
application.register("card", CardController)
application.register("trail", TrailController)
application.register("keys", KeysController)
application.register("help", HelpController)
application.register("settings", SettingsController)
application.register("diagram", DiagramController)
application.register("graph", GraphController)
application.register("disambiguation", DisambiguationController)
application.register("guide", GuideController)
application.register("pinboard", PinboardController)

document.documentElement.dataset.woodsMap = "ready"
