# -------------------------------------------------------------------------------
# The Legend of Zelda: Collector's Edition
#
#   Assemble this file to raw PowerPC bytes using "build.bat". It will wrap
#   the whole blob in a C0 "Execute ASM" Gecko code. The C0 body runs
#   continuously, but installs the menu hooks only after TWW has loaded.
#
#   Steps:
#     1. MAIN tracks whether the launcher or TWW code is loaded
#     2. It patches the launcher timer arming instruction
#     3. Once TWW is detected, it installs the menu and memory-card hooks
#     4. The hooks branch into restore_menus.asm (gecko code space)
#     5. If DEMO_SAVE_READY_HOOK unloads, MAIN waits for the launcher or TWW
#        to load again (i.e. a soft reset happened)
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Macros
# -------------------------------------------------------------------------------

.macro load reg, value
    lis \reg, \value@h
    ori \reg, \reg, \value@l
.endm

.macro call address
    load r12, \address
    mtctr r12
    bctrl
.endm

.macro jump address
    load r12, \address
    mtctr r12
    bctr
.endm

# gets address after blrl label (updates LR)
.macro getaddr reg, label
    bl \label
    mflr \reg
.endm

# opens/closes stack frame, save/restore LR through r0
.macro pushframe size
    stwu r1, -\size(r1)
    mflr r0
    stw r0, \size+4(r1)
.endm

.macro popframe size
    lwz r0, \size+4(r1)
    mtlr r0
    addi r1, r1, \size
.endm

.macro hook address, target
    .long \address, \target - PATCH_TABLE
.endm

.macro backupFull
    stwu r1, -0x100(r1)
    stw r0, 0x8C(r1)
    stw r2, 0x90(r1)
    stmw r3, 0x8(r1)
    mfcr r3
    stw r3, 0x7C(r1)
    mflr r3
    stw r3, 0x80(r1)
    mfctr r3
    stw r3, 0x84(r1)
    mfxer r3
    stw r3, 0x88(r1)
.endm

.macro restoreFull
    lwz r3, 0x7C(r1)
    mtcr r3
    lwz r3, 0x80(r1)
    mtlr r3
    lwz r3, 0x84(r1)
    mtctr r3
    lwz r3, 0x88(r1)
    mtxer r3
    lwz r0, 0x8C(r1)
    lwz r2, 0x90(r1)
    lmw r3, 0x8(r1)
    addi r1, r1, 0x100
.endm

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# build.ps1 supplies REGION_USA, REGION_JP, or REGION_PAL.
.ifdef REGION_JP
    .include "regions/jp.inc"
.else
    .ifdef REGION_PAL
        .include "regions/pal.inc"
    .else
        .include "regions/usa.inc"
    .endif
.endif

# SKIP SETTING TIMER
#   OLD | 54000632 | rlwinm r0, r0, 0, 24, 25 (000000c0)
#   NEW | 48000014 | b -> five instructions later
# Skips setting the timer used to simulate pressing the reset button.

.set LAUNCHER_TIMER_SET_OLD, 0x54000632
.set LAUNCHER_TIMER_ARM_NEW, 0x48000014
.set LAUNCHER_CHECK_ADDR,    LAUNCHER_TIMER_SET_ADDR - 4
.set LOADED_GAME_LAUNCHER,   0x880430e3
.set LOADED_GAME_TWW_DEMO,   0x28050000
.set MEMCPY,                 0x80003490

# ---------------------------------------------------------------------------
# Skips ahead to the main logic.......
# ---------------------------------------------------------------------------

PAYLOAD_START:
    b MAIN

# ---------------------------------------------------------------------------
# Code to inject into TWW (after TWW launches)
# ---------------------------------------------------------------------------

.include "restore_menus.asm" # bring in the menu restoration code

PATCH_TABLE_ADDR:
    blrl

