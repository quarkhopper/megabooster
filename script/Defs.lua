CURRENT_VERSION = "1.0"
TOOL_NAME = "MegaBooster"

-- delimeters
DELIM = {}
DELIM.VEC = ":"
DELIM.STRINGS = "~"
DELIM.ENUM_PAIR = "&"
DELIM.OPTION_SET = "|"
DELIM.OPTION = ";"

-- registry related delimeters and strings
REG = {}
REG.DELIM = "."
REG.TOOL_KEY = "megabooster"
REG.TOOL_NAME = "savegame.mod.tool." .. REG.TOOL_KEY .. ".quarkhopper"
REG.TOOL_OPTION = "option"
REG.PREFIX_TOOL_OPTIONS = REG.TOOL_NAME .. REG.DELIM .. REG.TOOL_OPTION
REG.TOOL_KEYBIND = "keybind"
REG.PREFIX_TOOL_KEYBIND = REG.TOOL_NAME .. REG.DELIM .. REG.TOOL_KEYBIND

-- Keybinds
function setup_keybind(name, reg, default_key)
    local keybind = {["name"] = name, ["reg"] = reg}
    keybind.key = GetString(REG.PREFIX_TOOL_KEYBIND..REG.DELIM..keybind.reg)
    if keybind.key == "" then 
        keybind.key = default_key
        SetString(REG.PREFIX_TOOL_KEYBIND..REG.DELIM..keybind.reg, keybind.key)
    end
    return keybind
end

KEY = {}
KEY.DEBUG = setup_keybind("Debug mode", "debug mode", "F11")
KEY.IGNITION = setup_keybind("Ignition toggle", "ignition", "I")
KEY.STOP_FX = setup_keybind("Stop all effects", "stop_fx", "V")
KEY.OPTIONS = setup_keybind("Options", "options", "O")

CONSTS = {}
CONSTS.FLAME_COLOR_DEFAULT = Vec(7.7, 1, 0.8)

-- UI display constants
UI = {}
UI.OPTION_TEXT_SIZE = 18
UI.OPTION_MODAL_HEADING_SIZE = 24
UI.OPTION_DESC_SIZE = 14
UI.OPTION_CONTROL_WIDTH = 1000
UI.OPTION_COLOR_SLIDER_WIDTH = UI.OPTION_CONTROL_WIDTH - 50
UI.OPTION_STANDARD_SLIDER_WIDTH = UI.OPTION_CONTROL_WIDTH - 50
UI.OPTION_BUMP_BUTTON_WIDTH = 10
