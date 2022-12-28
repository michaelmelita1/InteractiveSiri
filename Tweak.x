%hook SiriPresentationSpringBoardMainScreenViewController
-(BOOL)shouldDismissForTapsOutsideContent {
    return NO;
}
-(BOOL)shouldDismissForSwipesOutsideContent {
    return NO;
}
%end
%hook SiriUIBackgroundBlurViewController
-(BOOL)backgroundBlurIsVisible {
    return NO;
}
%end
