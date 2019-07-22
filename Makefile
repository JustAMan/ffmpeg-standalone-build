CORES := 8
TUNE_CPU := core2
PREFIX = $(CURDIR)/prefix
NONFREE := --enable-nonfree --enable-libfdk-aac # set to empty if plan to redistribute

export PATH := $(PREFIX)/bin:$(PATH)
export PKG_CONFIG_PATH := $(PREFIX)/lib/pkgconfig:$(PKG_CONFIG_PATH)
export ACLOCAL_PATH := /usr/share/aclocal

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
ASS=$(PREFIX)/lib/libass.so
FREETYPE=$(PREFIX)/lib/libfreetype.so
FRIBIDI=$(PREFIX)/lib/libfribidi.so
FONTCONFIG=$(PREFIX)/lib/libfontconfig.so
BZIP=$(PREFIX)/lib/libbz2.a
PNG=$(PREFIX)/lib/libpng.so
ZLIB=$(PREFIX)/lib/libz.so
GETTEXT=$(PREFIX)/bin/gettext
AUTOCONF=$(PREFIX)/bin/autoconf
AUTOMAKE=$(PREFIX)/bin/automake
LIBXML=$(PREFIX)/lib/libxml2.so

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
	  wget \
	  gperf \
	  gettext \
	  autopoint
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

BZIP_DIR := $(CURDIR)/bzip2-1.0.6
$(BZIP): $(TOOLS) $(BZIP_DIR).tar.gz
	@echo Building bzip
	rm -rf $(BZIP_DIR)
	tar xf $(BZIP_DIR).tar.gz
	$(MAKE) -C $(BZIP_DIR) "PREFIX=$(PREFIX)" CC="gcc -fPIC" install
ZLIB_DIR := $(CURDIR)/zlib
$(ZLIB_DIR)/zconf.h: $(TOOLS)
	@echo Configuring zlib
	cd $(ZLIB_DIR) && \
		CFLAGS="-mtune=$(TUNE_CPU)" ./configure "--prefix=$(PREFIX)"
$(ZLIB): $(ZLIB_DIR)/zconf.h
	@echo Building zlib 
	$(MAKE) -C $(ZLIB_DIR) -j $(CORES) || $(MAKE) -C $(ZLIB_DIR)
	$(MAKE) -C $(ZLIB_DIR) install


PNG_DIR := $(CURDIR)/libpng
$(PNG_DIR)/config.h: $(TOOLS) $(ZLIB)
	@echo Configuring libpng
	cd $(PNG_DIR) && \
		CFLAGS="-mtune=$(TUNE_CPU) `pkg-config zlib --cflags`" LDFLAGS="`pkg-config zlib --libs`" CPPFLAGS="`pkg-config zlib --cflags`" ./configure "--prefix=$(PREFIX)" --enable-shared --disable-static --disable-dependency-tracking --enable-hardware-optimizations=yes --enable-intel-sse=yes

$(PNG): $(PNG_DIR)/config.h 
	@echo Building libpng 
	$(MAKE) -C $(PNG_DIR) -j $(CORES) || $(MAKE) -C $(PNG_DIR)
	$(MAKE) -C $(PNG_DIR) install

FREETYPE_DIR := $(CURDIR)/freetype-2.9
$(FREETYPE_DIR)/builds/unix/ftconfig.h: $(TOOLS) $(FREETYPE_DIR).tar.gz $(BZIP) $(PNG)
	@echo Configuring freetype
	rm -rf $(FREETYPE_DIR)
	tar xf $(FREETYPE_DIR).tar.gz
	cd $(FREETYPE_DIR) && \
		./autogen.sh && \
		CFLAGS="-mtune=$(TUNE_CPU)" BZIP2_CFLAGS="-I$(PREFIX)/include" BZIP2_LIBS="-L$(PREFIX)/lib -lbz2" ./configure "--prefix=$(PREFIX)" --enable-shared --disable-static --with-zlib=no --with-bzip2=yes --with-png=yes
