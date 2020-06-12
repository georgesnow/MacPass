//
//  MPPasswordInputController.m
//  MacPass
//
//  Created by Michael Starke on 17.02.13.
//  Copyright (c) 2013 HicknHack Software GmbH. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import "MPPasswordInputController.h"
#import "MPAppDelegate.h"
#import "MPDocumentWindowController.h"
#import "MPDocument.h"
#import "MPSettingsHelper.h"
#import "MPPathControl.h"
#import "MPTouchBarButtonCreator.h"

#import "HNHUi/HNHUi.h"

#import "NSError+Messages.h"
#import "SAMKeychain.h"
#import "SAMKeychainQuery.h"
#import "MPOSHelper.h"

@interface MPPasswordInputController ()

@property (strong) NSButton *showPasswordButton;
@property (weak) IBOutlet HNHUISecureTextField *passwordTextField;
@property (weak) IBOutlet MPPathControl *keyPathControl;
@property (weak) IBOutlet NSImageView *messageImageView;
@property (weak) IBOutlet NSTextField *messageInfoTextField;
@property (strong) IBOutlet NSTextField *keyFileWarningTextField;
@property (weak) IBOutlet NSButton *togglePasswordButton;
@property (weak) IBOutlet NSButton *enablePasswordCheckBox;
@property (weak) IBOutlet NSButton *unlockButton;
@property (weak) IBOutlet NSButton *cancelButton;
@property (weak) IBOutlet NSButton *authenticateButton;

@property (copy) NSString *message;
@property (copy) NSString *cancelLabel;

@property (assign) BOOL showPassword;
@property (nonatomic, assign) BOOL enablePassword;
@property (nonatomic, assign) BOOL enableTID;
@property (copy) passwordInputCompletionBlock completionHandler;
@property (nonatomic, readonly) NSString *databaseName;
@property (weak) IBOutlet NSButton *useTouchIdButton;
@property (strong) IBOutlet NSButton *touchidEnabled;
@property (weak) IBOutlet NSButtonCell *touchidEnable;
@property (nonatomic) BOOL touchIDCheckButton;

@end

@implementation MPPasswordInputController

- (NSString *)nibName {
  return @"PasswordInputView";
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if(self) {
    _enablePassword = YES;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(_selectKeyURL) name:MPDidChangeStoredKeyFilesSettings object:nil];
  }
  return self;
}

