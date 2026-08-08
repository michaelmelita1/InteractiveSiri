FINALPACKAGE=1
ARCHS = arm64
TARGET = iphone:clang:16.5:15.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = InteractiveSiri
InteractiveSiri_FILES = Tweak.x
InteractiveSiri_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "sbreload"

include $(THEOS_MAKE_PATH)/aggregate.mk
