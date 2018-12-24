CORES := 8
TUNE_CPU := core2 
PREFIX = $(CURDIR)/prefix

export PATH := $(PREFIX)/bin:$(PATH)
export PKG_CONFIG_PATH := $(PREFIX)/lib/pkgconfig:$(PKG_CONFIG_PATH)

DEPS=$(CURDIR)/dependencies.stamp

NASM=$(PREFIX)/bin/nasm
YASM=$(PREFIX)/bin/yasm
X264=$(PREFIX)/lib/libx264.a

$(PREFIX):
	mkdir -p "$@"

$(DEPS): $(PREFIX)
	echo 'Grabbing dependencies'
	sudo apt-get -y install \
	  autoconf \
	  automake \
	  build-essential \
	  cmake \
	  git-core \
	  libtool \
	  pkg-config \
	  texinfo \
	  wget
	touch "$@"

NASM_DIR := nasm-2.13.03
$(NASM_DIR)/config.status: $(DEPS) $(NASM_DIR).tar.bz2
	rm -rf $(NASM_DIR) 
	tar xf $(NASM_DIR).tar.bz2
	cd $(NASM_DIR) && \
		./autogen.sh && \
		CFLAGS='-mtune=native' ./configure "--prefix=$(PREFIX)"
$(NASM): $(PREFIX) $(NASM_DIR)/config.status
	$(MAKE) -C $(NASM_DIR) -j $(CORES) || $(MAKE) -C $(NASM_DIR)
	$(MAKE) -C $(NASM_DIR) install	

YASM_DIR := yasm-1.3.0
$(YASM_DIR)/config.status: $(DEPS) $(YASM_DIR).tar.gz 
	rm -rf $(YASM_DIR)
	tar xf $(YASM_DIR).tar.gz
	cd $(YASM_DIR) && \
		CFLAGS='-mtune=native' ./configure "--prefix=$(PREFIX)" --disable-dependency-tracking
$(YASM): $(PREFIX) $(YASM_DIR)/config.status
	$(MAKE) -C $(YASM_DIR) -j $(CORES) || $(MAKE) -C $(YASM_DIR)
	$(MAKE) -C $(YASM_DIR) install	

X264_DIR := $(CURDIR)/libx264
$(X264_DIR)/config.status: $(DEPS) $(YASM) $(NASM)
	cd $(X264_DIR) && \
		./configure "--prefix=$(PREFIX)" --enable-static --disable-dynamic --enable-pic "--extra-cflags=-mtune=$(TUNE_CPU)" --bit-depth=all --chroma-format=all --enable-lto
$(X264): $(X264_DIR)/config.h
	$(MAKE) -C $(X264_DIR) -j $(CORES) || $(MAKE) -C $(X264_DIR)
	$(MAKE) -C $(X264_DIR) install	
	

all: $(X264) 

clean:
	rm -rf $(NASM_DIR)
	rm -rf $(YASM_DIR)
	rm -rf $(PREFIX)

.PHONY: all clean
#.SILENT:
.DEFAULT_GOAL := all