$(FREETYPE): $(FREETYPE_DIR)/builds/unix/ftconfig.h
	@echo Building freetype
	$(MAKE) -C $(FREETYPE_DIR) -j $(CORES) || $(MAKE) -C $(FREETYPE_DIR)
	$(MAKE) -C $(FREETYPE_DIR) install

FRIBIDI_DIR := $(CURDIR)/fribidi
$(FRIBIDI_DIR)/config.h: $(TOOLS)
	@echo Configuring fribidi
	cd $(FRIBIDI_DIR) && \
		NOCONFIGURE=1 ./autogen.sh && \
		CFLAGS="-mtune=$(TUNE_CPU)" ./configure "--prefix=$(PREFIX)" --enable-shared --disable-static --disable-deprecated
$(FRIBIDI): $(FRIBIDI_DIR)/config.h
	@echo Building fribidi
	$(MAKE) -C $(FRIBIDI_DIR) -j $(CORES) || $(MAKE) -C $(FRIBIDI_DIR)
	$(MAKE) -C $(FRIBIDI_DIR) install

GETTEXT_DIR := $(CURDIR)/gettext-0.19.8
$(GETTEXT_DIR)/gettext-tools/config.h: $(TOOLS) $(GETTEXT_DIR).tar.gz
	@echo Configuring gettext
	rm -rf $(GETTEXT_DIR)
	tar xf $(GETTEXT_DIR).tar.gz
	cd $(GETTEXT_DIR) && \
		CFLAGS="-mtune=$(TUNE_CPU)" ./configure "--prefix=$(PREFIX)" --enable-shared --disable-static --disable-dependency-tracking --disable-java --disable-native-java --disable-curses --without-git 
		
$(GETTEXT): $(GETTEXT_DIR)/gettext-tools/config.h
	@echo Building gettext 
	$(MAKE) -C $(GETTEXT_DIR) -j $(CORES) || $(MAKE) -C $(GETTEXT_DIR)
	$(MAKE) -C $(GETTEXT_DIR) install

AUTOCONF_DIR := $(CURDIR)/autoconf-2.69
$(AUTOCONF_DIR)/Makefile: $(TOOLS) $(AUTOCONF_DIR).tar.gz
	@echo Configuring autoconf
	rm -rf $(AUTOCONF_DIR)
	tar xf $(AUTOCONF_DIR).tar.gz
	cd $(AUTOCONF_DIR) && \
		CFLAGS="-mtune=$(TUNE_CPU)" ./configure "--prefix=$(PREFIX)"
$(AUTOCONF): $(AUTOCONF_DIR)/Makefile
	@echo Building autoconf 
	$(MAKE) -C $(AUTOCONF_DIR) -j $(CORES) || $(MAKE) -C $(AUTOCONF_DIR)
	$(MAKE) -C $(AUTOCONF_DIR) install

AUTOMAKE_DIR := $(CURDIR)/automake-1.16.1
$(AUTOMAKE_DIR)/Makefile: $(TOOLS) $(AUTOMAKE_DIR).tar.gz
	@echo Configuring automake
	rm -rf $(AUTOMAKE_DIR)
	tar xf $(AUTOMAKE_DIR).tar.gz
	cd $(AUTOMAKE_DIR) && \
		CFLAGS="-mtune=$(TUNE_CPU)" ./configure "--prefix=$(PREFIX)"
$(AUTOMAKE): $(AUTOMAKE_DIR)/Makefile
	@echo Building automake
	$(MAKE) -C $(AUTOMAKE_DIR) -j $(CORES) || $(MAKE) -C $(AUTOMAKE_DIR)
	$(MAKE) -C $(AUTOMAKE_DIR) install

LIBXML_DIR := $(CURDIR)/libxml2
$(LIBXML_DIR)/config.h: $(TOOLS)
	@echo Configuring libxml 
	cd $(LIBXML_DIR) && \
		libtoolize && \
		CFLAGS="-mtune=$(TUNE_CPU)" ./autogen.sh "--prefix=$(PREFIX)" --disable-dependency-tracking --with-python=no
$(LIBXML): $(LIBXML_DIR)/config.h
	@echo Building libxml 
	$(MAKE) -C $(LIBXML_DIR) -j $(CORES) || $(MAKE) -C $(LIBXML_DIR)
	$(MAKE) -C $(LIBXML_DIR) install
	

