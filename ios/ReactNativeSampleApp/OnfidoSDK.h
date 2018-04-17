//
//  RCTOnfidoFlow.h
//  ReactNativeSampleApp
//
//  Created by Anurag Ajwani on 16/04/2018.
//  Copyright © 2018 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>

@interface OnfidoSDK: NSObject<RCTBridgeModule>

+ (void)startSDK;

- (id)init;
- (void)run;

@end