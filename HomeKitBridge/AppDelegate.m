//
//  AppDelegate.m
//  HomeKitBridge
//
//  Created by Khaos Tian on 7/18/14.
//  Copyright (c) 2014 Oltica. All rights reserved.
//

#import "AppDelegate.h"
#import "OTIContentController.h"
#import "OTIHAPCore.h"
#import "SimpleHue.h"

@interface AppDelegate () <NSTableViewDataSource, NSTableViewDelegate>

@property (weak) IBOutlet NSWindow *window;

@property (strong,nonatomic) OTIContentController *contentController;
@property (strong,nonatomic) OTIHAPCore           *accessoryCore;
@property (strong,nonatomic) SimpleHue            *hueController;

@property (weak) IBOutlet NSTextField *passwordLabel;
@property (weak) IBOutlet NSButton *closeButton;
@property (weak) IBOutlet NSView *contentView;

@property (nonatomic) NSMutableArray *logMessages;
@property (weak) IBOutlet NSTableView *logTableView;


- (IBAction)closeApp:(id)sender;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [_logTableView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleNone];
    
    _logMessages = [NSMutableArray new];
    LOG_MESSAGE(@"Starting Application...");
    
    _closeButton.layer = [CALayer layer];
    _closeButton.layer.backgroundColor = [NSColor whiteColor].CGColor;
    _closeButton.wantsLayer = YES;
    
    _passwordLabel.wantsLayer = YES;
    _passwordLabel.layer.backgroundColor = [NSColor whiteColor].CGColor;
    
    [self setup];
}

-(void)setup {
    _accessoryCore = [[OTIHAPCore alloc]initAsBridge:YES withName:@"Hue Bridge" andSerialNumber:@"F7B47CD5EA72"];
    [_accessoryCore startTransport];
    
    _contentController = [[OTIContentController alloc]init];
    _contentController.view = _contentView;
    
    _passwordLabel.stringValue = _accessoryCore.password;
    
    _hueController = [[SimpleHue alloc]init];
    _hueController.accessoryCore = _accessoryCore;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (IBAction)closeApp:(id)sender {
    [[NSApplication sharedApplication] hide:self];
}

- (IBAction)resetPairings:(id)sender {
    [_accessoryCore resetTransportPairings];
}

- (IBAction)resetData:(id)sender {
    [_accessoryCore clearHomeData];
}

- (IBAction)forceStartSearch:(id)sender {
    
    [_hueController stop];
    
    
    _hueController = [[SimpleHue alloc]init];
    _hueController.accessoryCore = _accessoryCore;
    
    [_hueController startSearch];
}


+ (AppDelegate*)appDelegate {
    return (AppDelegate*)[[NSApplication sharedApplication] delegate];
}

#pragma mark ***** NSTableViewDataSource *****

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _logMessages.count;
}

/* This method is required for the "Cell Based" TableView, and is optional for the "View Based" TableView. If implemented in the latter case, the value will be set to the view at a given row/column if the view responds to -setObjectValue: (such as NSControl and NSTableCellView).
 */
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return _logMessages[row];
}

#pragma mark ***** NSTableViewDataDelegate *****


- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    NSColor *backgroundColor = (rowIndex % 2 == 1) ? [NSColor colorWithRed:0.94 green:0.94 blue:0.94 alpha:1.0] : [NSColor whiteColor];
    [aCell setBackgroundColor:backgroundColor];
    [aCell setDrawsBackground:YES];
}

@end


void LOG_MESSAGE(NSString *logMessage) {
    
    NSDateFormatter *formatter = [NSDateFormatter new];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    
    NSLog(@"%@", logMessage);
    [[AppDelegate appDelegate].logMessages addObject:[NSString stringWithFormat:@"%@ - %@", [formatter stringFromDate:[NSDate date]], logMessage]];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[AppDelegate appDelegate].logTableView reloadData];
    });
}
