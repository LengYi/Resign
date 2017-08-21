//
//  AppPackageInfoManager.m
//  TBRePackaging
//
//  Created by ice on 17/3/31.
//  Copyright © 2017年 tongbu. All rights reserved.
//

#import "AppPackageInfoManager.h"

@implementation AppPackageInfoManager
+ (void)changeItunesMetadatainfoPlist:(NSDictionary *)dict path:(NSString *)path{
    [self changeInfoPlistWithDict:dict path:path];
}

// 需要修改info.plist的什么值就用 参数字典key就用对应的,value使用新的即可
+ (void)changeInfoPlistWithDict:(NSDictionary *)dict path:(NSString *)plistPath{
    
    NSMutableDictionary *plistdict = [self getOriginPlistDict:plistPath];
    
    NSArray *array = dict.allKeys;
    if (array && array.count > 0) {
        for (NSString *key in array) {
            id newValue = dict[key];
            if (newValue) {
                [plistdict setObject:newValue forKey:key];
            }
        }
    }
    
    [plistdict writeToFile:plistPath atomically:YES];
}

+ (BOOL)addChannelFileInfo:(NSString *)path channelStr:(NSString *)channel{
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
    
    NSData *channelData = [channel dataUsingEncoding:NSASCIIStringEncoding];
    
    if (channelData) {
        return [channelData writeToFile:path atomically:YES];
    }
    
    return NO;
}

+ (BOOL)addSkuIDWithPath:(NSString *)path skuID:(NSString *)skuID{
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
    
    NSData *skuData = [skuID dataUsingEncoding:NSASCIIStringEncoding];
    if (skuData) {
        return [skuData writeToFile:path atomically:YES];
    }
    
    return NO;
}

+ (NSMutableDictionary *)getOriginPlistDict:(NSString *)plistPath{
    NSMutableDictionary *plistDic = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:plistPath]){
        plistDic = [[NSMutableDictionary alloc] initWithContentsOfFile:plistPath];
    }
    
    return plistDic;
}

@end
