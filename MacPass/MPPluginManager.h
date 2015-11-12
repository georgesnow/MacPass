//
//  MPPluginManager.h
//  MacPass
//
//  Created by Michael Starke on 16/07/15.
//  Copyright (c) 2015 HicknHack Software GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString *const MPPluginManagerWillLoadPlugin;
FOUNDATION_EXPORT NSString *const MPPluginManagerDidLoadPlugin;
FOUNDATION_EXPORT NSString *const MPPluginManagerWillUnloadPlugin;
FOUNDATION_EXPORT NSString *const MPPluginManagerDidUnloadPlugin;

FOUNDATION_EXPORT NSString *const MPPluginManagerPluginBundleIdentifiyerKey;

@class KPKNode;
@class MPPlugin;

@interface MPPluginManager : NSObject

@property (readonly, copy) NSArray <MPPlugin __kindof*> *plugins;
@property (nonatomic, readonly) BOOL loadUnsecurePlugins;

typedef BOOL (^NodeMatchBlock)(KPKNode *aNode);

+ (instancetype)sharedManager;

- (instancetype)init NS_UNAVAILABLE;

- (NSArray *)filteredEntriesUsingBlock:(NodeMatchBlock) matchBlock;
- (NSArray *)filteredGroupsUsingBlock:(NodeMatchBlock) matchBlock;

@end
