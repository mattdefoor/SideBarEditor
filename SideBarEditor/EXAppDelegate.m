//
//  EXAppDelegate.m
//  SideBarEditor
//
//  Created by Matt DeFoor on 3/5/14.
//  Copyright (c) 2014 Matt DeFoor. All rights reserved.
//

#import "EXAppDelegate.h"
#import "EXShareListItemCustomProperties.h"

@implementation EXAppDelegate

@synthesize _tableView;
@synthesize _tableContents;

#pragma mark -Startup Methods-
- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
  // Register for dragged types for drag and drop. We only accept NSURL types.
  [_tableView registerForDraggedTypes: [NSArray arrayWithObjects:NSURLPboardType, nil]];
  [_tableView setDoubleAction:@selector(openPath)];
  [_tableView setTarget:self];
  
  _tableContents = [[NSMutableArray alloc] init];

  [self readSidebar];
}

#pragma mark -Action Methods-

- (IBAction)refreshAction:(id)sender
{
  [self readSidebar];
}

- (IBAction)addItem:(id)sender
{
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  
  [panel setCanChooseFiles:NO];
  [panel setCanChooseDirectories:YES];
  [panel setAllowsMultipleSelection:YES];
  [panel setMessage:@"Select one or more directories."];
  
  // This method displays the panel and returns immediately.
  // The completion handler is called when the user selects an
  // item or cancels the panel.
  [panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result)
  {
    if (result == NSFileHandlingPanelOKButton)
    {
      NSArray *urls = [panel URLs];
      
      for (NSURL *url in urls)
      {
        CFBooleanRef boolRef = kCFBooleanTrue;
        NSDictionary *dictionary = [[NSDictionary alloc] initWithObjectsAndKeys:(__bridge id)(boolRef), @"Managed", nil];
        
        [self addToSharedList:url
                         type:(__bridge NSString *)kLSSharedFileListFavoriteItems
                   atPosition:kLSSharedFileListItemLast
               withDictionary:dictionary];
      }
    }
  }];
}

- (IBAction)removeItem:(id)sender
{
  if ([_tableView selectedRow] != -1)
  {
    EXShareListItemCustomProperties *item = [_tableContents objectAtIndex:[_tableView selectedRow]];
    
    if ([self removeFromSharedList:[item url] type:nil name:[item name]])
    {
      NSLog(@"Removed item \'%@\' for path \'%@\' from sidebar.", [item name], [[item url] path]);
      [self readSidebar];
    }
  }
}

- (void)openPath
{
  NSInteger row = [_tableView clickedRow];
  
  if (row != -1)
  {
    EXShareListItemCustomProperties *item = [_tableContents objectAtIndex:row];
    [[NSWorkspace sharedWorkspace] openURL:[item url]];
  }
}

#pragma mark -Tableview Methods-
// The only essential/required tableview dataSource method
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
  return [_tableContents count];
}

// This method is optional if you use bindings to provide the data
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
  // Group our "model" object, which is an EXShareListItemCustomProperties
  EXShareListItemCustomProperties *item = [_tableContents objectAtIndex:row];
  
  NSString *identifier = [tableColumn identifier];
  
  if ([identifier isEqualToString:@"MainCell"])
  {
    // We pass us as the owner so we can setup target/actions into this main controller object
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];
    
    // Then setup properties on the cellView based on the column
    cellView.textField.stringValue = [item name];
    cellView.imageView.objectValue = [item icon];
    
    return cellView;
  }
  else if ([identifier isEqualToString:@"PathCell"])
  {
    NSTableCellView *pathView = [tableView makeViewWithIdentifier:identifier owner:self];
    
    pathView.textField.objectValue = [[item url] path];
    
    return pathView;
  }
  else if ([identifier isEqualToString:@"Managed"])
  {
    // Get the checkbox from the table column so we can set it's value.
    NSButton *checkbox = [tableView makeViewWithIdentifier:identifier owner:self];

    [checkbox setState:[item managed]];
    
    return checkbox;
  }
  else
  {
    NSAssert1(NO, @"Unhandled table column identifier %@", identifier);
  }
  
  return nil;
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)op
{
  if (row > [_tableContents count])
    return NSDragOperationNone;
  
  if (nil == [info draggingSource]) // From other application
  {
    [tv setDropRow: row dropOperation: NSTableViewDropAbove];
    return NSDragOperationCopy;
  }
  
  return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
  NSPasteboard* pboard = [info draggingPasteboard];
  
  if ([[pboard types] containsObject:NSURLPboardType])
  {
    NSURL *fileURL = [NSURL URLFromPasteboard:pboard];

    NSNumber *isDirectory;
    [fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];

    if ([isDirectory boolValue])
    {
      CFBooleanRef boolRef = kCFBooleanTrue;
      NSDictionary *dictionary = [[NSDictionary alloc] initWithObjectsAndKeys:(__bridge id)(boolRef), @"Managed", nil];

      if ([self addToSharedList:fileURL
                       type:(__bridge NSString *)kLSSharedFileListFavoriteItems
                 atPosition:kLSSharedFileListItemLast
                 withDictionary:dictionary])
      {
        [self readSidebar];
      }
    }
  }
  
  return YES;
}

