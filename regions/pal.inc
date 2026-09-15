# ---------------------------------------------------------------------------
# Collector's Edition PAL (PZLP01)
# ---------------------------------------------------------------------------

.set LAUNCHER_TIMER_SET_ADDR,   0x800330cc
.set LOADED_GAME_CHECK_ADDR,    0x802c36b0

# TWW hook and return addresses
.set COLLECT_HOOK,              0x801ab95c
.set COLLECT_OTHER,             0x801ab96c
.set COLLECT_CONTINUE,          0x801ab9a8
.set ITEM_HOOK,                 0x801d5d8c
.set ITEM_OTHER,                0x801d5d90
.set ITEM_CONTINUE,             0x801d65a0
.set NAME_HOOK,                 0x80233ce0
.set NAME_CONTINUE,             0x80233cf0
.set NAME_SET_LINK_CALL,        0x802360a0
.set DEMO_SAVE_DATA_HOOK,       0x80236684
.set DEMO_SAVE_COPY,            0x80236688
.set DEMO_SAVE_READY_HOOK,      0x802366b4
.set DEMO_SAVE_RETURN,          0x802366c4
.set NAME_NEW_FILE_HOOK,        0x80235680
.set NAME_NEW_FILE_WRITE,       0x802356e0
.set SAVE_NEW_FILE_HOOK,        0x801de960
.set SAVE_NEW_FILE_WRITE,       0x801de9c0
.set MEMCARD_HOOK,              0x80018ec4
.set FILE_HOOK,                 0x80190828
.set FILE_EMPTY_LAYOUT,         0x8019082c
.set FILE_EMPTY_TEXT_HOOK,      0x801908c4
.set FILE_CONTINUE,             0x80190afc
.set FILE_RIGHT_HOOK,           0x80186cdc
.set FILE_RIGHT_CHECK,          0x80186ce0
.set FILE_RIGHT_CONTINUE,       0x80186cf8
.set FILE_LEFT_HOOK,            0x80186d60
.set FILE_LEFT_CHECK,           0x80186d64
.set FILE_LEFT_CONTINUE,        0x80186d7c

# TWW functions and variables
.set SAVE_INITIALIZE,           0x801dc7a4
.set OPTION_INITIALIZE,         0x801db7ac
.set MEMCARD_GET_STATUS,        0x80019318
.set RESET_FLAG,                0x803ac000
.set OS_LOCK_MUTEX,             0x8030a7a0
.set OS_UNLOCK_MUTEX,           0x8030a87c
.set OS_SIGNAL_COND,            0x8030ab64
.set EXI_PROBE,                 0x8030edb4
.set STRCPY,                    0x803325d4

# Menu structure offsets and setSaveData registers
.set COLLECT_MODE,          0x27fa
.set COLLECT_OPTIONS_MENU,  0x278c
.set COLLECT_SAVE_MENU,     0x2790
.set ITEM_MODE,             0x2406
.set NAME_MAIN_STATE,       0x05ec
.set NAME_CARD_STATE,       0x05ee
.set NAME_DRAW_STATE,       0x05ef
.set NAME_SAVE_BUFFER,      0x05f8
.set SAVE_SAVE_BUFFER,      0x058c
.set FILE_NAME_TEXT,        0x3c3c
.set FILE_EMPTY_FLAGS,      0x3c5c
.set FILE_CORRUPT_FLAGS,    0x3c5f
.set FILE_SELECTED_SLOT,    0x3c6a
.set FILE_MENU_CURSOR,      0x3c70

.set file_offset, 25
.set file_menu,   26
.set file_pane,   27
.set file_data,   28
.set file_slot,   29
