%hook SiriPresentationSpringBoardMainScreenViewController
-(BOOL)shouldDismissForTapsOutsideContent {
    return NO;
}
-(BOOL)shouldDismissForSwipesOutsideContent {
    return NO;
}
%end
%hook SBAssistantActiveInterfaceOrientationWindow
-(BOOL)touchesPassThroughToSpringBoard {
    return YES;
}
%end
%hook SBAssistantWindow
-(BOOL)touchesPassThroughToSpringBoard {
    return YES;
}
%end

