# -------------------------------------------------------------------------------
# The Legend of Zelda: Collector's Edition USA
#
#   Assemble this whole file to raw PowerPC bytes using the "assemble.bat" file
#   it will wrap the whole blob in a C0 "Execute ASM" Gecko code. The C0 body
#   runs continuously, but only install the hook once.
#
#   Steps:
#     1. MAIN runs a state machine keyed from LOADED_GAME_CHECK_ADDR
#     2. It patches the launcher timer arming instruction
#     3. Once TWW is detected, it reads the instruction at TWW_HOOK_ADDR
#     4. It writes that instruction into HOOK_NOP_REPLACE
#     5. It overwrites TWW_HOOK_ADDR with "bl GECKO_HOOK"
#     6. GECKO_HOOK runs your code, restores CPU state, executes the copied
#        original instruction, then blrs to TWW_HOOK_ADDR + 4
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Configure before assembling:
#   TWW_HOOK_ADDR - TWW instruction address to replace with bl to GECKO_HOOK_ADDR
# -------------------------------------------------------------------------------
.set TWW_HOOK_ADDR, 0x8000af80 # placeholder for testing = 0x8000af80, apparently
                               # runs ~once per frame. if unedited, placeholder
                               # code does nothing in various ways

# -------------------------------------------------------------------------------
# Hook restrictions:
#   The replaced instruction is copied into this C0 blob. Do not hook a relative
#   branch/call, mflr, mtlr, bctr/bctrl, blr, or an instruction whose behavior
#   depends on its original PC/LR placement unless you rewrite the logic for that
#   specific instruction.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Macros
# -------------------------------------------------------------------------------

.macro load reg, value
    lis \reg, \value@h
    ori \reg, \reg, \value@l
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
# Skips ahead to the main logic.......
# ---------------------------------------------------------------------------

b MAIN

# ---------------------------------------------------------------------------
# Code to inject into TWW (after TWW launches)
# ---------------------------------------------------------------------------

GECKO_HOOK_ADDR:
    blrl

GECKO_HOOK:
    backupFull

    # --------------
    # your code here
    # --------------

    ori r4, r4, 0x0000
    addi r5, r5, 0x0000
    mr r6, r6
    nop
    nop
    nop # just example for now
    nop
    nop
    ori r14, r14, 0x0000
    addi r15, r15, 0x0000
    mr r16, r16

    restoreFull
    b HOOK_NOP_REPLACE

HOOK_NOP_REPLACE_ADDR:
    blrl

HOOK_NOP_REPLACE:
    # ------ this nop gets replaced by whatever was
    # ------ originally at TWW_HOOK_ADDR
    nop

    blr

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# CHECK WHAT GAME IS CURRENTLY LOADED, DEPENDING ON WHAT INSTRUCTIONS EXIST
# IN THIS SELECTED LOCATION (it is completely arbitrary). Used to gate
# what code runs where, in addition to the state management.

.set LOADED_GAME_CHECK_ADDR,       0x802ba8d0
.set LOADED_GAME_LAUNCHER,         0x3e3a3633
.set LOADED_GAME_TWW_DEMO,         0x28050000

# SKIP SETTING TIMER: Original @ 0x80032b2c
#   OLD | 54000632 | rlwinm r0, r0, 0, 24, 25 (000000c0)
#   NEW | 48000014 | b -> 0x80032b40
#
# Jumps to 0x80032b40
# 
# Skips setting the timer variable that OSGetResetButtonState reads to
# know when to simulate pressing the console's reset button.

.set LAUNCHER_TIMER_SET_ADDR,      0x80032b2c
.set LAUNCHER_TIMER_SET_OLD,       0x54000632
.set LAUNCHER_TIMER_ARM_NEW,       0x48000014

# STATE VARIABLES
# Used to make sure things get written where they should, when they should!

.set STATE_VAR_MAGIC,              0x00
.set STATE_VAR_STATE,              0x04
.set STATE_VAR_HOOK_OLD_INST,      0x08
.set STATE_VAR_HOOK_NEW_INST,      0x0c
.set STATE_VAR_GECKO_CODE_ADDR,    0x10

.set STATE_MAGIC_WORD,             0x54575721 # "TWW!"

.set STATE_NOT_INITIALIZED,        0     # not initialized yet
.set STATE_WAITING_FOR_LAUNCHER,   1     # initialized, waiting for launcher
.set STATE_LAUNCHER_DETECTED,      2     # launcher detected
.set STATE_LAUNCHER_PATCHED,       3     # launcher patched
.set STATE_WAITING_FOR_TWW,        4     # waiting for detection of TWW
.set STATE_TWW_DETECTED,           5     # TWW detected
.set STATE_TWW_PATCHED,            6     # TWW patched

