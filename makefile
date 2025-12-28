CLIPS_VER     := 6.4.2
ARCHIVE       := clips_core_source_642.tar.gz
ARCHIVE_URL   := https://sourceforge.net/projects/clipsrules/files/CLIPS/$(CLIPS_VER)/$(ARCHIVE)
BUILD_DIR     := vendor/clips

all: $(BUILD_DIR)
	cp userfunctions.c vendor/clips
	$(MAKE) -C $(BUILD_DIR)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)
	[ -f $(ARCHIVE) ] || wget -O $(ARCHIVE) "$(ARCHIVE_URL)"
	tar --strip-components=2 -xvf $(ARCHIVE) -C $(BUILD_DIR)

test: all
	./vendor/clips/clips -f2 ./test.bat

clean:
	rm -r $(BUILD_DIR)
