//
//  OTIHAPCore.h
//  HomeKitBridge
//
//  Created by Khaos Tian on 7/18/14.
//  Copyright (c) 2014 Oltica. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OTIContentController.h"

@class HAKAccessory;

@interface OTIHAPCore : NSObject

- (id)initAsBridge:(BOOL)isBridge withName:(NSString*)name andSerialNumber:(NSString*)serialNumber;
- (void)startTransport;

- (void)resetTransportPairings;
- (void)clearHomeData;
- (void)removeAllAccessories;

- (HAKAccessory *)addAccessory:(HAKAccessory *)accessory;
- (HAKAccessory *)createHueAccessoryWithUUID:(NSString *)uuid Name:(NSString *)name;
- (NSString *)password;

@end
