// -------------------------------------------------------
// GitifierAppDelegate.m
//
// Copyright (c) 2010 Jakub Suder <jakub.suder@gmail.com>
// Licensed under Eclipse Public License v1.0
// -------------------------------------------------------

#define SUEnableAutomaticChecksKey @"SUEnableAutomaticChecks"
#define SUSendProfileInfoKey @"SUSendProfileInfo"

#import "RegexKitLite.h"

#import "Commit.h"
#import "Defaults.h"
#import "Git.h"
#import "Bzr.h"
#import "GitifierAppDelegate.h"
#import "GrowlController.h"
#import "PreferencesWindowController.h"
#import "Repository.h"
#import "RepositoryListController.h"
#import "StatusBarController.h"

@implementation GitifierAppDelegate

@synthesize monitor, userEmail, preferencesWindowController, statusBarController, repositoryListController,
  repositoryList;

// --- initialization and termination ---

- (void) applicationDidFinishLaunching: (NSNotification *) aNotification {
  repositoryList = [NSMutableArray array];
  [Defaults registerDefaults];

  PSObserve(nil, NSWindowDidBecomeMainNotification, windowBecameMain:);
  PSObserve(nil, GitExecutableSetNotification, gitPathUpdated);
  PSObserve(nil, BzrExecutableSetNotification, gitPathUpdated);
  ObserveDefaults(KEEP_WINDOWS_ON_TOP_KEY);
  [self loadGitPath];
  [self loadBzrPath];  

  [[GrowlController sharedController] setRepositoryListController: repositoryListController];
  [[GrowlController sharedController] checkGrowlAvailability];

  [self askAboutStats];

  NSNotificationCenter *center = [[NSWorkspace sharedWorkspace] notificationCenter];
  [center addObserver: self
             selector: @selector(wakeupEvent:)
                 name: NSWorkspaceDidWakeNotification
               object: nil];
  [center addObserver: self
             selector: @selector(wakeupEvent:)
                 name: NSWorkspaceSessionDidBecomeActiveNotification
               object: nil];

  [repositoryListController loadRepositories];
  [statusBarController createStatusBarItem];
  [monitor startMonitoring];
  [monitor executeFetch];

  if ([[repositoryListController repositoryList] count] == 0) {
    [self showPreferences: self];
  }
}

- (void) askAboutStats {
  if ([GitifierDefaults boolForKey: SUEnableAutomaticChecksKey]
      && ![GitifierDefaults boolForKey: ASKED_ABOUT_PROFILE_INFO]) {
    NSInteger output = NSRunAlertPanel(
      @"Is it OK if Gitifier sends anonymous system stats (CPU, OS version etc.) with update requests?",
      @"This doesn't include any personal data, just some numbers. You won't be asked about this again.",
      @"Yeah, whatever",
      @"Please don't",
      nil
    );
    if (output == NSAlertDefaultReturn) {
      [GitifierDefaults setBool: YES forKey: SUSendProfileInfoKey];
    }
  }

  [GitifierDefaults setBool: YES forKey: ASKED_ABOUT_PROFILE_INFO];
}

- (void) wakeupEvent: (NSNotification *) notification {
  // on a new day, notify the user about repositories that are still failing
  // also, give the network some time to reconnect after the wakeup
  [repositoryListController performSelector: @selector(resetRepositoryStatuses) withObject: nil afterDelay: 10.0];
}

- (void) windowBecameMain: (NSNotification *) notification {
  NSWindow *window = [notification object];
  window.keepOnTop = [GitifierDefaults boolForKey: KEEP_WINDOWS_ON_TOP_KEY];
}

