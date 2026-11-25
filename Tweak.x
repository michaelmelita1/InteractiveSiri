// InteractiveSiri: the iPad's compact Siri on iPhone (iOS 15). The orb sits in the bottom corner
// and you can keep touching and scrolling the app behind it; Siri stays up instead of dismissing.
//
// How (from the iPhone 7 15.8.8 and iPad 9 15.7 firmware): every iPad-only behaviour of compact Siri
// is decided by one SiriUI function, SiriUIDeviceIsPad() ([UIDevice currentDevice].userInterfaceIdiom == pad).
// Its callers are all Siri UI:
//   AssistantUI  -[AFUISiriCompactView _originXForOrbContainer] / _orbViewContainerFrame   orb in the corner
//                -[AFUISiriViewController initWithConnection:configuration:requestSource:]  tap dismissal policy (pad = 0)
//                -[AFUISiriViewController _setFullScreenDimmingLayerVisible:animated:], compactView:blurVisibilityDidChange:,
//                 siriSessionImmersiveExperienceRequested, viewWillTransitionToSize:withTransitionCoordinator:
//   SiriUIActivation (SpringBoard) -[SiriPresentationSpringBoardMainScreenViewController resetGestureBehaviors]
//                 dismiss on taps/swipes outside = !pad, pass touches through to SpringBoard = pad; setShareHomeGesture:
//   SiriUI       -[SiriUINavigationContentViewController hasContentAtPoint:] (which touches Siri keeps)
// (Apple's unfinished phone version is the feature flag SiriUI/persistent_phone, off on every device.)
// So answer YES from SiriUIDeviceIsPad in SpringBoard and Siri. Nothing else in these processes calls it.
//
// Experiment (EXP=PERSISTENT): instead of the iPad layout, turn on Apple's persistent_phone flag
// (touches pass through, Siri stays, but the orb stays in the middle like a phone).

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <os/log.h>
#import <substrate.h>
#import <mach-o/getsect.h>
#import <mach/mach.h>

#pragma mark - arm64e: sign our constant strings' isa (iOS 18)
// On newer arm64e iOS, libobjc authenticates every object's isa (key DA, discriminator = the isa field's address
// blended with 0x6AE1). Theos' Linux clang leaves @"..." constants' isa unsigned, which crashed ExposureControl on
// iOS 18 at load. Sign ours the way Foundation's own constant strings are signed, only if they are (checked by
// recomputing Foundation's signature), so iOS 15-16 and arm64 are untouched.
#if __has_feature(ptrauth_intrinsics)
#include <ptrauth.h>
extern NSString *const NSFileTypeDirectory;
static void __attribute__((constructor(101))) SignConstantStringISAs(void) {
	void **sysISA = (void **)(__bridge void *)NSFileTypeDirectory;
	void *sys = *sysISA, *raw = ptrauth_strip(sys, ptrauth_key_asda);
	if (sys == raw) return;
	if (ptrauth_sign_unauthenticated(raw, ptrauth_key_asda, ptrauth_blend_discriminator(sysISA, 0x6AE1)) != sys) return;
	Dl_info info;
	if (!dladdr((void *)SignConstantStringISAs, &info)) return;
	static const char *const segs[] = {"__DATA_CONST", "__DATA", "__AUTH_CONST", "__AUTH"};
	for (int si = 0; si < 4; si++) {
		unsigned long size = 0;
		uint8_t *sect = getsectiondata((const struct mach_header_64 *)info.dli_fbase, segs[si], "__cfstring", &size);
		if (!sect || !size) continue;
		vm_address_t page = (vm_address_t)sect & ~(vm_address_t)(PAGE_SIZE - 1);
		vm_size_t len = ((vm_address_t)sect + size) - page;
		if (vm_protect(mach_task_self(), page, len, false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY) != KERN_SUCCESS) continue;
		for (unsigned long off = 0; off + 32 <= size; off += 32) {
			void **isa = (void **)(sect + off);
			*isa = ptrauth_sign_unauthenticated(ptrauth_strip(*isa, ptrauth_key_asda), ptrauth_key_asda, ptrauth_blend_discriminator(isa, 0x6AE1));
		}
		if (strstr(segs[si], "CONST")) vm_protect(mach_task_self(), page, len, false, VM_PROT_READ);
	}
}
#endif

#define LOG(fmt, ...) os_log(OS_LOG_DEFAULT, "[InteractiveSiri] " fmt, ##__VA_ARGS__)

#ifdef DIAG_LOG
static void DiagLog(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);
static void DiagStart(void);
static void DiagHookSiriClasses(void);
static NSString *DescribeAddress(const void *addr);
#endif

