# ---------------------------------------------------------------------------
# Restores menus/saving in the TWW demo.
# Based on SuperDude88's Restore Saving code, and my notes in restore-saving.txt
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Allows opening "Options" and "Save" from dMenu_Collect_c::_move().
#   r0 = selected entry (6 for Options, 7 for Save)
#   r31 = dMenu_Collect_c instance
# ---------------------------------------------------------------------------
COLLECT_ACTION:
    cmplwi r0, 6
    bne COLLECT_CHECK_SAVE
    li r0, 4
    stb r0, COLLECT_MODE(r31)
    lwz r3, COLLECT_OPTIONS_MENU(r31)
    call OPTION_INITIALIZE
    jump COLLECT_CONTINUE
COLLECT_CHECK_SAVE:
    cmplwi r0, 7
    bne COLLECT_OTHER_ACTION
    li r0, 3
    stb r0, COLLECT_MODE(r31)
    lwz r3, COLLECT_SAVE_MENU(r31) # Save menu instance
    call SAVE_INITIALIZE
    jump COLLECT_CONTINUE
COLLECT_OTHER_ACTION:
    jump COLLECT_OTHER

# ---------------------------------------------------------------------------
# Allows opening "Save" from dMenu_Item_c::_move().
#   CR0 = result of comparing the selected entry with 0x15
#   r31 = dMenu_Item_c instance
# ---------------------------------------------------------------------------
ITEM_SAVE_ACTION:
    bne ITEM_OTHER_ACTION
    li r0, 1
    stb r0, ITEM_MODE(r31)
    lwz r3, 0x2330(r31)
    call SAVE_INITIALIZE
    jump ITEM_CONTINUE
ITEM_OTHER_ACTION:
    jump ITEM_OTHER

# ---------------------------------------------------------------------------
# Runs the original demo loader before the restored memcard checks.
#   r31 = dScnName_c instance (scene type @ +0x8)
# ---------------------------------------------------------------------------
NAME_SCENE_INIT:
    lha r3, 8(r31)
    cmpwi r3, 13
    li r3, 14 # ShopDemoDataLoad -> ShopDemoDataSet
    li r0, 4
    bne NAME_SET_STATES
    li r3, 10 # extra-save scene
    li r0, 3
NAME_SET_STATES:
    stb r3, NAME_MAIN_STATE(r31)
    stb r0, NAME_DRAW_STATE(r31)
    jump NAME_CONTINUE

# ---------------------------------------------------------------------------
# Keeps the presets loaded by dScnName_c::ShopDemoDataSet().
#   r4 = loaded demo save file
#   r31 = dScnName_c instance
# ---------------------------------------------------------------------------
DEMO_SAVE_DATA:
    addi r5, r4, 8
    getaddr r3, STATE_VARS
    stw r5, STATE_VAR_DEMO_DATA(r3)
    addi r3, r31, NAME_SAVE_BUFFER # replaced instruction
    jump DEMO_SAVE_COPY

# ---------------------------------------------------------------------------
# Enters the memcard checks after ShopDemoDataSet finishes loading.
#   r31 = dScnName_c instance
# ---------------------------------------------------------------------------
DEMO_SAVE_READY:
    li r0, 0
    stb r0, NAME_MAIN_STATE(r31)
    stb r0, NAME_CARD_STATE(r31)
    stb r0, NAME_DRAW_STATE(r31)
    jump DEMO_SAVE_RETURN

# ---------------------------------------------------------------------------
# Seeds a new memcard file from dScnName_c::MemCardMakeGameFileSel().
#   r31 = dScnName_c instance
# ---------------------------------------------------------------------------
NAME_NEW_FILE:
    addi r3, r31, NAME_SAVE_BUFFER
    bl COPY_DEMO_SAVES
    jump NAME_NEW_FILE_WRITE

# ---------------------------------------------------------------------------
# Seeds a new memcard file from dMenu_save_c::memCardMakeGameFileSel().
#   r31 = dMenu_save_c instance
# ---------------------------------------------------------------------------
SAVE_NEW_FILE:
    addi r3, r31, SAVE_SAVE_BUFFER
    bl COPY_DEMO_SAVES
    jump SAVE_NEW_FILE_WRITE

# ---------------------------------------------------------------------------
# Copies the three original save files.
#   r3 = destination save buffer
# Returns:
#   r3 = memcpy's return value
# ---------------------------------------------------------------------------
COPY_DEMO_SAVES:
    mflr r0
    getaddr r4, STATE_VARS
    lwz r4, STATE_VAR_DEMO_DATA(r4)
    li r5, 0x1650
    mtlr r0
    jump MEMCPY

# ---------------------------------------------------------------------------
# Restores mDoMemCd_Ctrl_c::update(), which is stubbed in the demo.
#   r3 = mDoMemCd_Ctrl_c instance
# ---------------------------------------------------------------------------
MEMCARD_UPDATE:
    pushframe 0x20
    stw r31, 0x1c(r1)
    mr r31, r3
    load r4, RESET_FLAG
    lwz r0, 0(r4)
    cmpwi r0, 0
    beq MEMCARD_CHECK_STATUS
    # status 3: resetting
    # command 5: detach
    li r4, 3
    li r5, 5
    b MEMCARD_COMMAND