- (void) observeValueForKeyPath: (NSString *) keyPath
                       ofObject: (id) object
                         change: (NSDictionary *) change
                        context: (void *) context {
  if ([[keyPath lastKeyPathElement] isEqual: KEEP_WINDOWS_ON_TOP_KEY]) {
    BOOL keepOnTop = [GitifierDefaults boolForKey: KEEP_WINDOWS_ON_TOP_KEY];
    NSArray *windows = [NSApp windows];
    NSWindow *mainWindow = nil;
    for (NSWindow *window in windows) {
      if ([window isMainWindow]) {
        mainWindow = window;
      } else {
        window.keepOnTop = keepOnTop;
      }
    }
    mainWindow.keepOnTop = keepOnTop;
  }
}

// --- actions ---

- (IBAction) showPreferences: (id) sender {
  if (!preferencesWindowController) {
    preferencesWindowController = [[PreferencesWindowController alloc] init];
  }

  [NSApp activateIgnoringOtherApps: YES];
  [preferencesWindowController showWindow: self];
}

- (IBAction) checkNow: (id) sender {
  [monitor restartMonitoring];
  [monitor executeFetch];
}

- (IBAction) quit: (id) sender {
  // if quit fails because of an open sheet, move the window to front
  [NSApp performSelector: @selector(activateIgnoringOtherApps:)
              withObject: PSBool(YES)
              afterDelay: 0.1];
  [NSApp terminate: self];
}

// --- user email management ---

- (void) updateUserEmail {
  if (!userEmail && [Git gitExecutable]) {
    Git *git = [[Git alloc] initWithDelegate: self];
    [git runCommand: @"config" withArguments: PSArray(@"user.email") inPath: NSHomeDirectory()];
  }
  if (!userEmail && [Bzr bzrExecutable]) {
    Bzr *bzr = [[Bzr alloc] initWithDelegate: self];
    [bzr runCommand: @"whoami" withArguments: PSArray(@"--emaill") inPath: NSHomeDirectory()];
  }    
}

// --- git path management ---

- (void) loadBzrPath {
    NSString *path = [GitifierDefaults objectForKey: BZR_EXECUTABLE_KEY];
    if (path) {
        [Bzr setBzrExecutable: path];
    } else {
        [self findBzrPath];
    }
}

- (void) loadGitPath {
  NSString *path = [GitifierDefaults objectForKey: GIT_EXECUTABLE_KEY];
  if (path) {
    [Bzr setBzrExecutable: path];
  } else {
    [self findGitPath];
  }
}

- (void) bzrPathUpdated {
    NSString *bzr = [Bzr bzrExecutable];
    if (bzr) {
        [self updateUserEmail];
        [self validateBzrPath];
        [GitifierDefaults setObject: bzr forKey: BZR_EXECUTABLE_KEY];
    } else {
        [GitifierDefaults removeObjectForKey: BZR_EXECUTABLE_KEY];
    }
}

- (void) gitPathUpdated {
  NSString *git = [Git gitExecutable];
  if (git) {
    [self updateUserEmail];
    [self validateGitPath];
    [GitifierDefaults setObject: git forKey: GIT_EXECUTABLE_KEY];
  } else {
    [GitifierDefaults removeObjectForKey: GIT_EXECUTABLE_KEY];
  }
}

- (void) validateBzrPath {
    Bzr *bzr = [[Bzr alloc] initWithDelegate: self];
    [bzr runCommand: @"help" inPath: NSHomeDirectory()];
}

- (void) validateGitPath {
  Git *git = [[Git alloc] initWithDelegate: self];
  [git runCommand: @"version" inPath: NSHomeDirectory()];
}

- (void) findBzrPath {
    NSPipe *inputPipe = [NSPipe pipe];
    NSPipe *outputPipe = [NSPipe pipe];
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/bin/bash";
    task.arguments = PSArray(@"--login", @"-c", @"which bzr");
    task.currentDirectoryPath = NSHomeDirectory();
    task.standardOutput = outputPipe;
    task.standardError = outputPipe;
    task.standardInput = inputPipe;
    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *e) {
        NSRunAlertPanel(@"Error: bash not found.",
                        @"Dude, if you don't even have bash, something is seriously wrong...",
                        @"OMG!", nil, nil);
        return;
    }
    
    NSData *data = [[[task standardOutput] fileHandleForReading] readDataToEndOfFile];
    NSString *output = [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] psTrimmedString];
    
    if (output && (output.length > 0) && (task.terminationStatus == 0)) {
        [Bzr setBzrExecutable: output];
    }
}

