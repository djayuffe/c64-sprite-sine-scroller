.PHONY: all clean

ACME ?= acme
OUTPUT := build/deepseek_c64_v7g.prg
SOURCE := deepseek_c64_v7g.s

all: $(OUTPUT)

$(OUTPUT): $(SOURCE)
	@mkdir -p build
	$(ACME) --strict-segments -f cbm -o $@ $(SOURCE)

clean:
	rm -rf build