MEMCARD_CHECK_STATUS:
    li r4, 0
    call MEMCARD_GET_STATUS
    cmplwi r3, 14
    beq MEMCARD_RETURN
    li r3, 0
    bl CARD_PROBE
    cmpwi r3, 0
    beq MEMCARD_CHECK_DETACH
    mr r3, r31
    li r4, 0
    call MEMCARD_GET_STATUS
    cmplwi r3, 0
    bne MEMCARD_CHECK_DETACH
    # status 0: inserted
    # command 4: attach
    li r4, 0
    li r5, 4
    b MEMCARD_COMMAND
MEMCARD_CHECK_DETACH:
    li r3, 0
    bl CARD_PROBE
    cmpwi r3, 0
    bne MEMCARD_RETURN
    mr r3, r31
    li r4, 0
    call MEMCARD_GET_STATUS
    cmplwi r3, 0
    beq MEMCARD_RETURN
    # status 1: removed
    # command 5: detach
    li r4, 1
    li r5, 5
MEMCARD_COMMAND:
    # ------ keep status/command across OSLockMutex
    stw r4, 8(r1)
    stw r5, 0xc(r1)
    addi r3, r31, 0x1664
    call OS_LOCK_MUTEX
    lwz r4, 8(r1)
    lwz r5, 0xc(r1)
    stb r4, 0x165a(r31)
    stw r5, 0x165c(r31)
    addi r3, r31, 0x1664
    call OS_UNLOCK_MUTEX
    addi r3, r31, 0x167c
    call OS_SIGNAL_COND
MEMCARD_RETURN:
    lwz r31, 0x1c(r1)
    popframe 0x20
    blr

# ---------------------------------------------------------------------------
# Probes a memcard slot unless bit 0x80 at 0x800030e3 disables it.
#   r3 = card slot
# Returns:
#   r3 = zero when probing is disabled, otherwise EXIProbe's result
# ---------------------------------------------------------------------------
CARD_PROBE:
    lis r4, 0x8000
    lbz r0, 0x30e3(r4)
    andi. r0, r0, 0x80
    beq CARD_PROBE_EXI
    li r3, 0
    blr
CARD_PROBE_EXI:
    jump EXI_PROBE

# Checks selected slot's empty flag
.macro checkemptyslot base, scratch
    lbz \scratch, FILE_SELECTED_SLOT(\base)
    add \scratch, \base, \scratch
    lbz r0, FILE_EMPTY_FLAGS(\scratch)
    cmplwi r0, 0
.endm

# ---------------------------------------------------------------------------
# Allows moving right onto Copy/Erase in dFile_select_c::menuSelect() if not empty.
#   r31 = dFile_select_c instance
# ---------------------------------------------------------------------------
FILE_MENU_RIGHT:
    checkemptyslot r31, r3
    beq FILE_MENU_RIGHT_DONE
    lbz r0, FILE_MENU_CURSOR(r31) # replaced instruction
    jump FILE_RIGHT_CHECK
FILE_MENU_RIGHT_DONE:
    jump FILE_RIGHT_CONTINUE

# ---------------------------------------------------------------------------
# Allows moving left onto Copy/Erase in dFile_select_c::menuSelect() if not empty.
#   r31 = dFile_select_c instance
# ---------------------------------------------------------------------------
FILE_MENU_LEFT:
    checkemptyslot r31, r3
    beq FILE_MENU_LEFT_DONE
    lbz r0, FILE_MENU_CURSOR(r31) # replaced instruction
    jump FILE_LEFT_CHECK
FILE_MENU_LEFT_DONE:
    jump FILE_LEFT_CONTINUE

.ifndef REGION_JP

# ---------------------------------------------------------------------------
# Restores labels in dFile_select_c::setSaveData().
#   file_offset = slot index * 4
#   file_menu = dFile_select_c instance
#   file_pane = slot pane
#   file_data = slot save data
#   file_slot = slot index
# ---------------------------------------------------------------------------
FILE_SLOT_RENDER:
    lbz r0, 0x157(file_data)
    cmplwi r0, 0
    bne FILE_OCCUPIED
    mr r3, file_pane # replaced instruction
    jump FILE_EMPTY_LAYOUT
FILE_EMPTY_TEXT:
    bl FILE_NEW_GAME_TEXT_END
FILE_NEW_GAME_TEXT:
    .asciz "New Game"
    .balign 4
FILE_NEW_GAME_TEXT_END:
    mflr r4
    add r3, file_menu, file_offset
    lwz r3, FILE_NAME_TEXT(r3)
    call STRCPY
    li r0, 1
    b FILE_FLAGS
FILE_OCCUPIED:
    add r3, file_menu, file_offset
    lwz r3, FILE_NAME_TEXT(r3)
    addi r4, file_data, 0x157
    call STRCPY
    li r0, 0
FILE_FLAGS:
    add r3, file_menu, file_slot
    stb r0, FILE_EMPTY_FLAGS(r3)
    li r0, 0
    stb r0, FILE_CORRUPT_FLAGS(r3)
    jump FILE_CONTINUE
.endif
