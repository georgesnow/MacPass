
//
//  MPOSHelper.m
//  MacPass
//
//  Created by Lucas Paul on 28/08/2017.
//  Copyright © 2017 HicknHack Software GmbH. All rights reserved.
//

#import "MPOSHelper.h"
#import "MPDocument.h"
#import "SAMKeychain.h"
#import "SAMKeychainQuery.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "MPSettingsHelper.h"

@implementation MPOSHelper

+(BOOL)supportsTouchID {
  LAContext *myContext = [LAContext new];

  NSError *authError = nil;

  if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber10_11_4) {
    if (@available(macOS 10.12.2, *)) {
      if ([myContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&authError]) {
        if (authError == nil) {
          return YES;
        }
      } else {
        // Could not evaluate policy; look at authError and present an appropriate message to user
        NSLog(@"Could not evaluate authentication policy: %@", authError.localizedDescription);
        if (authError.localizedFailureReason != nil) {
          NSLog(@"Failure Reason: %@", authError.localizedFailureReason);
        }
      }
    } else {
      // Fallback on earlier versions
      return NO;
    }
  }

  return NO;
}

-(void) askForTouchID:(NSString*)password document:(NSString *)doc {
  NSError *authError = nil;
  LAContext *myContext = [LAContext new];
  if (@available(macOS 10.12.2, *)) {
    if ([myContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&authError]) {
      
      NSAlert *alert = [NSAlert new];
      [alert addButtonWithTitle:@"Yes"];
      [alert addButtonWithTitle:@"No"];
      alert.messageText = NSLocalizedString(@"ALERT_TOUCH_ID_MESSAGE", @"");
      alert.informativeText = NSLocalizedString(@"ALERT_TOUCH_ID_DESCRIPTION", @"");
      [alert setAlertStyle:NSAlertStyleInformational];
      
      if ([alert runModal] == NSAlertFirstButtonReturn) {
        // Yes clicked, use TouchID
        [self _savePasswordInKeychain:password document:doc];
      } else {
        NSLog(@"User denied Touch ID. Deleting password from keychain.");
        [self deletePasswordFromKeychain:doc];
      }
    }
    else {
      NSAlert *alert = [NSAlert new];
      [alert addButtonWithTitle:@"Yes"];
      [alert addButtonWithTitle:@"No"];
      alert.messageText = NSLocalizedString(@"ALERT_TOUCH_ID_MESSAGE", @"");
      alert.informativeText = NSLocalizedString(@"ALERT_TOUCH_ID_DESCRIPTION", @"");
      [alert setAlertStyle:NSAlertStyleInformational];
      
      if ([alert runModal] == NSAlertFirstButtonReturn) {
        // Yes clicked, use TouchID
        [self _savePasswordInKeychain:password document:doc];
      } else {
        NSLog(@"User denied Touch ID. Deleting password from keychain.");
        [self deletePasswordFromKeychain:doc];
      }
    }
  }
  else {
    // Fallback on earlier versions
    
  }
}
- (void) _savePasswordInKeychain:(NSString*)password document:(NSString *)dbName {
//  MPDocument *document = doc;
  //  Uses document name -- could also attach file path
  //  However, if the file is move and/or filename is changes it will fail
//  NSString *dbName = document.displayName;
  NSError *error = nil;
  
  [SAMKeychain setPassword:password forService:@"MacPass" account:dbName];
  
  
  if (error == nil) {
    [MPSettingsHelper addTouchIdEnabledDatabaseWithName:dbName]; //Add DB name in the list of Touch ID enabled databases
    NSLog(@"Saved DB (%@) password in the keychain.", dbName);
  } else {
    NSLog(@"Error updating keychain with DB password: %@", error.localizedDescription);
  }
}

- (void) deletePasswordFromKeychain:(NSString *)dbName {
//  MPDocument *document = doc;
  //  Uses document name -- could also attach file path
  //  However, if the file is moved and/or the filename is changed it will fail
//  NSString *dbName = document.displayName;
  NSError *error = nil;
  
  
  
  if (error == nil) {
    [SAMKeychain deletePasswordForService:@"MacPass" account:dbName];
    [MPSettingsHelper removeTouchIdEnabledDatabaseWithName:dbName]; //Remove DB name from the list of Touch ID enabled databases
    NSLog(@"DB (%@) password deleted from keychain.", dbName);
  } else {
    NSLog(@"Error deleting DB password from the keychain: %@", error.localizedDescription);
  }
}

@end
