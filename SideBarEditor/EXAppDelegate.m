//
//  EXAppDelegate.m
//  SideBarEditor
//
//  Created by Matt DeFoor on 3/5/14.
//  Copyright (c) 2014 Matt DeFoor. All rights reserved.
//

#import "EXAppDelegate.h"
#import "EXShareListItemCustomProperties.h"
#import "EXSharedListManager.h"

@implementation EXAppDelegate (Private)

static void EXSharedFileListChangedCallback(LSSharedFileListRef inList, void *context)
{
  EXAppDelegate *object = (__bridge EXAppDelegate *)context;
  [object readSidebar];
}

@end

@implementation EXAppDelegate

@synthesize _tableView;
@synthesize _tableContents;
@synthesize _listManager;

#pragma mark -Startup Methods-

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
  // Register for dragged types for drag and drop. We only accept NSURL types.
  [_tableView registerForDraggedTypes: [NSArray arrayWithObjects:NSURLPboardType, nil]];
  [_tableView setDoubleAction:@selector(openPath)];
  [_tableView setTarget:self];
  
  _tableContents = [[NSMutableArray alloc] init];

  _listManager = [[EXSharedListManager alloc] initWithListType:(__bridge NSString *)kLSSharedFileListFavoriteItems];
  
  if (_listManager)
  {
    [_listManager addListObserver:[NSRunLoop currentRunLoop] runLoopMode:NSDefaultRunLoopMode callback:EXSharedFileListChangedCallback context:(__bridge void *)(self)];
  }
  
  [self readSidebar];
}

#pragma mark -Shutdown Methods-

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
  [_listManager removeListObserver:[NSRunLoop currentRunLoop] runLoopMode:NSDefaultRunLoopMode callback:EXSharedFileListChangedCallback context:(__bridge void *)(self)];
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
        [_listManager addToList:url atPosition:kLSSharedFileListItemLast withDictionary:dictionary];
      }
    }
  }];
}

- (IBAction)removeItem:(id)sender
{
  if ([_tableView selectedRow] != -1)
  {
    EXShareListItemCustomProperties *item = [_tableContents objectAtIndex:[_tableView selectedRow]];
    
    if ([_listManager removeFromList:[item url] withName:[item name]])
    {
      [self readSidebar];
    }
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
      
      if ([_listManager addToList:fileURL atPosition:kLSSharedFileListItemLast withDictionary:dictionary])
      {
        [self readSidebar];
      }
    }
  }
  
  return YES;
}

#pragma mark -Application Methods-

- (void)readSidebar
{
  [_tableContents removeAllObjects];
  
  NSArray *list = [_listManager copyListItems];
  
  for (NSObject *object in list)
  {
    LSSharedFileListItemRef sflItemRef = (__bridge LSSharedFileListItemRef)object;
    
    CFStringRef nameRef = LSSharedFileListItemCopyDisplayName(sflItemRef);
    
    CFURLRef urlRef = NULL;

    LSSharedFileListItemResolve(sflItemRef, kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes, &urlRef, NULL);
    
    UInt32 itemId = LSSharedFileListItemGetID(sflItemRef);
    
    NSImage *icon;
    
    IconRef iconRef = LSSharedFileListItemCopyIconRef(sflItemRef);
    if (!iconRef)
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

  CFRelease((CFArrayRef)list);

  [_tableView reloadData];
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

@end