#pragma mark - The switch

#ifndef EXP_PERSISTENT
static BOOL (*orig_SiriUIDeviceIsPad)(void);
static BOOL hook_SiriUIDeviceIsPad(void) {
#ifdef DIAG_LOG
	static NSMutableSet *seen;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ seen = [NSMutableSet set]; });
	NSString *caller = DescribeAddress(__builtin_return_address(0));
	BOOL first;
	@synchronized (seen) { first = ![seen containsObject:caller]; if (first) [seen addObject:caller]; }
	if (first) DiagLog(@"SiriUIDeviceIsPad() called from %@: real answer %d, answering YES", caller, orig_SiriUIDeviceIsPad ? orig_SiriUIDeviceIsPad() : -1);
#endif
	return YES;
}
#else
static BOOL (*orig_os_feature_enabled_impl)(const char *domain, const char *feature);
static BOOL hook_os_feature_enabled_impl(const char *domain, const char *feature) {
	if (domain && feature && !strcmp(domain, "SiriUI") && !strcmp(feature, "persistent_phone")) {
#ifdef DIAG_LOG
		DiagLog(@"os_feature_enabled(SiriUI, persistent_phone) from %@: answering YES", DescribeAddress(__builtin_return_address(0)));
#endif
		return YES;
	}
	return orig_os_feature_enabled_impl(domain, feature);
}
#endif

static BOOL sHooked;
static void TryHook(void) {
	if (sHooked) return;
#ifndef EXP_PERSISTENT
	void *f = dlsym(RTLD_DEFAULT, "SiriUIDeviceIsPad");
	if (!f) return;
	MSHookFunction(f, (void *)hook_SiriUIDeviceIsPad, (void **)&orig_SiriUIDeviceIsPad);
	LOG("hooked SiriUIDeviceIsPad");
#else
	void *f = dlsym(RTLD_DEFAULT, "_os_feature_enabled_impl");
	if (!f) return;
	MSHookFunction(f, (void *)hook_os_feature_enabled_impl, (void **)&orig_os_feature_enabled_impl);
	LOG("hooked _os_feature_enabled_impl for SiriUI/persistent_phone");
#endif
	sHooked = YES;
#ifdef DIAG_LOG
	DiagLog(@"main hook installed (%s)",
#ifndef EXP_PERSISTENT
		"SiriUIDeviceIsPad -> YES"
#else
		"SiriUI/persistent_phone -> YES"
#endif
	);
#endif
}

static void ImageAdded(const struct mach_header *mh, intptr_t slide) {
	TryHook();
#ifdef DIAG_LOG
	DiagHookSiriClasses();
#endif
}

%ctor {
	@autoreleasepool {
		NSString *proc = [[NSProcessInfo processInfo] processName];
		LOG("loaded into %{public}@", proc);
#ifdef DIAG_LOG
		DiagStart();
#endif
		TryHook();
		// SiriUI / AssistantUI may load later; check again as images arrive (also runs once per already-loaded image now).
		_dyld_register_func_for_add_image(ImageAdded);
	}
}

#ifdef DIAG_LOG
#pragma mark - Diagnostics

// Where a call came from, as image+offset (offsets match the firmware dumps) plus the nearest exported symbol.
static NSString *DescribeAddress(const void *addr) {
	Dl_info info;
	if (!dladdr(addr, &info) || !info.dli_fname) return [NSString stringWithFormat:@"%p", addr];
	NSString *image = [@(info.dli_fname) lastPathComponent];
	uintptr_t off = (uintptr_t)addr - (uintptr_t)info.dli_fbase;
	if (info.dli_sname) return [NSString stringWithFormat:@"%@+0x%lx (%s+0x%lx)", image, (unsigned long)off, info.dli_sname, (unsigned long)((uintptr_t)addr - (uintptr_t)info.dli_saddr)];
	return [NSString stringWithFormat:@"%@+0x%lx", image, (unsigned long)off];
}

// Hook-and-log the Siri methods that act on the iPad answer. Hooked by name with a logger chosen from the
// method's type encoding, as soon as each class exists; anything missing is reported, never guessed.
static NSMutableSet<NSString *> *sHookedMethods;

