//
//  HueLight.m
//  HomeKitBridge
//
//  Created by Khaos Tian on 7/18/14.
//  Copyright (c) 2014 Oltica. All rights reserved.
//

#import "HueLight.h"
#import <CommonCrypto/CommonDigest.h>
#import "HAKIdentifyCharacteristic.h"
#import "HAKCharacteristic.h"
#import "HAKAccessory.h"
#import "HAKService.h"
#import "HAKUUID.h"

@interface HueLight () {
    HAKCharacteristic* _state;
    HAKCharacteristic* _brightness;
    HAKCharacteristic* _hue;
    HAKCharacteristic* _saturation;
    BOOL               _pendingUpdate;
}

@end

@implementation HueLight

- (id)initWithHAPCore:(OTIHAPCore *)core HueLight:(PHLight *)hueLight {
    
    if (core == nil) {
        return nil;
    }
    
    self = [self init];
    
    if (self) {
        _pendingUpdate = NO;
        _accessoryCore = core;
        _huelight = hueLight;
        _lightAccesory = [_accessoryCore addAccessory:[self getLightAccessoryWithName:_huelight.name]];
        [self processLightAccessory];
    }
    
    return self;
}

- (void)processLightAccessory {
    HAKService* lightService = [_lightAccesory serviceWithType:[[HAKUUID alloc] initWithUUIDString:@"00000043"]];
    if (lightService) {
        _state = [lightService characteristicWithType:[[HAKUUID alloc] initWithUUIDString:@"00000025"]];
        _brightness = [lightService characteristicWithType:[[HAKUUID alloc] initWithUUIDString:@"00000008"]];
        _hue = [lightService characteristicWithType:[[HAKUUID alloc] initWithUUIDString:@"00000013"]];
        _saturation = [lightService characteristicWithType:[[HAKUUID alloc] initWithUUIDString:@"0000002F"]];
        
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(characteristicDidUpdateValueNotification:) name:@"HAKCharacteristicDidUpdateValueNotification" object:_state];
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(characteristicDidUpdateValueNotification:) name:@"HAKCharacteristicDidUpdateValueNotification" object:_brightness];
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(characteristicDidUpdateValueNotification:) name:@"HAKCharacteristicDidUpdateValueNotification" object:_hue];
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(characteristicDidUpdateValueNotification:) name:@"HAKCharacteristicDidUpdateValueNotification" object:_saturation];

    }
    
    [self updateLightValue];
}

- (void)updateLightValue {
    if (!_pendingUpdate) {
        PHLightState *lightState = _huelight.lightState;
        if (_brightness.value != lightState.brightness) {
            _brightness.value = @((lightState.brightness.floatValue/254)*100.0);
        }
        
        if (_hue.value != lightState.hue) {
            _hue.value = @((lightState.hue.floatValue/65535)*360.0);
        }
        
        if (_state.value != lightState.on) {
            _state.value = lightState.on;
        }
        
        if (_saturation.value != lightState.saturation) {
            _saturation.value = @((lightState.saturation.floatValue/254)*100.0);
        }
    }else{
        _pendingUpdate = NO;
    }
}

- (void)updateLightValueWithLight:(PHLight *)hueLight {
    _huelight = hueLight;
    [self updateLightValue];
}

- (HAKAccessory *)getLightAccessoryWithName:(NSString *)name {
    HAKAccessory *accessory = [_accessoryCore createHueAccessoryWithUUID:[self sha1:name] Name:name];
    return accessory;
}

