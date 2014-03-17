//
//  EXSharedListManager.m
//  SideBarEditor
//
//  Created by Matt DeFoor on 3/13/14.
//  Copyright (c) 2014 Matt DeFoor. All rights reserved.
//

#import "EXSharedListManager.h"

@implementation EXSharedListManager

@synthesize _seed;
@synthesize _listType;
@synthesize _listRef;

#pragma mark -Startup Methods-

- (id)initWithListType:(NSString *)type
{
  self = [super init];
  
  if (self)
  {
    _listType = [type copy];

    _listRef = LSSharedFileListCreate(NULL, (__bridge CFStringRef)_listType, NULL);
    
    _seed = LSSharedFileListGetSeedValue(_listRef);
  }
  
  return self;
}

#pragma mark -Shutdown Methods-

- (void)dealloc
{
  CFRelease(_listRef);
}

#pragma mark -Public Methods-

- (NSArray *)copyListItems
{
  UInt32 seed;
  
  return (__bridge NSArray *)LSSharedFileListCopySnapshot(_listRef, &seed);
}

- (BOOL)addToList:(NSURL *)url
{
  return [self addToList:url atPosition:nil withDictionary:nil];
}

- (BOOL)addToList:(NSURL *)url atPosition:(LSSharedFileListItemRef)position
{
  return [self addToList:url atPosition:position withDictionary:nil];
}

- (BOOL)addToList:(NSURL *)url atPosition:(LSSharedFileListItemRef)position withDictionary:(NSDictionary *)dictionary
{
  // NSURL parameter is required.
  if (!url) return NO;
  
  if (!position)
  {
    position = kLSSharedFileListItemLast;
  }
  
  // Actual insertion of an item.
  LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(_listRef, position, NULL, NULL, (__bridge CFURLRef)url, (__bridge CFDictionaryRef)dictionary, NULL);
  
  // Clean up in case of success
  if (item)
  {
    CFRelease(item);
    return YES;
  }
  
  return NO;
}

- (BOOL)removeFromList:(NSURL *)url
{
  return [self removeFromList:url withName:nil];
}

- (BOOL)removeFromList:(NSURL *)url withName:(NSString *)name
{
  // NSURL parameter is required.
  if (!url) return NO;
  
  OSStatus status = noErr;
 
  BOOL bUseName = name != nil;

  NSArray *list = [self copyListItems];
  
  for (NSObject *object in list)
  {
    status = noErr;
    
    LSSharedFileListItemRef sflItemRef = (__bridge LSSharedFileListItemRef)object;
    
    CFStringRef nameRef = NULL;
    
    if (bUseName)
    {
      nameRef = LSSharedFileListItemCopyDisplayName(sflItemRef);
    }
    
    CFURLRef urlRef = NULL;
    LSSharedFileListItemResolve(sflItemRef, kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes, &urlRef, NULL);
    
    NSString *aliasPath = (NSString *)CFBridgingRelease(CFURLCopyFileSystemPath(urlRef, kCFURLPOSIXPathStyle));

    if (bUseName)
    {
      if ([[url path] caseInsensitiveCompare:aliasPath] == NSOrderedSame &&
          [(__bridge NSString *)nameRef caseInsensitiveCompare:name] == NSOrderedSame)
      {
        status = LSSharedFileListItemRemove(_listRef, sflItemRef);
      }
    }
    else
    {
      if ([[url path] caseInsensitiveCompare:aliasPath] == NSOrderedSame)
      {
        status = LSSharedFileListItemRemove(_listRef, sflItemRef);
      }
    }

    CFRelease(nameRef);
    CFRelease(urlRef);
  }

  CFRelease((CFArrayRef)list);
  
  return status == noErr;
}

- (void)addListObserver:(NSRunLoop *)runLoop runLoopMode:(NSString *)mode callback:(void *)callback context:(void *)context
{
  // NOTE: NSRunLoop and CFRunLoopRef are not toll-free bridged! Take the
  // NSRunLoop and get the CFRunLoopRef from it.
  LSSharedFileListAddObserver(_listRef, [runLoop getCFRunLoop], (__bridge CFStringRef)mode, callback, context);
}

- (void)removeListObserver:(NSRunLoop *)runLoop runLoopMode:(NSString *)mode callback:(void *)callback context:(void *)context
{
  // NOTE: NSRunLoop and CFRunLoopRef are not toll-free bridged! Take the
  // NSRunLoop and get the CFRunLoopRef from it.
  LSSharedFileListRemoveObserver(_listRef, [runLoop getCFRunLoop], (__bridge CFStringRef)mode, callback, context);
}


@end
