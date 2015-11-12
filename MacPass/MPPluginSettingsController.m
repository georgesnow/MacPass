//
//  MPPluginSettingsController.m
//  MacPass
//
//  Created by Michael Starke on 09/11/15.
//  Copyright © 2015 HicknHack Software GmbH. All rights reserved.
//

#import "MPPluginSettingsController.h"
#import "MPPluginManager.h"
#import "MPPlugin.h"

#import "MPSettingsHelper.h"

NSString *const _kMPPluginTableNameColumn = @"Name";

@interface MPPluginSettingsController () <NSTableViewDataSource, NSTableViewDelegate>

@property (weak) IBOutlet NSTableView *pluginTableView;
@property (weak) IBOutlet NSView *settingsView;
@property (weak) IBOutlet NSButton *loadInsecurePlugsinCheckButton;

@end

@implementation MPPluginSettingsController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if(self) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_didChangePlugins:)
                                                 name:MPPluginManagerWillLoadPlugin
                                               object:[MPPluginManager sharedManager]];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_didChangePlugins:)
                                                 name:MPPluginManagerDidLoadPlugin
                                               object:[MPPluginManager sharedManager]];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_didChangePlugins:)
                                                 name:MPPluginManagerWillUnloadPlugin
                                               object:[MPPluginManager sharedManager]];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_didChangePlugins:)
                                                 name:MPPluginManagerDidUnloadPlugin
                                               object:[MPPluginManager sharedManager]];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSString *)nibName {
  return @"PluginSettings";
}

- (NSString *)identifier {
  return @"Plugins";
}

- (NSImage *)image {
  return [NSImage imageNamed:NSImageNameApplicationIcon];
}

- (NSString *)label {
  return NSLocalizedString(@"PLUGIN_SETTINGS", "");
}

- (void)didLoadView {
  self.pluginTableView.tableColumns[0].identifier = _kMPPluginTableNameColumn;

  self.pluginTableView.delegate = self;
  self.pluginTableView.dataSource = self;
  
  [self.loadInsecurePlugsinCheckButton bind:NSValueBinding
                                   toObject:[NSUserDefaultsController sharedUserDefaultsController]
                                withKeyPath:[MPSettingsHelper defaultControllerPathForKey:kMPSettingsKeyLoadUnsecurePlugins]
                                    options:nil];
  
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
  return [MPPluginManager sharedManager].plugins.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
  if(![tableColumn.identifier isEqualToString:_kMPPluginTableNameColumn]) {
    return nil;
  }
  MPPlugin *plugin = [self pluginForRow:row];
  NSTableCellView *view = [tableView makeViewWithIdentifier:@"NameCell" owner:nil];
  view.textField.stringValue = plugin.name;
  return view;
}

- (void)showSettingsForPlugin:(MPPlugin *)plugin {
  /* move old one regardless */
  [self.settingsView.subviews.firstObject removeFromSuperview];
  if([plugin conformsToProtocol:@protocol(MPPluginSettings)]) {
    NSAssert([plugin respondsToSelector:@selector(settingsViewController)], @"Required getter for settings on plugins");
    NSViewController *viewController = ((id<MPPluginSettings>)plugin).settingsViewController;
    [self.settingsView addSubview:viewController.view];
    NSDictionary *dict = @{ @"view" : viewController.view,
                            @"table" : self.pluginTableView.enclosingScrollView };
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[view]-|" options:0 metrics:nil views:dict]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[view]-|" options:0 metrics:nil views:dict]];
  }
}

- (MPPlugin *)pluginForRow:(NSInteger)row {
  NSArray<MPPlugin __kindof *> *plugins = [MPPluginManager sharedManager].plugins;
  if(0 > row || row >= plugins.count) {
    return nil;
  }
  return plugins[row];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
  NSTableView *table = notification.object;
  [self showSettingsForPlugin:[self pluginForRow:table.selectedRow]];
}


- (void)_didChangePlugins:(NSNotification *)notification {
  /* better way? */
  [self.pluginTableView deselectAll:self];
  [self.pluginTableView reloadData];
}

@end