# entries contain a hook and target offset from PATCH_TABLE
PATCH_TABLE:
    #    ---------------------------------------
    #    HOOK                   LABEL
    #    ---------------------------------------
    hook COLLECT_HOOK,          COLLECT_ACTION
    hook ITEM_HOOK,             ITEM_SAVE_ACTION
    hook NAME_HOOK,             NAME_SCENE_INIT
    hook DEMO_SAVE_DATA_HOOK,   DEMO_SAVE_DATA
    hook DEMO_SAVE_READY_HOOK,  DEMO_SAVE_READY
    hook NAME_NEW_FILE_HOOK,    NAME_NEW_FILE
    hook SAVE_NEW_FILE_HOOK,    SAVE_NEW_FILE
    hook MEMCARD_HOOK,          MEMCARD_UPDATE
.ifndef REGION_JP
    hook FILE_HOOK,             FILE_SLOT_RENDER
    hook FILE_EMPTY_TEXT_HOOK,  FILE_EMPTY_TEXT
.endif
    hook FILE_RIGHT_HOOK,       FILE_MENU_RIGHT
    hook FILE_LEFT_HOOK,        FILE_MENU_LEFT
PATCH_TABLE_END:

# STATE VARIABLES
# Used to make sure things get written where they should, when they should!

.set STATE_VAR_MAGIC,              0x00
.set STATE_VAR_STATE,              0x04
.set STATE_VAR_HOOK_NEW_INST,      0x08
.set STATE_VAR_DEMO_DATA,          0x0c

.set STATE_MAGIC_WORD,             0x54575721 # "TWW!"

.set STATE_NOT_INITIALIZED,        0     # not initialized yet
.set STATE_WAITING_FOR_LAUNCHER,   1     # initialized, waiting for launcher
.set STATE_LAUNCHER_DETECTED,      2     # launcher detected
.set STATE_WAITING_FOR_TWW,        3     # waiting for detection of TWW
.set STATE_TWW_DETECTED,           4     # TWW detected
.set STATE_TWW_PATCHED,            5     # TWW patched

STATE_VARS:
    blrl
    .long 0x00000000 # 0x00 magic
    .long 0x00000000 # 0x04 state
    .long 0x00000000 # 0x08 DEMO_SAVE_DATA_HOOK instruction
    .long 0x00000000 # 0x0c loaded demo preset slots

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
# Entry point. Gecko handler calls every handler cycle.
# ---------------------------------------------------------------------------
MAIN:
    # ------ backup registers
    backupFull

    # ------ get state variables
    getaddr r20, STATE_VARS

    # ------ check magic
    load r21, STATE_MAGIC_WORD
    lwz r22, STATE_VAR_MAGIC(r20)
    cmplw r22, r21
    beq MAIN_MAGIC_GOOD
    b MAIN_MAGIC_BAD

MAIN_MAGIC_GOOD:
    # ------ magic is good, state machine dispatch
    lwz r30, STATE_VAR_STATE(r20)

    # [0] ------ STATE_NOT_INITIALIZED
    cmpwi r30, STATE_NOT_INITIALIZED
    beq MAIN_STATE_NOT_INITIALIZED

    # [1] ------ STATE_WAITING_FOR_LAUNCHER
    cmpwi r30, STATE_WAITING_FOR_LAUNCHER
    beq MAIN_STATE_WAITING_FOR_LAUNCHER

    # [2] ------ STATE_LAUNCHER_DETECTED
    cmpwi r30, STATE_LAUNCHER_DETECTED
    beq MAIN_STATE_LAUNCHER_DETECTED

    # [3] ------ STATE_WAITING_FOR_TWW
    cmpwi r30, STATE_WAITING_FOR_TWW
    beq MAIN_STATE_WAITING_FOR_TWW

    # [4] ------ STATE_TWW_DETECTED
    cmpwi r30, STATE_TWW_DETECTED
    beq MAIN_STATE_TWW_DETECTED

    # [5] ------ STATE_TWW_PATCHED
    cmpwi r30, STATE_TWW_PATCHED
    beq MAIN_STATE_TWW_PATCHED

    # ------ UNKNOWN STATE, just exit
    b MAIN_ESCAPE

