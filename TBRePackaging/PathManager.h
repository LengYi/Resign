//
//  PathManager.h
//  TBRePackaging
//
//  Created by ice on 17/3/31.
//  Copyright © 2017年 tongbu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PathManager : NSObject

+ (NSString *)workingPath;
+ (NSString *)unzipPath;
//  payload 路径
+ (NSString *)payloadPath;
// .app 路径
+ (NSString *)appPath;
+ (NSString *)infoPlistPath;
+ (NSMutableArray *)searchInfoPlistPath;
+ (NSString *)ItunesMedataInfoPlistPath;
+ (NSString *)entitlementsPath;
+ (NSString *)mobileprovisionPath;
+ (NSString *)channelPath;
+ (NSString *)skuIDPath;
// 遍历需要被签名的文件路径
+ (NSMutableArray *)getCodeSignPathArray;
@end
