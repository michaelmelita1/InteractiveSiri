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
%hook SiriPresentationViewController
-(long long)currentViewMode {
    return 2;
}
%end
%hook SiriUIConfiguration 
-(long long)siriViewMode {
    return 1;
}
%end

%hook AFPreferences
-(BOOL)debugButtonIsEnabled {
    return YES;
}
%end
