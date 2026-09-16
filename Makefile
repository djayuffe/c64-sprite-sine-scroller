.PHONY: all clean

ACME ?= acme
OUTPUT := build/c64_sprite_sine_scroller.prg
SOURCE := c64_sprite_sine_scroller.s

all: $(OUTPUT)

$(OUTPUT): $(SOURCE)
	@mkdir -p build
	$(ACME) --strict-segments -f cbm -o $@ $(SOURCE)

clean:
	rm -rf build
