// -------------------------------------------------------
// Repository.h
//
// Copyright (c) 2010 Jakub Suder <jakub.suder@gmail.com>
// Licensed under MIT license
// -------------------------------------------------------

#import <Foundation/Foundation.h>

@class Repository;

@protocol RepositoryDelegate
- (void) commitsReceived: (NSArray *) commits inRepository: (Repository *) repository;
@end

// ------------------------------

@class Git;

@interface Repository : NSObject {
  Git *git;
}

@property (copy) NSString *url;
@property id delegate;

// public
- (id) initWithUrl: (NSString *) anUrl;
- (void) clone;
- (void) fetchNewCommits;
- (void) cancelCommands;

// private
- (BOOL) isProperUrl: (NSString *) url;
- (NSString *) cachesDirectory;
- (NSString *) workingCopyDirectory;
- (void) notifyDelegateWithSelector: (SEL) selector;
- (BOOL) ensureDirectoryIsDeleted: (NSString *) directory;
- (BOOL) ensureDirectoryExists: (NSString *) directory;

@end