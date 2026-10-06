.segment "EXTRA"

.ifdef CONFIG_CBM1_PATCHES
.include "cbm1_patches.s"
.endif

.ifdef SIM
.include "sim_extra.s"
.endif

.ifdef CONFIG_HANDLE_IO
.include "handle_io.s"
.endif

.ifdef CONFIG_BLOCK
.include "block.s"
.endif

.ifdef CONFIG_INSTR
.include "instr.s"
.endif

.ifdef CONFIG_HEXBIN
.include "hexbin.s"
.endif

.ifdef CONFIG_RPT
.include "rpt.s"
.endif

.ifdef CONFIG_MOD
.include "mod.s"
.endif

.ifdef CONFIG_GOTO_CACHE
.include "gotocache.s"
.endif

.ifdef CONFIG_VAR_CACHE
.include "varcache.s"
.endif
