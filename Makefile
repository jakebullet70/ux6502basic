# Build MS BASIC 6502 targets with ca65/ld65 and check them against the original ROM dumps.
# Run from Git Bash: make [all|verify|clean|<target>]

CC65    ?= /c/8bitProgramming/cc65/bin
CA65    := $(CC65)/ca65
LD65    := $(CC65)/ld65
SRC     := src
BUILD   := build
ORIG    := ref/msbasic/orig

# Targets with an original ROM dump in $(ORIG)
VERIFY_TARGETS := cbmbasic1 cbmbasic2 kbdbasic osi kb9 applesoft microtan aim65 sym1
TARGETS := $(VERIFY_TARGETS) w65c816sxb

SOURCES := $(wildcard $(SRC)/*.s)

all: $(TARGETS)

$(TARGETS): %: $(BUILD)/%.bin

$(BUILD)/%.bin: $(SOURCES) $(SRC)/%.cfg | $(BUILD)
	$(CA65) -D $* $(SRC)/msbasic.s -o $(BUILD)/$*.o -l $(BUILD)/$*.lst
	$(LD65) -C $(SRC)/$*.cfg $(BUILD)/$*.o -o $@ -Ln $(BUILD)/$*.lbl

$(BUILD):
	mkdir -p $(BUILD)

# Print only mismatches; exit non-zero if any target differs from its ROM dump.
verify: $(addprefix $(BUILD)/,$(addsuffix .bin,$(VERIFY_TARGETS)))
	@fail=0; for t in $(VERIFY_TARGETS); do \
	  cmp -s $(BUILD)/$$t.bin $(ORIG)/$$t.bin || { echo "DIFF $$t"; fail=1; }; \
	done; [ $$fail = 0 ] && echo "verify: all $(words $(VERIFY_TARGETS)) targets match"

clean:
	rm -rf $(BUILD)

.PHONY: all verify clean $(TARGETS)
