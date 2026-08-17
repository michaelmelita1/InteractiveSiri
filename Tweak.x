#import <UIKit/UIKit.h>

@interface SBAssistantWindow : UIWindow
- (void)setTouchesPassThroughToSpringBoard:(BOOL)value;
@end

@interface SBAssistantActiveInterfaceOrientationWindow : UIWindow
- (void)setTouchesPassThroughToSpringBoard:(BOOL)value;
@end

%hook SiriPresentationSpringBoardMainScreenViewController
-(BOOL)shouldDismissForTapsOutsideContent {
    return NO;
}
-(BOOL)shouldDismissForSwipesOutsideContent {
    return NO;
}
%end

%hook SBAssistantWindow
-(void)setTouchesPassThroughToSpringBoard:(BOOL)value {
    %orig(YES);
}
%end

%hook SBAssistantActiveInterfaceOrientationWindow
-(void)setTouchesPassThroughToSpringBoard:(BOOL)value {
    %orig(YES);
}
%end

@interface AFUISiriCompactDimmingView : UIView
@end

%hook AFUISiriCompactDimmingView
-(void)setFrame:(CGRect)frame {
    %orig(CGRectMake(0, 0, 0, 0));
}
%end

@interface _UIContextLayerHostView : UIView
@end

%hook _UIContextLayerHostView
-(void)setFrame:(CGRect)frame {
    UIView *ancestor = self.superview;
    BOOL isSiriScene = NO;
    int depth = 0;
    while (ancestor && depth < 5) {
        if ([ancestor respondsToSelector:@selector(description)]) {
            NSString *desc = [ancestor description];
            if ([desc rangeOfString:@"SiriHostedScene"].location != NSNotFound) {
                isSiriScene = YES;
                break;
            }
        }
        ancestor = ancestor.superview;
        depth++;
    }
    if (isSiriScene) {
        CGFloat const screenWidth = [UIScreen mainScreen].bounds.size.width;
        CGFloat const proportion = 140.0 / 667.0;
        CGFloat const height = frame.size.height * proportion;
        %orig(CGRectMake(0, 0, screenWidth, height));
    } else {
        %orig(frame);
    }
}
%end
