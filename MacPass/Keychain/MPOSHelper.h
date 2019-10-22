//
//  MPOSHelper.h
//  MacPass
//
//  Created by Lucas Paul on 28/08/2017.
//  Copyright © 2017 HicknHack Software GmbH. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@import LocalAuthentication;
#import "MPOSHelper.h"
#import "MPDocument.h"
#import "SAMKeychain.h"
#import "SAMKeychainQuery.h"
#import "MPSettingsHelper.h"

@interface MPOSHelper : NSObject

+(BOOL)supportsTouchID;
-(void)askForTouchID:(NSString*)password document:(NSString *)doc;
-(void)deletePasswordFromKeychain:(NSString *)doc;

@end
