// -------------------------------------------------------
// GrowlController.m
//
// Copyright (c) 2010 Jakub Suder <jakub.suder@gmail.com>
// Licensed under MIT license
// -------------------------------------------------------

#import "Commit.h"
#import "CommitWindowController.h"
#import "Defaults.h"
#import "GrowlController.h"
#import "Repository.h"
#import "RepositoryListController.h"

@implementation GrowlController

@synthesize repositoryListController;

+ (GrowlController *) sharedController {
  static GrowlController *instance = nil;
  if (!instance) {
    instance = [[GrowlController alloc] init];
  }
  return instance;
}

- (id) init {
  self = [super init];
  if (self) {
    [GrowlApplicationBridge setGrowlDelegate: self];
  }
  return self;
}

- (void) checkGrowlAvailability {
  if (![GrowlApplicationBridge isGrowlInstalled]) {
    NSInteger output = NSRunAlertPanel(@"Warning: Growl framework is not installed.",
                         @"Gitifier requires Growl to display notifications - please download and install it first.",
                         @"Open Growl website", @"Nevermind", nil);
    if (output == NSAlertDefaultReturn) {
      [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: @"http://growl.info"]];
    }
  }

  if (![GrowlApplicationBridge isGrowlRunning]) {
    NSInteger output = NSRunAlertPanel(@"Warning: Growl is not running.",
                                       @"To get any notifications from Gitifier, you need to start Growl.",
                                       @"Open Growl Preferences", @"Nevermind", nil);
    if (output == NSAlertDefaultReturn) {
      [self openGrowlPreferences];
    }
  }
}

- (void) openGrowlPreferences {
  NSArray *globalPathArray = PSArray(NSOpenStepRootDirectory(), @"Library", @"PreferencePanes", @"Growl.prefPane");
  NSArray *localPathArray = PSArray(NSHomeDirectory(), @"Library", @"PreferencePanes", @"Growl.prefPane");
  NSArray *preferencesPathArray = PSArray(NSOpenStepRootDirectory(), @"Applications", @"System Preferences.app");

  NSString *globalPath = [NSString pathWithComponents: globalPathArray];
  NSString *localPath = [NSString pathWithComponents: localPathArray];
  NSString *preferencesPath = [NSString pathWithComponents: preferencesPathArray];

  NSFileManager *manager = [NSFileManager defaultManager];
  NSWorkspace *workspace = [NSWorkspace sharedWorkspace];

  if ([manager fileExistsAtPath: globalPath]) {
    [workspace openURL: [NSURL fileURLWithPath: globalPath]];
  } else if ([manager fileExistsAtPath: localPath]) {
    [workspace openURL: [NSURL fileURLWithPath: localPath]];
  } else {
    [workspace openURL: [NSURL fileURLWithPath: preferencesPath]];
  }
}

- (void) showGrowlWithCommit: (Commit *) commit repository: (Repository *) repository {
  BOOL sticky = [GitifierDefaults boolForKey: STICKY_NOTIFICATIONS_KEY];
  NSDictionary *commitData = PSDict([commit toDictionary], @"commit", repository.url, @"repository");

  [GrowlApplicationBridge notifyWithTitle: PSFormat(@"%@ – %@", repository.name, commit.authorName)
                              description: commit.subject
                         notificationName: CommitReceivedGrowl
                                 iconData: [self growlIcon]
                                 priority: 0
                                 isSticky: sticky
                             clickContext: commitData];
}  

- (void) showGrowlWithError: (NSString *) message repository: (Repository *) repository {
  NSString *title;
  if (repository) {
    NSLog(@"Error in %@: %@", repository.name, message);
    title = PSFormat(@"Error in %@", repository.name);
  } else {
    NSLog(@"Error: %@", message);
    title = @"Error";
  }
  [GrowlApplicationBridge notifyWithTitle: title
                              description: message
                         notificationName: RepositoryUpdateFailedGrowl
                                 iconData: [self growlIcon]
                                 priority: 0
                                 isSticky: NO
                             clickContext: nil];
}

- (NSData *) growlIcon {
  static NSData *icon = nil;
  if (!icon) {
    icon = [[NSImage imageNamed: @"icon_app_32.png"] TIFFRepresentation];
  }
  return icon;
}

- (void) growlNotificationWasClicked: (id) clickContext {
  BOOL shouldShowDiffs = [GitifierDefaults boolForKey: SHOW_DIFF_WINDOW_KEY];
  BOOL shouldOpenInBrowser = [GitifierDefaults boolForKey: OPEN_DIFF_IN_BROWSER_KEY];
  
  if (clickContext && shouldShowDiffs) {
    NSString *url = [clickContext objectForKey: @"repository"];
    NSDictionary *commitHash = [clickContext objectForKey: @"commit"];
    Repository *repository = [repositoryListController findByUrl: url];
    Commit *commit = [Commit commitFromDictionary: commitHash];
    NSURL *webUrl = [repository webUrlForCommit: commit];
    
    if (repository) {
      if (webUrl && shouldOpenInBrowser) {
        [[NSWorkspace sharedWorkspace] openURL: webUrl];
      } else {
        CommitWindowController *window = [[CommitWindowController alloc] initWithRepository: repository commit: commit];
        [window showWindow: self];
        [NSApp activateIgnoringOtherApps: YES];
      }
    }
  }
}

@end