- (void) findGitPath {
  NSPipe *inputPipe = [NSPipe pipe];
  NSPipe *outputPipe = [NSPipe pipe];
  NSTask *task = [[NSTask alloc] init];
  task.launchPath = @"/bin/bash";
  task.arguments = PSArray(@"--login", @"-c", @"which git");
  task.currentDirectoryPath = NSHomeDirectory();
  task.standardOutput = outputPipe;
  task.standardError = outputPipe;
  task.standardInput = inputPipe;
  @try {
    [task launch];
    [task waitUntilExit];
  } @catch (NSException *e) {
    NSRunAlertPanel(@"Error: bash not found.",
                    @"Dude, if you don't even have bash, something is seriously wrong...",
                    @"OMG!", nil, nil);
    return;
  }

  NSData *data = [[[task standardOutput] fileHandleForReading] readDataToEndOfFile];
  NSString *output = [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] psTrimmedString];

  if (output && (output.length > 0) && (task.terminationStatus == 0)) {
    [Git setGitExecutable: output];
  }
}

- (void) rejectBzrPath {
    NSRunAlertPanel(@"Incorrect Bzr path",
                    PSFormat(@"The file at %@ is not a Bzr executable.", [Bzr bzrExecutable]),
                    @"OK", nil, nil);
    [Bzr setBzrExecutable: nil];
}

- (void) rejectGitPath {
  NSRunAlertPanel(@"Incorrect Git path",
                  PSFormat(@"The file at %@ is not a Git executable.", [Git gitExecutable]),
                  @"OK", nil, nil);
  [Git setGitExecutable: nil];
}

// --- git command callbacks ---

- (void) commandCompleted: (NSString *) command output: (NSString *) output {
  if ([command isEqual: @"config"] || [command isEqual: @"whoami"]) {
    if (output && output.length > 0) {
      userEmail = [output psTrimmedString];
      PSNotifyWithData(UserEmailChangedNotification, PSHash(@"email", userEmail));
    }
  } else if ([command isEqual: @"version"]) {
    if (!output || ![output isMatchedByRegex: @"^git version \\d"]) {
      [self rejectGitPath];
    }
  } else if ([command isEqual: @"help"]) {
    if (!output || ![output isMatchedByRegex: @"^Bazaar \\d"]) {
      [self rejectGitPath];
    }    
  }
}

- (void) commandFailed: (NSString *) command output: (NSString *) output {
  if ([command isEqual: @"version"]) {
    [self rejectGitPath];
  } else if ([command isEqual: @"help"]) {
      [self rejectBzrPath];
  }
}

// --- repository callbacks ---

- (void) commitsReceived: (NSArray *) commits inRepository: (Repository *) repository {
  BOOL ignoreMerges = [GitifierDefaults boolForKey: IGNORE_MERGES_KEY];
  BOOL ignoreOwnCommits = [GitifierDefaults boolForKey: IGNORE_OWN_COMMITS];

  for (Commit *commit in [commits reverseObjectEnumerator]) {
    if (ignoreMerges && [commit isMergeCommit]) continue;
    if (ignoreOwnCommits && [commit.authorEmail isEqualToString: userEmail]) continue;

    [[GrowlController sharedController] showGrowlWithCommit: commit repository: repository];
  }
}

// these should be rare, only when a fetch fails and a repository needs to be recloned

- (void) repositoryWasCloned: (Repository *) repository {
  [repository fetchNewCommits];
}

- (void) repositoryCouldNotBeCloned: (Repository *) repository {
  [[GrowlController sharedController] showGrowlWithError: @"Cached copy was deleted and can't be restored."
                                              repository: repository];
}

@end
