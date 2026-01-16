class_name GdSpawnConstants

const BASE_SETTING = "GdSpawn/Settings/%s"
const BASE_SHORTCUTS = "GdSpawn/Shortcuts/%s"

#settings
const PREVIEW_PERSPECTIVE = BASE_SETTING % "Preview Perspective"
const PREVIEW_ANGLE_HORIZONTAL = BASE_SETTING % "Preview Angle Horizontal"
const PREVIEW_ANGLE_VERTICAL = BASE_SETTING % "Preview Angle Vertical"

const SHIFT_ROTATION_STEP = BASE_SETTING % "Shift Rotation Step"

#const SURFACE_PLACEMENT_COLLISION_MASK = BASE_SETTING % "Surface Placement Collsion Mask"
const SHOW_TOOLTIPS = BASE_SETTING % "Show Tooltips"


#shortcuts
const RESET_TRANSFORMATION = BASE_SHORTCUTS % "Reset Transformation"
const SELECT_PREVIOUS_ASSET = BASE_SHORTCUTS % "Select Previous Scene"
const PLACE_AND_SELECT = BASE_SHORTCUTS % "Place and Select Modifier"
const TOGGLE_SNAPPING = BASE_SHORTCUTS % "Toggle Snapping"
const DISPLACE_PLANE = BASE_SHORTCUTS % "Move Grid (Plane Placement Mode)"
const ROTATE_90_X = BASE_SHORTCUTS % "Rotate 90 degrees around X"
const ROTATE_90_Y = BASE_SHORTCUTS % "Rotate 90 degrees around Y"
const ROTATE_90_Z = BASE_SHORTCUTS % "Rotate 90 degrees around Z"

const SELECT_YZ_PLANE = BASE_SHORTCUTS % "Select YZ Plane"
const SELECT_XZ_PLANE = BASE_SHORTCUTS % "Select XZ Plane"
const SELECT_XY_PLANE = BASE_SHORTCUTS % "Select XY Plane"

const FLIP_X = BASE_SHORTCUTS % "Flip on X axis"
const FLIP_Y = BASE_SHORTCUTS % "Flip on Y axis"
const FLIP_Z = BASE_SHORTCUTS % "Flip on Z axis"


const DEFAULT_COLLISION_MASK: int = 0xFFFFFFFF 


