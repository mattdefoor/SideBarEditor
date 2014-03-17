//
//  EXSharedListManager.h
//  SideBarEditor
//
//  Created by Matt DeFoor on 3/13/14.
//  Copyright (c) 2014 Matt DeFoor. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EXSharedListManager : NSObject
{
  @private
    UInt32 _seed;
    NSString *_listType;
    LSSharedFileListRef _listRef;
}

@property (nonatomic) UInt32 _seed;
@property (readonly) NSString *_listType;
@property (readonly) LSSharedFileListRef _listRef;

- (id)initWithListType:(NSString *)type;
- (void)dealloc;

- (NSArray *)copyListItems;

- (BOOL)addToList:(NSURL *)url;
- (BOOL)addToList:(NSURL *)url atPosition:(LSSharedFileListItemRef)position;
- (BOOL)addToList:(NSURL *)url atPosition:(LSSharedFileListItemRef)position withDictionary:(NSDictionary *)dictionary;

- (BOOL)removeFromList:(NSURL *)url;
- (BOOL)removeFromList:(NSURL *)url withName:(NSString *)name;

- (void)addListObserver:(NSRunLoop *)runLoop runLoopMode:(NSString *)mode callback:(void *)callback context:(void *)context;
- (void)removeListObserver:(NSRunLoop *)runLoop runLoopMode:(NSString *)mode callback:(void *)callback context:(void *)context;

@end
