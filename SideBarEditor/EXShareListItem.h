//
//  EXShareListItem.h
//  SideBarEditor
//
//  Created by Matt DeFoor on 3/8/14.
//  Copyright (c) 2014 Matt DeFoor. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EXShareListItem : NSObject

@property NSNumber *itemId;
@property NSString *name;
@property NSURL *url;
@property NSImage *icon;

@end
