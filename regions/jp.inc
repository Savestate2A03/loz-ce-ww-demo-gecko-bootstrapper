# ---------------------------------------------------------------------------
# Collector's Edition JP (PZLJ01)
# ---------------------------------------------------------------------------

.set LAUNCHER_TIMER_SET_ADDR,   0x800360e8
.set LOADED_GAME_CHECK_ADDR,    0x802baa10

# TWW hook and return addresses
.set COLLECT_HOOK,              0x801a4fc8
.set COLLECT_OTHER,             0x801a4fd8
.set COLLECT_CONTINUE,          0x801a5014
.set ITEM_HOOK,                 0x801cedd4
.set ITEM_OTHER,                0x801cedd8
.set ITEM_CONTINUE,             0x801cf5e8
.set NAME_HOOK,                 0x8022bb38
.set NAME_CONTINUE,             0x8022bb48
.set NAME_SET_LINK_CALL,        0x8022d4ec
.set DEMO_SAVE_DATA_HOOK,       0x8022dad0
.set DEMO_SAVE_COPY,            0x8022dad4
.set DEMO_SAVE_READY_HOOK,      0x8022db00
.set DEMO_SAVE_RETURN,          0x8022db10
.set NAME_NEW_FILE_HOOK,        0x8022cb7c
.set NAME_NEW_FILE_WRITE,       0x8022cbdc
.set SAVE_NEW_FILE_HOOK,        0x801d7768
.set SAVE_NEW_FILE_WRITE,       0x801d77c8
.set MEMCARD_HOOK,              0x80018ea0
.set FILE_RIGHT_HOOK,           0x80182778
.set FILE_RIGHT_CHECK,          0x8018277c
.set FILE_RIGHT_CONTINUE,       0x80182794
.set FILE_LEFT_HOOK,            0x801827fc
.set FILE_LEFT_CHECK,           0x80182800
.set FILE_LEFT_CONTINUE,        0x80182818

# TWW functions and variables
.set SAVE_INITIALIZE,           0x801d55ac
.set OPTION_INITIALIZE,         0x801d4598
.set MEMCARD_GET_STATUS,        0x80019268
.set RESET_FLAG,                0x80397b80
.set OS_LOCK_MUTEX,             0x80301b00
.set OS_UNLOCK_MUTEX,           0x80301bdc
.set OS_SIGNAL_COND,            0x80301ec4
.set EXI_PROBE,                 0x803060a8

# Menu structure offsets and setSaveData registers
.set COLLECT_MODE,          0x27ee
.set COLLECT_OPTIONS_MENU,  0x2780
.set COLLECT_SAVE_MENU,     0x2784
.set ITEM_MODE,             0x23fe
.set NAME_MAIN_STATE,       0x0554
.set NAME_CARD_STATE,       0x0556
.set NAME_DRAW_STATE,       0x0557
.set NAME_SAVE_BUFFER,      0x0560
.set SAVE_SAVE_BUFFER,      0x0554
.set FILE_NAME_TEXT,        0x38f4
.set FILE_EMPTY_FLAGS,      0x3914
.set FILE_CORRUPT_FLAGS,    0x3917
.set FILE_SELECTED_SLOT,    0x3922
.set FILE_MENU_CURSOR,      0x3928