static void LogHook(Class cls, SEL sel) {
	Method m = class_getInstanceMethod(cls, sel);
	NSString *name = [NSString stringWithFormat:@"-[%s %s]", class_getName(cls), sel_getName(sel)];
	if (!m || [sHookedMethods containsObject:name]) return;
	if (method_getImplementation(m) == NULL) return;
	// Only hook methods the class itself defines (not inherited ones).
	unsigned n = 0; BOOL own = NO;
	Method *ms = class_copyMethodList(cls, &n);
	for (unsigned i = 0; i < n; i++) if (ms[i] == m) { own = YES; break; }
	free(ms);
	if (!own) return;
	[sHookedMethods addObject:name];
	const char *enc = method_getTypeEncoding(m);
	char ret[64] = {0}; method_getReturnType(m, ret, sizeof ret);
	unsigned nargs = method_getNumberOfArguments(m);
	char a2[64] = {0}, a3[64] = {0};
	if (nargs > 2) method_getArgumentType(m, 2, a2, sizeof a2);
	if (nargs > 3) method_getArgumentType(m, 3, a3, sizeof a3);
	IMP orig = method_getImplementation(m);
	IMP rep = NULL;
	if (ret[0] == 'v' && nargs == 2) {
		rep = imp_implementationWithBlock(^(id me) { DiagLog(@"%@", name); ((void (*)(id, SEL))orig)(me, sel); });
	} else if (ret[0] == 'v' && nargs == 3 && (a2[0] == 'B' || a2[0] == 'c')) {
		rep = imp_implementationWithBlock(^(id me, BOOL v) { DiagLog(@"%@ %d", name, v); ((void (*)(id, SEL, BOOL))orig)(me, sel, v); });
	} else if (ret[0] == 'v' && nargs == 4 && (a2[0] == 'B' || a2[0] == 'c') && (a3[0] == 'B' || a3[0] == 'c')) {
		rep = imp_implementationWithBlock(^(id me, BOOL v, BOOL w) { DiagLog(@"%@ %d %d", name, v, w); ((void (*)(id, SEL, BOOL, BOOL))orig)(me, sel, v, w); });
	} else if (ret[0] == '@' && nargs == 4 && strchr("qQiIlL", a2[0]) && a3[0] == '@') {
		rep = imp_implementationWithBlock(^id(id me, long long v, id w) { DiagLog(@"%@ %lld", name, v); return ((id (*)(id, SEL, long long, id))orig)(me, sel, v, w); });
	} else if (ret[0] == 'd' && nargs == 2) {
		rep = imp_implementationWithBlock(^double(id me) { double r = ((double (*)(id, SEL))orig)(me, sel); DiagLog(@"%@ = %g", name, r); return r; });
	} else if (!strncmp(ret, "{CGRect", 7) && nargs == 2) {
		rep = imp_implementationWithBlock(^CGRect(id me) { CGRect r = ((CGRect (*)(id, SEL))orig)(me, sel); DiagLog(@"%@ = %@", name, NSStringFromCGRect(r)); return r; });
	} else if ((ret[0] == 'B' || ret[0] == 'c') && nargs == 3 && !strncmp(a2, "{CGPoint", 8)) {
		// Called for every touch: log only when the answer changes.
		__block int last = -1;
		rep = imp_implementationWithBlock(^BOOL(id me, CGPoint p) {
			BOOL r = ((BOOL (*)(id, SEL, CGPoint))orig)(me, sel, p);
			if (r != last) { last = r; DiagLog(@"%@ (%.0f, %.0f) = %d", name, p.x, p.y, r); }
			return r;
		});
	} else if ((ret[0] == 'B' || ret[0] == 'c') && nargs == 2) {
		__block int last = -1;
		rep = imp_implementationWithBlock(^BOOL(id me) {
			BOOL r = ((BOOL (*)(id, SEL))orig)(me, sel);
			if (r != last) { last = r; DiagLog(@"%@ = %d", name, r); }
			return r;
		});
	} else if (ret[0] == 'v') {
		// Anything else returning void: log the call only (arguments untouched).
		rep = NULL;
		DiagLog(@"(not hooked, signature %s) %@", enc, name);
		return;
	} else {
		DiagLog(@"(not hooked, signature %s) %@", enc, name);
		return;
	}
	method_setImplementation(m, rep);
}

static void HookMatching(const char *className, NSArray<NSString *> *words) {
	Class cls = objc_getClass(className);
	if (!cls) return;
	unsigned n = 0;
	Method *ms = class_copyMethodList(cls, &n);
	for (unsigned i = 0; i < n; i++) {
		NSString *s = @(sel_getName(method_getName(ms[i])));
		for (NSString *w in words) if (!w.length || [s rangeOfString:w options:NSCaseInsensitiveSearch].location != NSNotFound) { LogHook(cls, method_getName(ms[i])); break; }
	}
	free(ms);
}

