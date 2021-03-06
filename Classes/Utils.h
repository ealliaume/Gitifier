// -------------------------------------------------------
// Utils.h
//
// Copyright (c) 2010 Jakub Suder <jakub.suder@gmail.com>
// Licensed under Eclipse Public License v1.0
// -------------------------------------------------------

#import <Cocoa/Cocoa.h>

#define UserEmailChangedNotification @"UserEmailChangedNotification"
#define GitExecutableSetNotification @"GitExecutableSetNotification"
#define BzrExecutableSetNotification @"BzrExecutableSetNotification"

#define ObserveDefaults(setting) [[NSUserDefaultsController sharedUserDefaultsController] \
  addObserver: self forKeyPath: PSFormat(@"values.%@", setting) options: 0 context: nil]

@interface NSString (Gitifier)
- (NSString *) MD5Hash;
- (NSString *) lastKeyPathElement;
@end

@interface NSWindow (Gitifier)
@property BOOL keepOnTop;
@end
