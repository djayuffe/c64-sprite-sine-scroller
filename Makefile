.PHONY: all clean

ACME ?= acme
OUTPUT := build/v7g_gfxboost.prg
SOURCE := deepseek_asm_20251009_fixed_v7g_gfxboost.s

all: $(OUTPUT)

$(OUTPUT): $(SOURCE)
	@mkdir -p build
	$(ACME) --strict-segments -f cbm -o $@ $(SOURCE)

clean:
	rm -rf build