- (void)characteristicDidUpdateValueNotification:(NSNotification *)aNote {
    PHLightState *currentLightState = _huelight.lightState;
    HAKCharacteristic *characteristic = aNote.object;
    if ([characteristic.service.accessory isEqual:_lightAccesory]) {
        if ([characteristic isKindOfClass:[HAKIdentifyCharacteristic class]]) {
            id value = aNote.userInfo[@"HAKCharacteristicValueKey"];
            if ([value isKindOfClass:[NSNumber class]]) {
                if ([value isEqualToNumber: @1]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        PHLightState *lightState = [[PHLightState alloc] init];
                        [lightState setAlert:ALERT_LSELECT];
                        [currentLightState setAlert:ALERT_LSELECT];
                        [[[[PHOverallFactory alloc] init] bridgeSendAPI] updateLightStateForId:_huelight.identifier withLighState:lightState completionHandler:^(NSArray *errors) {
                            if (errors) {
                                LOG_MESSAGE([NSString stringWithFormat: @"ERROR:%@",errors]);
                            }
                        }];
                    });
                }else{
                    dispatch_async(dispatch_get_main_queue(), ^{
                        PHLightState *lightState = [[PHLightState alloc] init];
                        [lightState setAlert:ALERT_NONE];
                        [currentLightState setAlert:ALERT_NONE];
                        [[[[PHOverallFactory alloc] init] bridgeSendAPI] updateLightStateForId:_huelight.identifier withLighState:lightState completionHandler:^(NSArray *errors) {
                            if (errors) {
                                LOG_MESSAGE([NSString stringWithFormat:@"ERROR:%@",errors]);
                            }
                        }];
                    });
                }
            }
        }
        if (characteristic == _state) {
            id value = aNote.userInfo[@"HAKCharacteristicValueKey"];
            if ([value isKindOfClass:[NSNumber class]]) {
                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                    if (![currentLightState.on isEqualToNumber:value]) {
                        LOG_MESSAGE([NSString stringWithFormat:@"UpdateOn:%@",value]);
                        _pendingUpdate = YES;
                        PHLightState *lightState = [[PHLightState alloc] init];
                        [lightState setOn:value];
                        [currentLightState setOn:value];
                        [[[[PHOverallFactory alloc] init] bridgeSendAPI] updateLightStateForId:_huelight.identifier withLighState:lightState completionHandler:^(NSArray *errors) {
                            if (errors) {
                                LOG_MESSAGE([NSString stringWithFormat:@"ERROR:%@",errors]);
                            }
                        }];
                    }
                });
            }
        }
        if (characteristic == _hue) {
            id value = aNote.userInfo[@"HAKCharacteristicValueKey"];
            if ([value isKindOfClass:[NSNumber class]]) {
                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                    if (![currentLightState.hue isEqualToNumber:value]) {
                        LOG_MESSAGE([NSString stringWithFormat:@"UpdateHue:%@",value]);
                        int hueConverted = ([value intValue]/360.0)*65535;
                        
                        _pendingUpdate = YES;
                        PHLightState *lightState = [[PHLightState alloc] init];
                        
                        [lightState setHue:@(hueConverted)];
                        [currentLightState setHue:@(hueConverted)];
                        [[[[PHOverallFactory alloc] init] bridgeSendAPI] updateLightStateForId:_huelight.identifier withLighState:lightState completionHandler:^(NSArray *errors) {
                            if (errors) {
                                LOG_MESSAGE([NSString stringWithFormat:@"ERROR:%@",errors]);
                            }
                        }];
                    }
                });
            }
        }
        if (characteristic == _saturation) {
            id value = aNote.userInfo[@"HAKCharacteristicValueKey"];
            if ([value isKindOfClass:[NSNumber class]]) {
                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                    if (![currentLightState.saturation isEqualToNumber:value]) {
                        LOG_MESSAGE([NSString stringWithFormat:@"UpdateSaturation:%@",value]);
                        int satConverted = ([value intValue]/100.0)*254;
                        
                        _pendingUpdate = YES;
                        PHLightState *lightState = [[PHLightState alloc] init];
                        [lightState setSaturation:@(satConverted)];
                        [currentLightState setSaturation:@(satConverted)];
                        [[[[PHOverallFactory alloc] init] bridgeSendAPI] updateLightStateForId:_huelight.identifier withLighState:lightState completionHandler:^(NSArray *errors) {
                            if (errors) {
                                LOG_MESSAGE([NSString stringWithFormat:@"ERROR:%@",errors]);
                            }
                        }];
                    }
                });
            }
        }
        if (characteristic == _brightness) {
            id value = aNote.userInfo[@"HAKCharacteristicValueKey"];
            if ([value isKindOfClass:[NSNumber class]]) {
                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                    if (![currentLightState.brightness isEqualToNumber:value]) {
                        LOG_MESSAGE([NSString stringWithFormat:@"UpdateBrightness:%@",value]);
                        int brightConverted = ([value intValue]/100.0)*254;
                        
                        _pendingUpdate = YES;
                        PHLightState *lightState = [[PHLightState alloc] init];
                        [lightState setBrightness:@(brightConverted)];
                        [currentLightState setBrightness:@(brightConverted)];
                        [[[[PHOverallFactory alloc] init] bridgeSendAPI] updateLightStateForId:_huelight.identifier withLighState:lightState completionHandler:^(NSArray *errors) {
                            if (errors) {
                                LOG_MESSAGE([NSString stringWithFormat:@"ERROR:%@",errors]);
                            }
                        }];
                    }
                });
            }
        }
    }
}

-(NSString*) sha1:(NSString*)input
{
    const char *cstr = [input cStringUsingEncoding:NSUTF8StringEncoding];
    NSData *data = [NSData dataWithBytes:cstr length:input.length];
    
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    
    CC_SHA1(data.bytes, (unsigned int)data.length, digest);
    
    NSMutableString* output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    
    return output;
    
}

@end
