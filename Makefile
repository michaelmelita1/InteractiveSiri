FINALPACKAGE=1
ARCHS = arm64
TARGET = iphone:13.7

include $(THEOS)/makefiles/common.mk

TWEAK_NAME =InteractiveSiri
InteractiveSiri_FILES = Tweak.x
InteractiveSiri_CFLAGS = -fobjc-arc


include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "sbreload"

include $(THEOS_MAKE_PATH)/aggregate.mk
