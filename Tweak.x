#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define kWidth  ([UIScreen mainScreen].bounds.size.width)
#define kHeight ([UIScreen mainScreen].bounds.size.height)

@interface SBAssistantWindow : UIWindow
@end

@interface SBAssistantActiveInterfaceOrientationWindow : UIWindow
@end

@interface UIStatusBar : UIView
@end
@interface _UIStatusBar : UIView
@end

%hook SiriPresentationSpringBoardMainScreenViewController
-(BOOL)shouldDismissForTapsOutsideContent {
    return NO;
}
-(BOOL)shouldDismissForSwipesOutsideContent {
    return NO;
}
%end

%hook SiriPresentationViewController
-(long long)currentViewMode {
    return 1;
}
%end

%hook SiriUIConfiguration
-(long long)siriViewMode {
    return 1;
}
%end

%hook SBAssistantWindow
-(void)becomeKeyWindow {
    %orig;
    CGFloat const side = 175;
    CGRect small = CGRectMake((kWidth - side) / 2.0, kHeight - side - 10, side, side);
    if (!CGRectEqualToRect(self.frame, small)) {
        self.frame = small;
        self.clipsToBounds = YES;
        self.layer.cornerRadius = side / 2.0;
        if (self.subviews.count > 0) {
            UIView *content = self.subviews[0];
            content.frame = self.bounds;
            content.layer.cornerRadius = side / 2.0;
            content.clipsToBounds = YES;
            [content setNeedsLayout];
            [content layoutIfNeeded];
        }
    }
}
%end

%hook SBAssistantActiveInterfaceOrientationWindow
-(void)becomeKeyWindow {
    %orig;
    CGFloat const side = 175;
    CGRect small = CGRectMake((kWidth - side) / 2.0, kHeight - side - 10, side, side);
    if (!CGRectEqualToRect(self.frame, small)) {
        self.frame = small;
        self.clipsToBounds = YES;
        self.layer.cornerRadius = side / 2.0;
        if (self.subviews.count > 0) {
            UIView *content = self.subviews[0];
            content.frame = self.bounds;
            content.layer.cornerRadius = side / 2.0;
            content.clipsToBounds = YES;
            [content setNeedsLayout];
            [content layoutIfNeeded];
        }
    }
}
%end

%hook UIStatusBar
-(void)didMoveToWindow {
    %orig;
    if ([self.window isMemberOfClass:objc_getClass("SBAssistantWindow")] ||
        [self.window isMemberOfClass:objc_getClass("SBAssistantActiveInterfaceOrientationWindow")]) {
        [self removeFromSuperview];
    }
}
%end

%hook _UIStatusBar
-(void)didMoveToWindow {
    %orig;
    if ([self.window isMemberOfClass:objc_getClass("SBAssistantWindow")] ||
        [self.window isMemberOfClass:objc_getClass("SBAssistantActiveInterfaceOrientationWindow")]) {
        [self removeFromSuperview];
    }
}
%end