MAIN_STATE_NOT_INITIALIZED:
    # ------ calculate hook used to detect a reload (DEMO_SAVE_READY_HOOK)
    getaddr r4, PATCH_TABLE_ADDR
    addi r4, r4, DEMO_SAVE_READY - PATCH_TABLE
    load r3, DEMO_SAVE_READY_HOOK
    bl MAKE_BRANCH_INSTRUCTION
    stw r3, STATE_VAR_HOOK_NEW_INST(r20)
    # ------ update we are at new state
    li r3, STATE_WAITING_FOR_LAUNCHER
    stw r3, STATE_VAR_STATE(r20)
    b MAIN_ESCAPE

MAIN_STATE_WAITING_FOR_LAUNCHER:
    # ------ check if the launcher is currently loaded
    load r21, LAUNCHER_CHECK_ADDR
    lwz r22, 0(r21)
    load r23, LOADED_GAME_LAUNCHER
    cmpw r22, r23
    beq MAIN_LAUNCHER_FOUND
    b MAIN_ESCAPE

MAIN_LAUNCHER_FOUND:
    # ------ launcher detected
    li r3, STATE_LAUNCHER_DETECTED
    stw r3, STATE_VAR_STATE(r20)
    b MAIN_ESCAPE

MAIN_STATE_LAUNCHER_DETECTED:
    # ------ patch the launcher's timer-arming
    # ------ instruction if it is still vanilla
    load r21, LAUNCHER_TIMER_SET_ADDR
    lwz r22, 0(r21)
    load r23, LAUNCHER_TIMER_SET_OLD
    cmpw r22, r23
    beq MAIN_STATE_LAUNCHER_WRITE_TIMER_PATCH

    # ------ already patched is also valid
    load r23, LAUNCHER_TIMER_ARM_NEW
    cmpw r22, r23
    beq MAIN_STATE_LAUNCHER_TIMER_PATCHED

    # ------ neither old nor new means our assumptions are wrong
    b SOMETHING_IS_WRONG_CLEAR_MAGIC

MAIN_STATE_LAUNCHER_WRITE_TIMER_PATCH:
    load r23, LAUNCHER_TIMER_ARM_NEW
    stw r23, 0(r21)

MAIN_STATE_LAUNCHER_TIMER_PATCHED:
    # ------ clear cache for the patched launcher instruction
    load r3, LAUNCHER_TIMER_SET_ADDR
    li r4, 4
    bl FLUSH_CODE_RANGE

    # ------ wait for TWW to replace the launcher
    li r3, STATE_WAITING_FOR_TWW
    stw r3, STATE_VAR_STATE(r20)
    b MAIN_ESCAPE

MAIN_STATE_WAITING_FOR_TWW:
    # ------ check if patched launcher got replaced with unpatched launcher
    load r21, LAUNCHER_CHECK_ADDR
    lwz r22, 0(r21)
    load r23, LOADED_GAME_LAUNCHER
    cmpw r22, r23
    bne MAIN_CHECK_TWW

    load r21, LAUNCHER_TIMER_SET_ADDR
    lwz r22, 0(r21)
    load r23, LAUNCHER_TIMER_ARM_NEW
    cmpw r22, r23
    bne MAIN_LAUNCHER_FOUND
    b MAIN_ESCAPE

MAIN_CHECK_TWW:
    # ------ check if the TWW demo is currently loaded
    load r21, LOADED_GAME_CHECK_ADDR
    lwz r22, 0(r21)
    load r23, LOADED_GAME_TWW_DEMO
    cmpw r22, r23
    bne MAIN_ESCAPE

    # ------ TWW detected
    li r3, STATE_TWW_DETECTED
    stw r3, STATE_VAR_STATE(r20)
    b MAIN_ESCAPE

MAIN_STATE_TWW_DETECTED:
    # ------ install menu/memcard hooks
    bl INSTALL_TWW_PATCHES

    # ------ TWW is patched
    li r3, STATE_TWW_PATCHED
    stw r3, STATE_VAR_STATE(r20)
    b MAIN_ESCAPE