STATE_VARS:
    blrl
    .long 0x00000000 # 0x00 magic
    .long 0x00000000 # 0x04 state
    .long 0x00000000 # 0x08 hook old instruction
    .long 0x00000000 # 0x0C hook new instruction
    .long 0x00000000 # 0x10 address of GECKO_HOOK

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# Entry point. Gecko handler calls every handler cycle.
MAIN:
    # ------ backup registers
    backupFull

    # ------ get state variables
    bl STATE_VARS 
    mflr r20

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

    # [3] ------ STATE_LAUNCHER_PATCHED
    cmpwi r30, STATE_LAUNCHER_PATCHED
    beq MAIN_STATE_LAUNCHER_PATCHED

    # [4] ------ STATE_WAITING_FOR_TWW
    cmpwi r30, STATE_WAITING_FOR_TWW
    beq MAIN_STATE_WAITING_FOR_TWW

    # [5] ------ STATE_TWW_DETECTED
    cmpwi r30, STATE_TWW_DETECTED
    beq MAIN_STATE_TWW_DETECTED

    # [6] ------ STATE_TWW_PATCHED
    cmpwi r30, STATE_TWW_PATCHED
    beq MAIN_STATE_TWW_PATCHED

    # ------ UNKNOWN STATE, just exit
    b MAIN_ESCAPE

MAIN_STATE_NOT_INITIALIZED:
    # ------ fill in state variables via calculations
    bl GECKO_HOOK_ADDR
    mflr r4
    stw r4, STATE_VAR_GECKO_CODE_ADDR(r20)
    load r3, TWW_HOOK_ADDR
    li r5, 1
    # ------ hook: TWW, target: GECKO, b/bl?: bl
    bl MAKE_BRANCH_INSTRUCTION
    stw r3, STATE_VAR_HOOK_NEW_INST(r20)
    # ------ update we are at new state
    li r3, STATE_WAITING_FOR_LAUNCHER
    stw r3, STATE_VAR_STATE(r20)
    b MAIN_ESCAPE

MAIN_STATE_WAITING_FOR_LAUNCHER:
    # ------ check if the launcher is currently loaded
    load r21, LOADED_GAME_CHECK_ADDR
    lwz r22, 0(r21)
    load r23, LOADED_GAME_LAUNCHER
    cmpw r22, r23
    bne MAIN_ESCAPE

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
    li r3, STATE_LAUNCHER_PATCHED
    stw r3, STATE_VAR_STATE(r20)
    b MAIN_STATE_LAUNCHER_PATCHED

MAIN_STATE_LAUNCHER_PATCHED:
    # ------ clear cache for the patched launcher instruction
    load r3, LAUNCHER_TIMER_SET_ADDR
    li r4, 4
    bl FLUSH_CODE_RANGE

    # ------ wait for TWW to replace the launcher
    li r3, STATE_WAITING_FOR_TWW
    stw r3, STATE_VAR_STATE(r20)
    b MAIN_ESCAPE

MAIN_STATE_WAITING_FOR_TWW:
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
    # ------ capture the live instruction at the TWW hook site
    load r21, TWW_HOOK_ADDR
    lwz r22, 0(r21)
    stw r22, STATE_VAR_HOOK_OLD_INST(r20)

    # ------ write the displaced instruction into the end-nop first
    bl HOOK_NOP_REPLACE_ADDR
    mflr r23
    stw r22, 0(r23)
    mr r3, r23
    li r4, 4
    bl FLUSH_CODE_RANGE

    # ------ install the TWW hook
    lwz r24, STATE_VAR_HOOK_NEW_INST(r20)
    stw r24, 0(r21)
    mr r3, r21
    li r4, 4
    bl FLUSH_CODE_RANGE

    # ------ TWW is patched
    li r3, STATE_TWW_PATCHED
    stw r3, STATE_VAR_STATE(r20)
    b MAIN_ESCAPE

MAIN_STATE_TWW_PATCHED:
    # ------ if the hook disappears, assume reset/reload and reinitialize
    load r21, TWW_HOOK_ADDR
    lwz r22, 0(r21)
    lwz r23, STATE_VAR_HOOK_NEW_INST(r20)
    cmpw r22, r23
    beq MAIN_ESCAPE
    b MAIN_MAGIC_BAD

MAIN_MAGIC_BAD:
    # ------ initialize the state machine
    li r10, 0x0000
    stw r10, STATE_VAR_MAGIC(r20)
    stw r10, STATE_VAR_STATE(r20)
    stw r10, STATE_VAR_HOOK_OLD_INST(r20)
    stw r10, STATE_VAR_HOOK_NEW_INST(r20)
    stw r10, STATE_VAR_GECKO_CODE_ADDR(r20)
    # ------ set magic
    load r10, STATE_MAGIC_WORD
    stw r10, STATE_VAR_MAGIC(r20)
    # ------ finish for now
    b MAIN_ESCAPE

MAIN_ESCAPE:
    restoreFull
    blr

SOMETHING_IS_WRONG_CLEAR_MAGIC:
    # ------ wtf happened
    bl STATE_VARS 
    mflr r20
    li r10, 0x0000
    stw r10, STATE_VAR_MAGIC(r20)
    b MAIN_ESCAPE    

# ---------------------------------------------------------------------------
# Builds a PowerPC relative branch instruction.
#   r3 = hook address
#   r4 = target address
#   r5 = 0 for b, non-zero for bl
# Returns:
#   r3 = encoded branch instruction
# ---------------------------------------------------------------------------
MAKE_BRANCH_INSTRUCTION:
    subf r6, r3, r4
    load r7, 0x03FFFFFC
    and r6, r6, r7
    load r7, 0x48000000
    or r3, r7, r6
    cmpwi r5, 0
    beq make_branch_done
    ori r3, r3, 1
make_branch_done:
    blr

# ---------------------------------------------------------------------------
# Instruction/data cache maintenance so patched functions work post-
# patch.
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
