//
//  EXAppDelegate.h
//  SideBarEditor
//
//  Created by Matt DeFoor on 3/5/14.
//  Copyright (c) 2014 Matt DeFoor. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface EXAppDelegate : NSObject <NSTableViewDelegate, NSTableViewDataSource>

@property (assign) IBOutlet NSWindow *window;

@property (weak) IBOutlet NSTableView *_tableView;

@property (retain) NSMutableArray *_tableContents;
@property (weak) IBOutlet NSButton *refreshAction;

@end