MAIN_STATE_TWW_PATCHED:
    # ------ if DEMO_SAVE_READY_HOOK disappears, wait for the next game load
    load r21, DEMO_SAVE_READY_HOOK
    lwz r22, 0(r21)
    lwz r23, STATE_VAR_HOOK_NEW_INST(r20)
    cmpw r22, r23
    beq MAIN_STATE_WAITING_FOR_LAUNCHER
    li r3, STATE_WAITING_FOR_TWW
    stw r3, STATE_VAR_STATE(r20)
    b MAIN_ESCAPE

MAIN_MAGIC_BAD:
    # ------ initialize the state machine
    li r10, 0x0000
    stw r10, STATE_VAR_MAGIC(r20)
    stw r10, STATE_VAR_STATE(r20)
    stw r10, STATE_VAR_HOOK_NEW_INST(r20)
    # ------ set magic
    load r10, STATE_MAGIC_WORD
    stw r10, STATE_VAR_MAGIC(r20)
    # ------ finish for now
    b MAIN_ESCAPE

MAIN_ESCAPE:
    restoreFull
    blr

SOMETHING_IS_WRONG_CLEAR_MAGIC:
    # ------ wtf happened. clear magic so the state machine can reinitialize
    getaddr r20, STATE_VARS
    li r10, 0x0000
    stw r10, STATE_VAR_MAGIC(r20)
    b MAIN_ESCAPE

# ---------------------------------------------------------------------------
# Installs the TWW menu and memcard hooks.
# ---------------------------------------------------------------------------
INSTALL_TWW_PATCHES:
    pushframe 0x20
    stw r29, 0x14(r1)
    stw r30, 0x18(r1)
    stw r31, 0x1c(r1)

    # ------ get the table and number of hooks
    getaddr r31, PATCH_TABLE_ADDR
    mr r29, r31
    li r30, (PATCH_TABLE_END - PATCH_TABLE) / 8

install_patch_loop:
    # ------ hook: TWW, target: code in this C0 blob
    lwz r3, 0(r29)
    lwz r4, 4(r29)
    add r4, r4, r31
    bl MAKE_BRANCH_INSTRUCTION
    lwz r4, 0(r29)
    stw r3, 0(r4)

    # ------ clear cache for the patched instruction
    mr r3, r4
    li r4, 4
    bl FLUSH_CODE_RANGE
    addi r29, r29, 8
    addic. r30, r30, -1
    bne install_patch_loop

    # ------ skip overwriting the loaded player name with Link
    # ------
    # ------ NOTE: if you don't want this functionality, you
    # ------       can just comment it out / remove it. (everything
    # ------       between the lines of pound signs) It does
    # ------       have the side effect of being called the file
    # ------       name, so it might be undesirable to some.

    # START RENAME DISABLE ##################################################
    load r3, NAME_SET_LINK_CALL
    lis r4, 0x6000 # nop
    stw r4, 0(r3)
    li r4, 4
    bl FLUSH_CODE_RANGE
    # END RENAME DISABLE ####################################################

    lwz r29, 0x14(r1)
    lwz r30, 0x18(r1)
    lwz r31, 0x1c(r1)
    popframe 0x20
    blr

# ---------------------------------------------------------------------------
# Builds a PowerPC relative branch instruction (b).
#   r3 = hook address
#   r4 = target address
# Returns:
#   r3 = encoded branch instruction
# ---------------------------------------------------------------------------
MAKE_BRANCH_INSTRUCTION:
    subf r6, r3, r4
    load r7, 0x03FFFFFC
    and r6, r6, r7
    load r7, 0x48000000
    or r3, r7, r6
    blr

# ---------------------------------------------------------------------------
# Instruction/data cache maintenance so patched functions work post-patch.
#   r3 = start address
#   r4 = byte size
# ---------------------------------------------------------------------------
FLUSH_CODE_RANGE:
    add r5, r3, r4
    rlwinm r6, r3, 0, 0, 26

flush_data_loop:
    dcbst 0, r6
    addi r6, r6, 0x20
    cmplw r6, r5
    blt flush_data_loop

    sync
    rlwinm r6, r3, 0, 0, 26

flush_instruction_loop:
    icbi 0, r6
    addi r6, r6, 0x20
    cmplw r6, r5
    blt flush_instruction_loop

    sync
    isync
    blr
PAYLOAD_END:
