//
//  PackageHandler.m
//  TBRePackaging
//
//  Created by zeejun on 15-4-8.
//  Copyright (c) 2015年 tongbu. All rights reserved.
//

#import "PackageHandler.h"
#import "Package.h"
#import "Channel.h"

@implementation PackageHandler

+ (BOOL)checkPackage:(NSString *)content
{
    return YES;
}

//将字符串双换行跟分割
+ (NSArray*)dividStr:(NSString *)content withSeparater:(NSString *)separater
{
    NSArray *strs = [content componentsSeparatedByString:separater];
    return strs;
}

+ (NSArray *)anaylyzeChannel:(NSString *)channelStr
{
    channelStr = [channelStr stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
    NSMutableArray *array = [NSMutableArray array];
    NSArray *lines = [PackageHandler dividStr:channelStr withSeparater:@"\n"];
    for (NSString *aLineStr in lines) {
        NSArray *item = [PackageHandler dividStr:aLineStr withSeparater:@":"];
        if (item.count == 2) {
            Channel *channel = [[Channel alloc]init];
            channel.name = [item objectAtIndex:0];
            channel.text = [item objectAtIndex:1];
            
            [array addObject:channel];
        }
    }
    return array;
}

+ (void)anaylyzeBaseInfo:(NSString *)baseInfoStr
{
    
}

//根据字符串，返回单个Package对象
+ (void)anaylyzePackage:(NSString *)packageContent completeHandler:(void(^)(Package *aPackage, NSError *error))handler
{
    Package *package = [[Package alloc]init];
    
    NSRange range = [packageContent rangeOfString:PackageChannels];
    if (range.length > 0) {
        NSString *channelStr = [packageContent substringFromIndex:range.location +range.length+1];
        [package.channelArray addObjectsFromArray:[PackageHandler anaylyzeChannel:channelStr]];
    }
    
    NSArray *lines = [PackageHandler dividStr:packageContent withSeparater:@"\n"];
    for (NSString *aLineStr in lines) {
        NSRange range = [aLineStr rangeOfString:@":"];
        if (range.length > 0)
        {
            NSString *key = [aLineStr substringToIndex:range.location];
            NSString *value = [aLineStr substringFromIndex:range.location + range.length];
            
            if ([key isEqualToString:PackageBaseDir])
            {
                package.baseDir = value;
            }else if ([key isEqualToString:PackageName])
            {
                package.packageName = value;
            }
            else if ([key isEqualToString:PackageSourcePath])
            {
                package.sourcePath = value;
                
            }else if ([key isEqualToString:PackageCertificate])
            {
                package.certificate = value;
                
            }else if ([key isEqualToString:PackageIdentifier])
            {
                package.identifier = value;
                
            }else if([key isEqualToString:PackagePlistIdentifier]){
                package.infoplistIdentifier = value;
            }
            else if ([key isEqualToString:PackageShortVersion])
            {
                package.shortVersion = value;
                
            }else if ([key isEqualToString:PackageBundleVersion])
            {
                package.bundleVersion = value;
            }else if ([key isEqualToString:PackageEntitlementsPath])
            {
                package.entitlementsPath = value;
            }else if([key isEqualToString:PackageProvisionPath])
            {
                package.provisionPath = value;
            }else if([key isEqualToString:PackageDeviceType]){
                package.deviceType = value;
            }
        }else
        {
            
        }
        
    }
    
    if (package.baseDir && package.packageName) {
        package.outPutPath = [package.baseDir stringByAppendingPathComponent:package.packageName];
    }
    
    handler(package,nil);
}

+ (void)anaylyzeWithBase:(NSString *)baseContent packageContents:(NSString *)packageContents completeHandler:(void(^)(NSArray *array,NSError *error))handler
{
    //先解析通用属性
    __block Package *basePackage = nil;
    [PackageHandler anaylyzePackage:baseContent completeHandler:^(Package *package, NSError *error) {
        basePackage = package;
    }];
    
    NSArray *array = [PackageHandler dividStr:packageContents withSeparater:@"\n\n"];
    NSMutableArray *packages = [NSMutableArray arrayWithCapacity:15];
    for (NSString *string in array) {
        [PackageHandler anaylyzePackage:string completeHandler:^(Package *package, NSError *error) {
            [packages addObject:package];
        }];
    }
    
    //通用属性设置
    if (basePackage) {
        [self setValueWithBasePackage:basePackage withPackages:packages];
    }
    
    handler(packages,nil);
}


+(void)setValueWithBasePackage:(Package *)basePackage withPackages:(NSArray *)array
{
    for (Package *package in array) {
        
        if (!package.baseDir) {
            package.baseDir = basePackage.baseDir;
        }
        
        if (!package.packageName) {
            package.packageName = basePackage.packageName;
        }
        
        if (!package.sourcePath) {
            package.sourcePath = basePackage.sourcePath;
        }
        
        if (!package.certificate) {
            package.certificate = basePackage.certificate;
        }
        
        if (!package.identifier) {
            package.identifier = basePackage.identifier;
        }
        
        if (!package.shortVersion) {
            package.shortVersion = basePackage.shortVersion;
        }
        
        if (!package.bundleVersion) {
            package.bundleVersion = basePackage.bundleVersion;
        }
        
        if (!package.entitlementsPath) {
            package.entitlementsPath = basePackage.entitlementsPath;
        }
        
        if (!package.provisionPath) {
            package.provisionPath = basePackage.provisionPath;
        }
    }
}

@end
