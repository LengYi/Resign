//
//  AppPackageInfoManager.h
//  TBRePackaging
//
//  Created by ice on 17/3/31.
//  Copyright © 2017年 tongbu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AppPackageInfoManager : NSObject

// 修改App 包 info.plist 信息 需要修改什么哪个键值,按原始info.plist 的键值传字典即可
+ (void)changeInfoPlistWithDict:(NSDictionary *)dict path:(NSString *)plistPath;

// 添加渠道信息
+ (BOOL)addChannelFileInfo:(NSString *)path channelStr:(NSString *)channel;

// 添加SKUID信息
+ (BOOL)addSkuIDWithPath:(NSString *)path skuID:(NSString *)skuID;

@end
