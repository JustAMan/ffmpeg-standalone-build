CORES := 8
TUNE_CPU := core2 
PREFIX = $(CURDIR)/prefix

export PATH := $(PREFIX)/bin:$(PATH)
export PKG_CONFIG_PATH := $(PREFIX)/lib/pkgconfig:$(PKG_CONFIG_PATH)

DEPS=$(CURDIR)/dependencies.stamp
TOOLS=$(CURDIR)/tools.stamp

NASM=$(PREFIX)/bin/nasm
YASM=$(PREFIX)/bin/yasm
LIBNUMA=$(PREFIX)/lib/libnuma.so
X264=$(PREFIX)/lib/libx264.so
X265=$(PREFIX)/lib/libx265.so
LIBVPX=$(PREFIX)/lib/libvpx.so
LAME=$(PREFIX)/lib/libmp3lame.so
OPUS=$(PREFIX)/lib/libopus.so
AOM=$(PREFIX)/lib/libaom.so

$(PREFIX):
	mkdir -p "$@"

$(DEPS): $(PREFIX)
	@echo Grabbing dependencies
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
	@echo Configuring nasm
	rm -rf $(NASM_DIR) 
	tar xf $(NASM_DIR).tar.bz2
	cd $(NASM_DIR) && \
		./autogen.sh && \
		CFLAGS='-mtune=native' ./configure "--prefix=$(PREFIX)"
$(NASM): $(PREFIX) $(NASM_DIR)/config.status
	@echo Building nasm
	$(MAKE) -C $(NASM_DIR) -j $(CORES) || $(MAKE) -C $(NASM_DIR)
	$(MAKE) -C $(NASM_DIR) install	

YASM_DIR := yasm-1.3.0
$(YASM_DIR)/config.status: $(DEPS) $(YASM_DIR).tar.gz 
	@echo Configuring yasm
	rm -rf $(YASM_DIR)
	tar xf $(YASM_DIR).tar.gz
	cd $(YASM_DIR) && \
		CFLAGS='-mtune=native' ./configure "--prefix=$(PREFIX)" --disable-dependency-tracking
$(YASM): $(PREFIX) $(YASM_DIR)/config.status
	@echo Building yasm
	$(MAKE) -C $(YASM_DIR) -j $(CORES) || $(MAKE) -C $(YASM_DIR)
	$(MAKE) -C $(YASM_DIR) install	

LIBNUMA_DIR := $(CURDIR)/libnuma
$(LIBNUMA_DIR)/config.status: $(DEPS) 
	@echo Configuring libnuma
	cd $(LIBNUMA_DIR) && \
		./autogen.sh && \
		CFLAGS="-mtune=$(TUNE_CPU)" ./configure "--prefix=$(PREFIX)" --disable-static --enable-shared
$(LIBNUMA): $(LIBNUMA_DIR)/config.status
	@echo Building libnuma 
	$(MAKE) -C $(LIBNUMA_DIR) -j $(CORES) || $(MAKE) -C $(LIBNUMA_DIR)
	$(MAKE) -C $(LIBNUMA_DIR) install

$(TOOLS): $(DEPS) $(YASM) $(NASM) $(LIBNUMA)
	touch "$@"

X264_DIR := $(CURDIR)/libx264
$(X264_DIR)/config.h: $(TOOLS) 
	@echo Configuring x264
	cd $(X264_DIR) && \
		./configure "--prefix=$(PREFIX)" --enable-shared --enable-pic "--extra-cflags=-mtune=$(TUNE_CPU)" --bit-depth=all --chroma-format=all
$(X264): $(X264_DIR)/config.h
	@echo Building x264
	$(MAKE) -C $(X264_DIR) -j $(CORES) || $(MAKE) -C $(X264_DIR)
	$(MAKE) -C $(X264_DIR) install	

X265_DIR := $(CURDIR)/libx265/build/linux
$(X265_DIR)/Makefile: $(TOOLS) 
	@echo Configuring x265
	cd $(X265_DIR) && cmake -G "Unix Makefiles" "-DCMAKE_INSTALL_PREFIX=$(PREFIX)" -DENABLE_SHARED=on ../../source -DENABLE_AGGRESSIVE_CHECKS=off -DENABLE_ASSEMBLY=on -DENABLE_HDR10_PLUS=on -DHIGH_BIT_DEPTH=on -DCMAKE_BUILD_TYPE=Release -DNATIVE_BUILD=on "-DNUMA_ROOT_DIR=$(PREFIX)" "-DNUMA_INCLUDE_DIR=$(PREFIX)/include" "-DNUMA_LIBRARY=$(LIBNUMA)"
