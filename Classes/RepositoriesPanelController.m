// -------------------------------------------------------
// RepositoriesPanelController.m
//
// Copyright (c) 2011 Jakub Suder <jakub.suder@gmail.com>
// Licensed under Eclipse Public License v1.0
// -------------------------------------------------------

#import "Git.h"
#import "Bzr.h"
#import "RepositoriesPanelController.h"
#import "RepositoryListController.h"

@implementation RepositoriesPanelController

@synthesize repositoryListController;

- (id) init {
  return [super initWithNibName: @"RepositoriesPreferencesPanel" bundle: nil];
}

- (NSString *) toolbarItemIdentifier {
  return @"Repositories";
}

- (NSImage *) toolbarItemImage {
  return [NSImage imageNamed: NSImageNameNetwork];
}

- (NSString *) toolbarItemLabel {
  return @"Repositories";
}

- (id) gitClass {
  return [Git class];
}

- (id) bzrClass {
    return [Bzr class];
}

- (IBAction) removeRepositories: (id) sender {
  [repositoryListController removeSelectedRepositories];
}

@end
