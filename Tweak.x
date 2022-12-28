%hook SiriPresentationSpringBoardMainScreenViewController
-(BOOL)shouldDismissForTapsOutsideContent {
    return NO;
}
-(BOOL)shouldDismissForSwipesOutsideContent {
    return NO;
}
-(BOOL)showAppsBehindSiri {
    return YES;
}
-(BOOL)shouldPassTapsThrough {
    return YES;
}
-(BOOL)shouldPassTouchesThroughToSpringBoard {
    return YES;
}
%end