FONTCONFIG_DIR := $(CURDIR)/fontconfig
$(FONTCONFIG_DIR)/config.h: $(TOOLS) $(GETTEXT) $(AUTOCONF) $(AUTOMAKE) $(LIBXML)
	@echo Configuring fontconfig
	cd $(FONTCONFIG_DIR) && \
		CFLAGS="-mtune=$(TUNE_CPU)" ./autogen.sh "--prefix=$(PREFIX)" --enable-shared --disable-static --disable-dependency-tracking --disable-docs --enable-libxml2 

$(FONTCONFIG): $(FONTCONFIG_DIR)/config.h
	@echo Building fontconfig 
	$(MAKE) -C $(FONTCONFIG_DIR) -j $(CORES) || $(MAKE) -C $(FONTCONFIG_DIR)
	$(MAKE) -C $(FONTCONFIG_DIR) install

ASS_DIR := $(CURDIR)/libass
$(ASS_DIR)/config.h: $(TOOLS) $(FREETYPE) $(FRIBIDI) $(FONTCONFIG)
	@echo Configuring libass
	cd $(ASS_DIR) && ./autogen.sh && \
		CFLAGS="-mtune=$(TUNE_CPU)" ./configure "--prefix=$(PREFIX)" --enable-shared --disable-static --disable-dependency-tracking --with-pic
$(ASS): $(ASS_DIR)/config.h
	@echo Building libass
	$(MAKE) -C $(ASS_DIR) -j $(CORES) || $(MAKE) -C $(ASS_DIR)
	$(MAKE) -C $(ASS_DIR) install

all: $(ASS)

FFMPEG_DIR := $(CURDIR)/ffmpeg
ff:
	@echo Configuring ffmpeg
	cd "$(FFMPEG_DIR)" && \
		./configure --prefix="${PREFIX}" --pkg-config-flags="--static" \
			--extra-cflags="-I${PREFIX}/include -mtune=${TUNE_CPU}" \
			'--extra-ldflags=-L${PREFIX}/lib -Wl,-rpath=\\\$\$ORIGIN/../lib -Wl,-z,origin' \
			 --extra-libs="-lpthread -lm" --enable-gpl --enable-version3 \
			 ${NONFREE} --enable-libaom --enable-libass --enable-libbluray \
			--enable-libbs2b --enable-libcaca --enable-libcdio  --enable-libfontconfig \
			--enable-libfreetype --enable-libfribidi --enable-libmp3lame \
			--enable-libopenjpeg --enable-libopenmpt --enable-libopus \
			--enable-librubberband --enable-libsrt --enable-libtheora \
			--enable-libtwolame --enable-libvidstab --enable-libvpx --enable-libwebp \
			--enable-libx264 --enable-libx265 --enable-libxml2 --enable-libmysofa \
			--enable-libdrm --enable-vaapi --cpu="${TUNE_CPU}" --x86asmexe=nasm \
			--enable-asm  --enable-mmx --enable-mmxext --enable-sse --enable-sse2 \
			--enable-sse3 --enable-ssse3 --enable-sse4 --enable-sse42 --enable-avx \
			--enable-avx2 --disable-fast-unaligned --enable-hwaccel=h264_nvdec \
			--enable-hwaccel=h264_vaapi --enable-hwaccel=hevc_nvdec \
			--enable-hwaccel=hevc_vaapi --enable-hwaccel=vp8_nvdec \
			--enable-hwaccel=vp8_vaapi --enable-hwaccel=vp9_nvdec \
			--enable-hwaccel=vp9_vaapi --enable-encoder=h264_nvenc \
			--enable-encoder=h264_vaapi --enable-encoder=hevc_nvenc \
			--enable-encoder=hevc_vaapi --enable-encoder=mpeg2_vaapi \
			--enable-encoder=nvenc --enable-encoder=nvenc_h264 \
			--enable-encoder=nvenc_hevc --enable-encoder=vp9_vaapi
		

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
	# TODO: add AOM and further

.PHONY: all clean ff
#.SILENT:
.DEFAULT_GOAL := all
