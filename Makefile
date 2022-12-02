FINALPACKAGE=1
ARCHS = arm64, arm64e
TARGET = iphone:14.5

include $(THEOS)/makefiles/common.mk

TWEAK_NAME =InteractiveSiri
InteractiveSiri_FILES = Tweak.x
InteractiveSiri_CFLAGS = -fobjc-arc


include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "sbreload"

include $(THEOS_MAKE_PATH)/aggregate.mk
