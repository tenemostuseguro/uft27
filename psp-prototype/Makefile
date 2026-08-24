TARGET = uft15cards
OBJS = main.o fut15_data.o

CFLAGS = -O2 -G0 -Wall -std=c99
CXXFLAGS = $(CFLAGS) -fno-exceptions -fno-rtti
ASFLAGS = $(CFLAGS)
LDFLAGS =
LIBS = -lpspge

BUILD_PRX = 1
PSP_FW_VERSION = 660
EXTRA_TARGETS = EBOOT.PBP
PSP_EBOOT_TITLE = UFT FUT15 Visual Card Lab

PSPSDK := $(shell psp-config --pspsdk-path)
include $(PSPSDK)/lib/build.mak