- (void)dealloc {
  [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)viewDidLoad {
  [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(_didSetKeyURL:) name:MPPathControlDidSetURLNotification object:self.keyPathControl];
  self.messageImageView.image = [NSImage imageNamed:NSImageNameCaution];
  [self.passwordTextField bind:NSStringFromSelector(@selector(showPassword)) toObject:self withKeyPath:NSStringFromSelector(@selector(showPassword)) options:nil];
  [self.togglePasswordButton bind:NSValueBinding toObject:self withKeyPath:NSStringFromSelector(@selector(showPassword)) options:nil];
  [self.enablePasswordCheckBox bind:NSValueBinding toObject:self withKeyPath:NSStringFromSelector(@selector(enablePassword)) options:nil];
  [self.togglePasswordButton bind:NSEnabledBinding toObject:self withKeyPath:NSStringFromSelector(@selector(enablePassword)) options:nil];
  [self.passwordTextField bind:NSEnabledBinding toObject:self withKeyPath:NSStringFromSelector(@selector(enablePassword)) options:nil];
  [self _reset];
  if ([MPSettingsHelper.touchIdEnabledDatabases containsObject:self.databaseName]) {
    self.touchidEnabled.state = NSOnState;
    _touchIDCheckButton = [MPSettingsHelper.touchIdEnabledDatabases containsObject:self.databaseName];
    return;
  } else {
    self.touchidEnabled.state = NSOffState;
    _touchIDCheckButton = [MPSettingsHelper.touchIdEnabledDatabases containsObject:self.databaseName];
  }
}

-(void)viewDidAppear {
  [super viewDidAppear];
  [self _enableTouchID]; //Maybe call this when the password text field is focused and not on viewDidAppear...
}

- (NSResponder *)reconmendedFirstResponder {
  return self.passwordTextField;
}

- (void)requestPasswordWithMessage:(NSString *)message cancelLabel:(NSString *)cancelLabel completionHandler:(passwordInputCompletionBlock)completionHandler {
  self.completionHandler = completionHandler;
  self.message = message;
  self.cancelLabel = cancelLabel;
  [self _reset];
}

- (void)requestPasswordWithCompletionHandler:(passwordInputCompletionBlock)completionHandler {
  [self requestPasswordWithMessage:nil cancelLabel:nil completionHandler:completionHandler];
}

#pragma mark Properties
- (void)setEnablePassword:(BOOL)enablePassword {
  if(_enablePassword != enablePassword) {
    _enablePassword = enablePassword;
    if(!_enablePassword) {
      self.passwordTextField.stringValue = @"";
    }
  }
  if(_enablePassword) {
    self.passwordTextField.placeholderString = NSLocalizedString(@"PASSWORD_INPUT_ENTER_PASSWORD", "Placeholder in the unlock-password input field if password is enabled");
  }
  else {
    self.passwordTextField.placeholderString = NSLocalizedString(@"PASSWORD_INPUT_NO_PASSWORD", "Placeholder in the unlock-password input field if password is disabled");
  }
}


- (NSString*) databaseName {
//  MPDocumentWindowController *documentWindow = self.windowController;
//  Pointer needs to be fixed - possible fix:
  NSWindowController *documentWindow = self.windowController;
  MPDocument *document = documentWindow.document;
  return document.displayName;
}

#pragma mark -
#pragma mark Private
- (IBAction)_submit:(id)sender {
  if(!self.completionHandler) {
    return;
  }
  
  /* No password is different than an empty password */
  NSError *error = nil;
  NSString *password = self.enablePassword ? self.passwordTextField.stringValue : nil;
  
  BOOL cancel = (sender == self.cancelButton);
  BOOL result = self.completionHandler(password, self.keyPathControl.URL, cancel, &error);
  if(cancel || result) {
    return;
  }
  [self _showError:error];
  /* do not shake if we are a sheet */
  if(!self.view.window.isSheet) {
    [self.view.window shakeWindow:nil];
  }
}

- (IBAction)resetKeyFile:(id)sender {
  /* If the reset was triggered by ourselves we want to preselect the keyfile */
  if(sender == self) {
    [self _selectKeyURL];
  }
  else {
    self.keyPathControl.URL = nil;
  }
}

- (void)_reset {
  self.showPassword = NO;
  self.enablePassword = YES;
  self.passwordTextField.stringValue = @"";
  self.messageInfoTextField.hidden = (nil == self.message);
  if(self.message) {
    self.messageInfoTextField.stringValue = self.message;
    self.messageImageView.image = [NSImage imageNamed:NSImageNameInfo];
  }
  else {
    self.messageImageView.image = [NSImage imageNamed:NSImageNameCaution];
  }
  self.messageImageView.hidden = (nil == self.message);
  self.cancelButton.hidden = (nil == self.cancelLabel);
  if(self.cancelLabel) {
    self.cancelButton.stringValue = self.cancelLabel;
  }
  [self resetKeyFile:self];
}

- (void)_selectKeyURL {
  MPDocument *document = self.windowController.document;
  self.keyPathControl.URL = document.suggestedKeyURL;
}

- (void)_showError:(NSError *)error {
  if(error) {
    self.messageInfoTextField.stringValue = error.descriptionForErrorCode;
  }
  self.messageImageView.hidden = NO;
  self.messageImageView.image = [NSImage imageNamed:NSImageNameCaution];
  self.messageInfoTextField.hidden = NO;
}
- (IBAction)showTouchIdDialog:(id)sender {
  [self _enableTouchID];
}
- (IBAction)enableTIDforDB:(id)sender {
  [self _enableTouchID];
}

- (NSTouchBar *)makeTouchBar {
  NSTouchBar *touchBar = [[NSTouchBar alloc] init];
  touchBar.delegate = self;
  touchBar.customizationIdentifier = MPTouchBarCustomizationIdentifierPasswordInput;
  NSArray<NSTouchBarItemIdentifier> *defaultItemIdentifiers = @[MPTouchBarItemIdentifierShowPassword, MPTouchBarItemIdentifierChooseKeyfile, NSTouchBarItemIdentifierFlexibleSpace,MPTouchBarItemIdentifierUnlock];
  touchBar.defaultItemIdentifiers = defaultItemIdentifiers;
  touchBar.customizationAllowedItemIdentifiers = defaultItemIdentifiers;
  return touchBar;
}

- (NSTouchBarItem *)touchBar:(NSTouchBar *)touchBar makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier  API_AVAILABLE(macos(10.12.2)) {
  if (identifier == MPTouchBarItemIdentifierChooseKeyfile) {
    return [MPTouchBarButtonCreator touchBarButtonWithTitleAndImage:NSLocalizedString(@"TOUCHBAR_CHOOSE_KEYFILE","Touchbar button label for choosing the keyfile") identifier:MPTouchBarItemIdentifierChooseKeyfile image:[NSImage imageNamed:NSImageNameTouchBarFolderTemplate] target:self.keyPathControl selector:@selector(showOpenPanel:) customizationLabel:NSLocalizedString(@"TOUCHBAR_CHOOSE_KEYFILE","Touchbar button label for choosing the keyfile")];
  } else if (identifier == MPTouchBarItemIdentifierShowPassword) {
    NSTouchBarItem *item = [MPTouchBarButtonCreator touchBarButtonWithTitleAndImage:NSLocalizedString(@"TOUCHBAR_SHOW_PASSWORD","Touchbar button label for showing the password") identifier:MPTouchBarItemIdentifierShowPassword image:[NSImage imageNamed:NSImageNameTouchBarQuickLookTemplate] target:self selector:@selector(toggleShowPassword) customizationLabel:NSLocalizedString(@"TOUCHBAR_SHOW_PASSWORD","Touchbar button label for showing the password")];
    _showPasswordButton = (NSButton *) item.view;
    return item;
  } else if (identifier == MPTouchBarItemIdentifierUnlock) {
    return [MPTouchBarButtonCreator touchBarButtonWithImage:[NSImage imageNamed:NSImageNameLockUnlockedTemplate] identifier:MPTouchBarItemIdentifierUnlock target:self selector:@selector(_submit:) customizationLabel:NSLocalizedString(@"TOUCHBAR_UNLOCK_DATABASE","Touchbar button label for unlocking the database")];
  } else {
    return nil;
  }
}

- (void)toggleShowPassword {
  self.showPassword = !self.showPassword;
  if (@available(macOS 10.12.2, *)) {
    _showPasswordButton.bezelColor = self.showPassword ? [NSColor selectedControlColor] : [NSColor controlColor];
  }
}


- (void)_enableTouchID {

  if (![MPSettingsHelper.touchIdEnabledDatabases containsObject:self.databaseName]) {
    [_useTouchIdButton setHidden:YES];
    self.touchidEnabled.state = NSOffState;
    return; //Do not ask for TouchID if its not enabled for this database.
  } else if (MPOSHelper.supportsTouchID) {
        LAContext *myContext = [LAContext new];
        NSString *myLocalizedReasonString = NSLocalizedString(@"TOUCHBAR_TOUCH_ID_MESSAGE", @"");
    if (@available(macOS 10.12.2, *)) {
      [myContext evaluatePolicy:LAPolicyDeviceOwnerAuthentication localizedReason:myLocalizedReasonString reply:^(BOOL success, NSError * _Nullable error) {
        if (success) {
          // User authenticated successfully, take appropriate action
          NSLog(@"User authentication sucessful! Getting password from the keychain...");
          [self _getPasswordFromKeychain];
        } else {
          //updating UI in background requires to happen on main thread
          dispatch_async(dispatch_get_main_queue(), ^{
            self.authenticateButton.hidden = NO;

            });

          // User did not authenticate successfully, look at error and take appropriate action
          NSLog(@"User authentication failed. %@", error.localizedDescription);
        }
      }];
    }
  } else if ([MPSettingsHelper.touchIdEnabledDatabases containsObject:self.databaseName] && !MPOSHelper.supportsTouchID) {
    NSLog(@"Else - getting password from keychain");
//    [self _getPasswordFromKeychain];
    [_useTouchIdButton setHidden:NO];
    self.touchidEnabled.state = NSOnState;
  } else {
    NSLog(@"Skipped Touch ID and Keychain authentication");
  }
}
//  if (MPOSHelper.supportsTouchID) {
//    LAContext *myContext = [LAContext new];
//    NSString *myLocalizedReasonString = NSLocalizedString(@"TOUCHBAR_TOUCH_ID_MESSAGE", @"");
//    [myContext evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:myLocalizedReasonString reply:^(BOOL success, NSError * _Nullable error) {
//      if (success) {
//        // User authenticated successfully, take appropriate action
//        NSLog(@"User authentication sucessful! Getting password from the keychain...");
//        [self _getPasswordFromKeychain];
//      } else {
//        // User did not authenticate successfully, look at error and take appropriate action
//        NSLog(@"User authentication failed. %@", error.localizedDescription);
//      }
//    }];
//  } else {
//    NSLog(@"TouchID is not supported.");
//  }
- (IBAction)unlockTrigger:(id)sender {
  if (self.touchidEnabled.state && [MPSettingsHelper.touchIdEnabledDatabases containsObject:self.databaseName]) {
    [self performSelector:@selector(unlockViaTouchID)];
  } else {
    NSLog(@"touchid not setup");
  }
}

- (IBAction)reAuthenticateTouchId:(id)sender {
    [self performSelector:@selector(unlockViaTouchID)];
}

-(void)unlockViaTouchID {
  if (MPOSHelper.supportsTouchID) {
    LAContext *myContext = [LAContext new];
    NSString *myLocalizedReasonString = NSLocalizedString(@"TOUCHBAR_TOUCH_ID_MESSAGE", @"");
    if (@available(macOS 10.12.2, *)) {
      [myContext evaluatePolicy:LAPolicyDeviceOwnerAuthentication localizedReason:myLocalizedReasonString reply:^(BOOL success, NSError * _Nullable error) {
        if (success) {
          // User authenticated successfully, take appropriate action
          NSLog(@"User authentication sucessful! Getting password from the keychain...");
          [self _getPasswordFromKeychain];
        } else {
          // User did not authenticate successfully, look at error and take appropriate action
          NSLog(@"User authentication failed. %@", error.localizedDescription);
        }
      }];
    } else if ([MPSettingsHelper.touchIdEnabledDatabases containsObject:self.databaseName] && !MPOSHelper.supportsTouchID) {
      NSLog(@"Else - getting password from keychain");
      [self _getPasswordFromKeychain];
    } else {
      NSLog(@"Skipped Touch ID and Keychain authentication");
    }
  } else if ([MPSettingsHelper.touchIdEnabledDatabases containsObject:self.databaseName] && !MPOSHelper.supportsTouchID) {
    NSLog(@"Else - getting password from keychain");
    [self _getPasswordFromKeychain];
  } else {
    NSLog(@"Skipped Touch ID and Keychain authentication");
  }
}

- (void) _getPasswordFromKeychain{
//  NSString *passwordItem = [SAMKeychain passwordForService:@"MacPass" account:self.databaseName];
//  __autoreleasing NSError *err = nil;



//  static dispatch_once_t onceToken;
//  dispatch_once(&onceToken, ^{
//      NSString *passwordItem = [SAMKeychain passwordForService:@"MacPass" account:self.databaseName];
//    __autoreleasing NSError *err = nil;
//    if (err != nil) {
//      NSLog(@"Could not retrieve DB password from the keychain:");
//    } else {
//      dispatch_sync(dispatch_get_main_queue(), ^{
//
//        self->_passwordTextField.stringValue = passwordItem;
//        [self _submit:nil];
//      });
//    }
//  });
  NSError *error = nil;
  SAMKeychainQuery *query = [[SAMKeychainQuery alloc] init];
  query.service = @"MacPass";
  query.account = self.databaseName;
  [query fetch:&error];

  if ([error code] == errSecItemNotFound) {
    NSLog(@"Not password found for current database in the keychain");
  } else if (error !=nil) {
    NSLog(@"Erro retrieving password for current database from the keychain");
  }  else {
    NSString *passwordItem = [SAMKeychain passwordForService:@"MacPass" account:self.databaseName];
    if(!passwordItem.kpk_isNotEmpty){
      NSLog(@"Password field was empty on retrieval from the keychain");
    } else {
    dispatch_async(dispatch_get_main_queue(), ^{
      self.passwordTextField.stringValue = passwordItem;
      [self _submit:nil];
    });
    }
  }
  
  //old test method for filling out password...need to dispatch on the main thread...
//  NSString *passwordItem = [SAMKeychain passwordForService:@"MacPass" account:self.databaseName];
//  if ([passwordItem kpk_isNotEmpty]){
//
//    _passwordTextField.stringValue = passwordItem;
//    [self _submit:nil];
//  }
//  else {
//    NSLog(@"Could not retrieve DB password from the keychain");
//  }


  
}
- (IBAction)turnOnTouchID:(NSString *)password {
  MPOSHelper *helper = [[MPOSHelper alloc] init];
  BOOL buttonState = self.touchidEnabled.state;
  if (![MPSettingsHelper.touchIdEnabledDatabases containsObject:self.databaseName]) {
    
    
    password = self.passwordTextField.stringValue;
    if (password.kpk_isNotEmpty) {
      [helper askForTouchID:password document:self.databaseName];
      self.touchidEnabled.state = NSOnState;
      [_useTouchIdButton setHidden:NO];
    } else
      NSLog(@"password field is empty");
      self.touchidEnabled.state = NSOffState;
    //Do not ask for TouchID if its not enabled for this database.
  } else if (buttonState) {
    NSLog(@"remove keychain");
    [helper deletePasswordFromKeychain:self.databaseName];
    self.touchidEnabled.state = NSOffState;
    [_useTouchIdButton setHidden:YES];
  } else
    NSLog(@"else");
    [helper deletePasswordFromKeychain:self.databaseName];
    self.touchidEnabled.state = NSOffState;
    [_useTouchIdButton setHidden:YES];
  
}

- (void)_didSetKeyURL:(NSNotification *)notification {
  if(notification.object != self.keyPathControl) {
    return; // wrong sender
  }
  NSDocument *document = (NSDocument *)self.windowController.document;
  NSData *keyFileData = [NSData dataWithContentsOfURL:self.keyPathControl.URL];
  KPKFileVersion keyFileVersion = [KPKFormat.sharedFormat fileVersionForData:keyFileData];
  BOOL isKdbDatabaseFile = (keyFileVersion.format != KPKDatabaseFormatUnknown);
  if(isKdbDatabaseFile) {
    if([document.fileURL isEqual:self.keyPathControl.URL]) {
      self.keyFileWarningTextField.stringValue = NSLocalizedString(@"WARNING_CURRENT_DATABASE_FILE_SELECTED_AS_KEY_FILE", "Error message displayed when the current database file is also set as the key file");
      self.keyFileWarningTextField.hidden = NO;
    }
    else {
      self.keyFileWarningTextField.stringValue = NSLocalizedString(@"WARNING_DATABASE_FILE_SELECTED_AS_KEY_FILE", "Error message displayed when a keepass database file is set as the key file");
      self.keyFileWarningTextField.hidden = NO;
    }
  }
  else {
    self.keyFileWarningTextField.stringValue = @"";
    self.keyFileWarningTextField.hidden = YES;

  }
}
@end
