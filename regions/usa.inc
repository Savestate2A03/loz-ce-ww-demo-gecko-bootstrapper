# ---------------------------------------------------------------------------
# Collector's Edition USA (PZLE01)
# ---------------------------------------------------------------------------

.set LAUNCHER_TIMER_SET_ADDR,   0x80032b2c
.set LOADED_GAME_CHECK_ADDR,    0x802ba8d0

# TWW hook and return addresses
.set COLLECT_HOOK,              0x801a4efc
.set COLLECT_OTHER,             0x801a4f0c
.set COLLECT_CONTINUE,          0x801a4f48
.set ITEM_HOOK,                 0x801cee68
.set ITEM_OTHER,                0x801cee6c
.set ITEM_CONTINUE,             0x801cf67c
.set NAME_HOOK,                 0x8022b9ac
.set NAME_CONTINUE,             0x8022b9bc
.set NAME_SET_LINK_CALL,        0x8022d360
.set DEMO_SAVE_DATA_HOOK,       0x8022d944
.set DEMO_SAVE_COPY,            0x8022d948
.set DEMO_SAVE_READY_HOOK,      0x8022d974
.set DEMO_SAVE_RETURN,          0x8022d984
.set NAME_NEW_FILE_HOOK,        0x8022c9f0
.set NAME_NEW_FILE_WRITE,       0x8022ca50
.set SAVE_NEW_FILE_HOOK,        0x801d7a3c
.set SAVE_NEW_FILE_WRITE,       0x801d7a9c
.set MEMCARD_HOOK,              0x80018ed0
.set FILE_HOOK,                 0x8018b6d0
.set FILE_EMPTY_LAYOUT,         0x8018b6d4
.set FILE_EMPTY_TEXT_HOOK,      0x8018b76c
.set FILE_CONTINUE,             0x8018b890
.set FILE_RIGHT_HOOK,           0x80182650
.set FILE_RIGHT_CHECK,          0x80182654
.set FILE_RIGHT_CONTINUE,       0x8018266c
.set FILE_LEFT_HOOK,            0x801826d4
.set FILE_LEFT_CHECK,           0x801826d8
.set FILE_LEFT_CONTINUE,        0x801826f0

# TWW functions and variables
.set SAVE_INITIALIZE,           0x801d5880
.set OPTION_INITIALIZE,         0x801d4888
.set MEMCARD_GET_STATUS,        0x80019298
.set RESET_FLAG,                0x803a17e0
.set OS_LOCK_MUTEX,             0x803019c0
.set OS_UNLOCK_MUTEX,           0x80301a9c
.set OS_SIGNAL_COND,            0x80301d84
.set EXI_PROBE,                 0x80305f68
.set STRCPY,                    0x80329788

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

.set file_offset, 26
.set file_menu,   27
.set file_pane,   28
.set file_data,   29
.set file_slot,   30
