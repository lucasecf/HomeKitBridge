//
//  AppDelegate.h
//  HomeKitBridge
//
//  Created by Khaos Tian on 7/18/14.
//  Copyright (c) 2014 Oltica. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

+ (AppDelegate*)appDelegate;

@end

void LOG_MESSAGE(NSString *logMessage);