$(X265): $(X265_DIR)/Makefile
	@echo Building x265
	$(MAKE) -C $(X265_DIR) -j $(CORES) || $(MAKE) -C $(X265_DIR)
	$(MAKE) -C $(X265_DIR) install
	

LIBVPX_DIR := $(CURDIR)/libvpx
$(LIBVPX_DIR)/config.mk: $(TOOLS) 
	@echo Configuring libvpx
	cd $(LIBVPX_DIR) && \
		./configure --prefix=$(PREFIX) --cpu=$(TUNE_CPU) --enable-pic --disable-examples --disable-unit-tests --as=yasm --disable-docs --enable-vp9-highbitdepth --enable-better-hw-compatibility --enable-vp8 --enable-vp9 --enable-postproc --enable-vp9-postproc  --enable-vp9-temporal-denoising --enable-webm-io  --enable-libyuv --disable-dependency-tracking --enable-shared --disable-static  
$(LIBVPX): $(LIBVPX_DIR)/config.mk
	@echo Building libvpx
	$(MAKE) -C $(LIBVPX_DIR) -j $(CORES) || $(MAKE) -C $(LIBVPX_DIR)
	$(MAKE) -C $(LIBVPX_DIR) install

LAME_DIR := $(CURDIR)/lame-3.100
$(LAME_DIR)/config.h: $(TOOLS) $(LAME_DIR).tar.gz
	@echo Configuring lame
	rm -rf $(LAME_DIR)
	tar xf $(LAME_DIR).tar.gz
	cd $(LAME_DIR) && \
		CFLAGS="-mtune=$(TUNE_CPU)" ./configure "--prefix=$(PREFIX)" --enable-shared --disable-static --enable-nasm --disable-dependency-tracking --disable-frontend --with-pic  
$(LAME): $(LAME_DIR)/config.h
	@echo Building lame
	$(MAKE) -C $(LAME_DIR) -j $(CORES) || $(MAKE) -C $(LAME_DIR)
	$(MAKE) -C $(LAME_DIR) install

OPUS_DIR := $(CURDIR)/opus
$(OPUS_DIR)/config.h: $(TOOLS)
	@echo Configuring opus
	cd $(OPUS_DIR) && \
		./autogen.sh && \
		CFLAGS="-mtune=$(TUNE_CPU)" ./configure "--prefix=$(PREFIX)" --enable-shared --disable-static --disable-doc --disable-extra-programs --with-pic
$(OPUS): $(OPUS_DIR)/config.h
	@echo Building opus
	$(MAKE) -C $(OPUS_DIR) -j $(CORES) || $(MAKE) -C $(OPUS_DIR)
	$(MAKE) -C $(OPUS_DIR) install

AOM_DIR := $(CURDIR)/aom
$(AOM_DIR)/aom_build/Makefile: $(TOOLS)
	@echo Configuring aom
	mkdir -p "$(AOM_DIR)/aom_build"
	cd $(AOM_DIR)/aom_build && \
		 cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=$(PREFIX) -DENABLE_SHARED=on -DENABLE_NASM=on .. -DBUILD_SHARED_LIBS=on -DCONFIG_PIC=on -DCONFIG_SHARED=on -DCONFIG_STATIC=no -DENABLE_EXAMPLES=off -DENABLE_TESTDATA=off -DENABLE_TESTS=off 
$(AOM): $(AOM_DIR)/aom_build/Makefile
	@echo Building aom 
	$(MAKE) -C $(AOM_DIR)/aom_build -j $(CORES) || $(MAKE) -C $(AOM_DIR)/aom_build 
	$(MAKE) -C $(AOM_DIR)/aom_build install

all: $(AOM)

clean:
	rm -rf $(NASM_DIR)
	rm -rf $(YASM_DIR)
	rm -rf $(PREFIX)
	cd $(LIBNUMA_DIR) && git clean -fxd
	cd $(X264_DIR) && git clean -fxd
	cd $(X265_DIR) && git clean -fxd
	cd $(LIBVPX_DIR) && git clean -fxd
	rm -rf $(LAME_DIR)
	cd $(OPUS_DIR) && git clean -fxd

.PHONY: all clean 
#.SILENT:
.DEFAULT_GOAL := all
