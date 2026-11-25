# Rootless by default. For rootful jailbreaks: make package ROOTFUL=1
ifneq ($(ROOTFUL),1)
THEOS_PACKAGE_SCHEME = rootless
endif

FINALPACKAGE ?= 1
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = InteractiveSiri
InteractiveSiri_FILES = Tweak.x
InteractiveSiri_CFLAGS = -fobjc-arc
InteractiveSiri_FRAMEWORKS = UIKit
ifneq ($(DIAG),)
InteractiveSiri_CFLAGS += $(foreach d,$(DIAG),-D$(d))
endif
ifneq ($(EXP),)
InteractiveSiri_CFLAGS += $(foreach e,$(EXP),-DEXP_$(e))
endif

include $(THEOS_MAKE_PATH)/tweak.mk