static void DiagHookSiriClasses(void) {
	static dispatch_once_t once;
	dispatch_once(&once, ^{ sHookedMethods = [NSMutableSet set]; });
	@synchronized (sHookedMethods) {
		NSUInteger before = sHookedMethods.count;
		// Tap / pan dismissal policy (every method).
		HookMatching("AFUISiriTapPanDismissalPolicyManager", @[@""]);
		// SpringBoard side: dismissing on outside taps/swipes and passing touches through.
		HookMatching("SiriPresentationSpringBoardMainScreenViewController", @[@"Dismiss", @"PassTouches", @"Gesture", @"TouchesThrough"]);
		HookMatching("SiriPresentationViewController", @[@"Dismiss", @"PassTouches", @"TouchesThrough", @"hasContentAtPoint"]);
		// Orb placement and compact view.
		HookMatching("AFUISiriCompactView", @[@"orb", @"setMode", @"dimming", @"blur"]);
		HookMatching("AFUISiriViewController", @[@"Dimming", @"Immersive", @"blurVisibility", @"Dismiss", @"hasContentAtPoint", @"passThrough"]);
		// Which touches Siri keeps.
		HookMatching("SiriUINavigationContentViewController", @[@"hasContentAtPoint"]);
		HookMatching("AFUITouchPassThroughView", @[@"hitTest"]);
		HookMatching("SiriUIPassThroughHitTestView", @[@"hitTest"]);
		if (sHookedMethods.count != before) DiagLog(@"watching %lu Siri methods (%lu new)", (unsigned long)sHookedMethods.count, (unsigned long)(sHookedMethods.count - before));
	}
}

static dispatch_queue_t sDiagQueue;
static NSMutableArray<NSString *> *sDiagPaths;

static void DiagStart(void) {
	sDiagQueue = dispatch_queue_create("interactivesiri.diag", DISPATCH_QUEUE_SERIAL);
	sDiagPaths = [NSMutableArray array];
	NSString *proc = [[NSProcessInfo processInfo] processName];
	NSString *file = [NSString stringWithFormat:@"InteractiveSiri-%@-diag.txt", proc];
	NSString *header = [NSString stringWithFormat:@"\n==== InteractiveSiri diagnostic log, %@, %@, iOS %@\n", [NSDate date], proc, [[NSProcessInfo processInfo] operatingSystemVersionString]];
	NSMutableArray *tried = [NSMutableArray array];
	for (NSString *dir in @[@"/var/mobile/Library/Caches", @"/var/mobile/Media", @"/var/tmp", NSTemporaryDirectory()]) {
		NSString *path = [dir stringByAppendingPathComponent:file];
		NSString *real = [[dir stringByResolvingSymlinksInPath] stringByAppendingPathComponent:file];
		BOOL dup = NO;
		for (NSString *p in sDiagPaths) if ([[[p stringByDeletingLastPathComponent] stringByResolvingSymlinksInPath] isEqualToString:[real stringByDeletingLastPathComponent]]) dup = YES;
		if (dup) continue;
		NSFileManager *fm = [NSFileManager defaultManager];
		if ([[fm attributesOfItemAtPath:path error:NULL] fileSize] > 4 * 1024 * 1024) [fm removeItemAtPath:path error:NULL];
		if (![fm fileExistsAtPath:path]) [@"" writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:NULL];
		NSFileHandle *h = [NSFileHandle fileHandleForWritingAtPath:path];
		if (h) { [h seekToEndOfFile]; [h writeData:[header dataUsingEncoding:NSUTF8StringEncoding]]; [h closeFile]; [sDiagPaths addObject:path]; [tried addObject:[path stringByAppendingString:@"=ok"]]; }
		else [tried addObject:[path stringByAppendingString:@"=failed"]];
	}
	DiagLog(@"log locations: %@", [tried componentsJoinedByString:@" | "]);
}

static void DiagLog(NSString *fmt, ...) {
	va_list ap; va_start(ap, fmt);
	NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
	va_end(ap);
	LOG("diag: %{public}@", msg);
	if (!sDiagQueue) return;
	NSData *line = [[NSString stringWithFormat:@"%@ %@\n", [NSDate date], msg] dataUsingEncoding:NSUTF8StringEncoding];
	dispatch_async(sDiagQueue, ^{
		for (NSString *path in sDiagPaths) {
			NSFileHandle *h = [NSFileHandle fileHandleForWritingAtPath:path];
			[h seekToEndOfFile]; [h writeData:line]; [h closeFile];
		}
	});
}
#endif
