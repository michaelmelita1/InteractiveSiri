# InteractiveSiri
iPad compact Siri on iPhone (iOS 15; iPhone 7 first). Firmware: iPhone_4.7_P3_15.8.8_19H422 (rootfs 098-68844-067.dmg) and
iPad_10.2_2021_15.7_19H12 (rootfs 078-69226-013.dmg) in the user's Downloads. Device-VM work dir ~/siri (i7 cache in ~/dsc_i7, symbols /tmp/i7.symbols).

Findings (iPhone 7 15.8.8 cache):
- SiriUIDeviceIsPad (SiriUI, 0x1a87a85c4) = UIDevice idiom == pad. All callers:
  AssistantUI: AFUISiriCompactView _orbViewContainerFrame/_originXForOrbContainer; AFUISiriViewController initWithConnection:configuration:requestSource:
  (tap/pan dismissal policy: if siriViewMode==7 -> policy = isPad ? 0 : (os_feature SiriUI/persistent_phone ? 2 : 1)),
  _setFullScreenDimmingLayerVisible:animated:, compactView:blurVisibilityDidChange:, siriSessionImmersiveExperienceRequested, viewWillTransitionToSize:.
  SiriUIActivation (SpringBoard): -[SiriPresentationSpringBoardMainScreenViewController resetGestureBehaviors]: dismissForTap/Taps/Swipes = !(persistent||isPad),
  setShouldPassTouchesThroughToSpringBoard: = persistent||isPad; setShareHomeGesture:.
  SiriUI: -[SiriUINavigationContentViewController hasContentAtPoint:] + one unnamed; IsLargeFormatPad separate.
  SpringBoard.framework itself never calls it.
- FeatureFlags SiriUI.plist identical on iPhone 7 and iPad (persistent_phone absent = off).
- Siri.app = com.apple.siri.

0.1.0: main hooks SiriUIDeviceIsPad -> YES in SpringBoard + Siri. EXP=PERSISTENT instead forces os_feature SiriUI/persistent_phone.
DIAG_LOG logs callers (image+offset) and hooks the Siri methods above by name (type-encoding based loggers).
Logs: InteractiveSiri-<process>-diag.txt in /var/mobile/Library/Caches, /var/mobile/Media, /var/tmp.
Not yet done: iPad cache comparison (disk space on device VM is tight), iOS 16 check.

0.4.0: user confirmed iPad mode works great on the iPhone 7. Control file from the user (Version 0.4.0, Architecture iphoneos-arm64,
Maintainer/Author michaelmelita1, Sileodepiction). ARCHS = arm64 arm64e; arm64e gets the same constant-string isa signing
constructor as ExposureControl (no-op unless the system signs isa). arm64e devices (XS+) and iOS 16+ untested.
Release builds: main + experiments-diag (EXP=PERSISTENT DIAG=DIAG_LOG) + source zip.
Removed the constant-string isa workaround (user request): arm64e must be built on the Mac with Xcode.
User wants only the iPad version: persistent_phone experiment removed; build.sh makes just the main package. (DIAG=DIAG_LOG still available.)
