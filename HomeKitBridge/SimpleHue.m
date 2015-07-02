//
//  SimpleHue.m
//  HomeKitBridge
//
//  Created by Khaos Tian on 7/18/14.
//  Copyright (c) 2014 Oltica. All rights reserved.
//

#import "SimpleHue.h"

#import <AppKit/NSColor.h>
#import <HueSDK_OSX/HueSDK.h>

#import "HueLight.h"

@interface SimpleHue () {
    PHBridgeSearching   *_searchingObject;
    PHHueSDK            *_hueCentral;
    
    NSString            *_hueIP;
    NSString            *_hueMAC;
    
    BOOL                _hasSetup;
    
    NSMutableDictionary *_lights;
}

@end

@implementation SimpleHue

- (id)init {
    self = [super init];
    if (self) {
        _hasSetup = NO;
        _lights = [NSMutableDictionary dictionary];
        _hueCentral = [[PHHueSDK alloc]init];
        [_hueCentral startUpSDK];
        
        
        [[PHNotificationManager defaultManager] registerObject:self withSelector:@selector(localConnection) forNotification:LOCAL_CONNECTION_NOTIFICATION];
        [[PHNotificationManager defaultManager] registerObject:self withSelector:@selector(noLocalConnection) forNotification:NO_LOCAL_CONNECTION_NOTIFICATION];
        [[PHNotificationManager defaultManager] registerObject:self withSelector:@selector(notAuthenticated) forNotification:NO_LOCAL_AUTHENTICATION_NOTIFICATION];
        [[PHNotificationManager defaultManager] registerObject:self withSelector:@selector(authenticationSuccess) forNotification:PUSHLINK_LOCAL_AUTHENTICATION_SUCCESS_NOTIFICATION];
        [[PHNotificationManager defaultManager] registerObject:self withSelector:@selector(authenticationFailed) forNotification:PUSHLINK_LOCAL_AUTHENTICATION_FAILED_NOTIFICATION];
        
        [self enableLocalHeartbeat];
    }
    return self;
}

- (void)stop {
    [_hueCentral stopSDK];
    
    [[PHNotificationManager defaultManager] deregisterObject:self forNotification:LOCAL_CONNECTION_NOTIFICATION];
    [[PHNotificationManager defaultManager] deregisterObject:self forNotification:NO_LOCAL_CONNECTION_NOTIFICATION];
    [[PHNotificationManager defaultManager] deregisterObject:self forNotification:NO_LOCAL_AUTHENTICATION_NOTIFICATION];
    [[PHNotificationManager defaultManager] deregisterObject:self forNotification:PUSHLINK_LOCAL_AUTHENTICATION_SUCCESS_NOTIFICATION];
    [[PHNotificationManager defaultManager] deregisterObject:self forNotification:PUSHLINK_LOCAL_AUTHENTICATION_FAILED_NOTIFICATION];
}

- (void)localConnection {
    [self updateLights];
}

- (void)noLocalConnection {
    LOG_MESSAGE(@"No Local Connection");
}

- (void)notAuthenticated {
    LOG_MESSAGE(@"Not Authenticated");
    [self doAuthentication];
}

- (void)authenticationSuccess {
    LOG_MESSAGE(@"Authentication Success!");
    [self setupLights];
    [self performSelector:@selector(enableLocalHeartbeat) withObject:nil afterDelay:1];
}

- (void)authenticationFailed {
    LOG_MESSAGE(@"Authentication Failed");
}

- (void)updateLights {
    if (!_hasSetup) {
        _hasSetup = YES;
        [self setupLights];
    }else{
        for (PHLight *light in [PHBridgeResourcesReader readBridgeResourcesCache].lights.allValues) {
            HueLight *huelight = _lights[light.name];
            [huelight updateLightValueWithLight:light];
        }
    }
}

- (void)setupLights {
    for (PHLight *light in [PHBridgeResourcesReader readBridgeResourcesCache].lights.allValues) {
        HueLight *huelight = [[HueLight alloc]initWithHAPCore:_accessoryCore HueLight:light];
        [_lights setObject:huelight forKey:light.name];
    }
}

- (void)startSearch {
    _searchingObject = [[PHBridgeSearching alloc] initWithUpnpSearch:YES andPortalSearch:YES andIpAdressSearch:YES];
    [_searchingObject startSearchWithCompletionHandler:^(NSDictionary *bridgesFound) {
        if (bridgesFound.count > 0) {
            
            int i = 1;
            for (NSString *key in bridgesFound) {
                LOG_MESSAGE([NSString stringWithFormat:@"Bridge %d Found:%@ - %@",i, key, bridgesFound[key]]);
                i++;
            }
            
            NSString *macAddress = bridgesFound.allKeys.firstObject;
            [self setBridgeWithIP:bridgesFound[macAddress] andMAC:macAddress];
        }else{
            LOG_MESSAGE([NSString stringWithFormat:@"No bridges found"]);
        }
    }];
}

- (void)enableLocalHeartbeat {
    /***************************************************
     The heartbeat processing collects data from the bridge
     so now try to see if we have a bridge already connected
     *****************************************************/
    
    PHBridgeResourcesCache *cache = [PHBridgeResourcesReader readBridgeResourcesCache];
    if (cache != nil && cache.bridgeConfiguration != nil && cache.bridgeConfiguration.ipaddress != nil) {
        
        // Enable heartbeat with interval of 3 seconds
        [_hueCentral enableLocalConnectionUsingInterval:3];
    } else {
        // Automaticly start searching for bridges
        [self startSearch];
    }
}

- (void)doAuthentication {
    // Disable heartbeats
    [_hueCentral disableLocalConnection];
    [_hueCentral startPushlinkAuthentication];
}

- (void)setBridgeWithIP:(NSString *)ipAddress andMAC:(NSString *)macAddress {
    if (ipAddress && macAddress) {
        _hueIP = [ipAddress copy];
        _hueMAC = [macAddress copy];
        [_hueCentral setBridgeToUseWithIpAddress:_hueIP macAddress:_hueMAC];
    }
}

@end
