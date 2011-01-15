// -------------------------------------------------------
// LoginItemController.h
//
// Copyright (c) 2010 Jakub Suder <jakub.suder@gmail.com>
// Licensed under Eclipse Public License v1.0
// -------------------------------------------------------

#import <Cocoa/Cocoa.h>

@interface LoginItemController : NSObject {}

@property BOOL loginItemEnabled;

// private
- (NSURL *) applicationPath;
- (LSSharedFileListRef) getLoginItemList;
- (void) addApplicationToLoginList: (LSSharedFileListRef) list;
- (BOOL) findApplicationInLoginList: (LSSharedFileListRef) list andRemove: (BOOL) remove;

@end
