//
//  EXAppDelegate.h
//  SideBarEditor
//
//  Created by Matt DeFoor on 3/5/14.
//  Copyright (c) 2014 Matt DeFoor. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class EXSharedListManager;

@interface EXAppDelegate : NSObject <NSTableViewDelegate, NSTableViewDataSource>

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSTableView *_tableView;
@property (weak) IBOutlet NSButton *refreshAction;

@property NSMutableArray *_tableContents;
@property EXSharedListManager *_listManager;

- (void)readSidebar;
- (void)openPath;

@end