- (void)readSidebar
{
  LSSharedFileListRef sflRef = [self sharedFileListRef:(__bridge NSString *)kLSSharedFileListFavoriteItems];
  
  if (!sflRef)
  {
    return;
  }
  
  [_tableContents removeAllObjects];
  
  UInt32 seed;
  
  NSArray *list = (__bridge NSArray *)LSSharedFileListCopySnapshot(sflRef, &seed);
  
  for (NSObject *object in list)
  {
    LSSharedFileListItemRef sflItemRef = (__bridge LSSharedFileListItemRef)object;
    
    CFStringRef nameRef = LSSharedFileListItemCopyDisplayName(sflItemRef);
    
    CFURLRef urlRef = NULL;
    LSSharedFileListItemResolve(sflItemRef, kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes, &urlRef, NULL);
    
    NSString *aliasPath = (NSString*)CFBridgingRelease(CFURLCopyFileSystemPath(urlRef, kCFURLPOSIXPathStyle));
    
    UInt32 itemId = LSSharedFileListItemGetID(sflItemRef);
    
    printf("%i\t%s\t%s\n", itemId, [(__bridge NSString*)nameRef UTF8String], [aliasPath UTF8String]);
    
    NSImage *icon = nil;
    
    IconRef iconRef = LSSharedFileListItemCopyIconRef(sflItemRef);
    if (iconRef)
    {
      // Make a copy
      icon = [[NSImage alloc] initWithIconRef:iconRef];
      
      // Docs say must release
      ReleaseIconRef(iconRef);
    }

    // Get Property dictionary?
    CFBooleanRef booleanRef = LSSharedFileListItemCopyProperty(sflItemRef, CFSTR("Managed"));
    
    EXShareListItemCustomProperties *item = [[EXShareListItemCustomProperties alloc] init];
    
    [item setItemId:[NSNumber numberWithInt:itemId]];
    [item setName:(__bridge NSString *)nameRef];
    [item setIcon:icon];
    [item setUrl:(__bridge NSURL *)urlRef];
    
    if (booleanRef)
    {
      [item setManaged:CFBooleanGetValue(booleanRef)];
    }
    
    [_tableContents addObject:item];

    CFRelease(urlRef);
    CFRelease(nameRef);
  }
  
  CFRelease(sflRef);
  
  [_tableView reloadData];
}

- (BOOL)addToSharedList:(NSURL *)url
{
  return [self addToSharedList:url type:nil atPosition:nil withDictionary:nil];
}

- (BOOL)addToSharedList:(NSURL *)url type:(NSString *)type
{
  return [self addToSharedList:url type:type atPosition:nil withDictionary:nil];
}

- (BOOL)addToSharedList:(NSURL *)url type:(NSString *)type atPosition:(LSSharedFileListItemRef)position
{
  return [self addToSharedList:url type:type atPosition:position withDictionary:nil];
}

- (BOOL)addToSharedList:(NSURL *)url type:(NSString *)type atPosition:(LSSharedFileListItemRef)position withDictionary:(NSDictionary *)dictionary
{
  BOOL bOK = NO;
  
  if (!url)
  {
    return bOK;
  }

  // Get reference to shared file list. Don't forget to release it if not null!
  LSSharedFileListRef sflRef = [self sharedFileListRef:type];
  
  if (!sflRef)
  {
    return bOK;
  }

  if (!type)
  {
    type = (__bridge NSString *)kLSSharedFileListFavoriteItems;
  }

  if (!position)
  {
    position = kLSSharedFileListItemLast;
  }
  
  // Actual insertion of an item.
  LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(sflRef, position, NULL, NULL, (__bridge CFURLRef)url, (__bridge CFDictionaryRef)dictionary, NULL);
  
  // Clean up in case of success
  if (item)
  {
    bOK = YES;
    CFRelease(item);
  }

  CFRelease(sflRef);
  
  return bOK;
}

- (BOOL)removeFromSharedList:(NSURL *)url type:(NSString *)type name:(NSString *)name
{
  if (!url && !name)
  {
    return NO;
  }

  if (!type)
  {
    type = (__bridge NSString *)kLSSharedFileListFavoriteItems;
  }

  // Get reference to shared file list. Don't forget to release it if not null!
  LSSharedFileListRef sflRef = [self sharedFileListRef:type];
  
  if (!sflRef)
  {
    return NO;
  }

  OSStatus status = noErr;
  UInt32 seed;
  
  NSArray *list = (__bridge NSArray *)LSSharedFileListCopySnapshot(sflRef, &seed);
  
  for (NSObject *object in list)
  {
    LSSharedFileListItemRef sflItemRef = (__bridge LSSharedFileListItemRef)object;
    
    CFStringRef nameRef = LSSharedFileListItemCopyDisplayName(sflItemRef);
    
    CFURLRef urlRef = NULL;
    LSSharedFileListItemResolve(sflItemRef, kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes, &urlRef, NULL);
    
    NSString *aliasPath = (NSString *)CFBridgingRelease(CFURLCopyFileSystemPath(urlRef, kCFURLPOSIXPathStyle));
    
    if ([[url path] caseInsensitiveCompare:aliasPath] == NSOrderedSame &&
        [(__bridge NSString *)nameRef caseInsensitiveCompare:name] == NSOrderedSame)
    {
      status = LSSharedFileListItemRemove(sflRef, sflItemRef);
    }
    
    CFRelease(urlRef);
    CFRelease(nameRef);
  }

  CFRelease(sflRef);
  
  return status == noErr;
}

- (LSSharedFileListRef)sharedFileListRef:(NSString *)type
{
  // Reference to shared file list. Caller is responsible for releasing returned
  // LSSharedFileListRef per the LaunchServices LSSharedFileList.h file.
  LSSharedFileListRef sflItemRef = LSSharedFileListCreate(NULL, (__bridge CFStringRef)type, NULL);
  
  return sflItemRef;
}

@end
