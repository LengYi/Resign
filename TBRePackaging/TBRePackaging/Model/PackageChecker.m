//
//  PackageChecker.m
//  TBRePackaging
//
//  Created by zeejun on 15-4-10.
//  Copyright (c) 2015年 tongbu. All rights reserved.
//

#import "PackageChecker.h"


@implementation PackageChecker


+(BOOL)checkCertificateName:(NSString *)name
{
    return [name hasPrefix: @"iPhone Distribution:"] || [name hasPrefix: @"iPhone Developer:"];
}

+ (void)checkPackages:(NSArray *)packages certs:(NSArray *)certs completeHandler:(void(^)(NSError *error))handler
{
    NSError *error = nil;
    for (Package *package in packages) {
        [PackageChecker checkPackage:package certs:certs error:&error];
        
        if (error) {
            NSString *errorString = [[error localizedDescription]stringByAppendingFormat:@"\n%@",package];
            error = [NSError errorWithDomain:@"" code:0 userInfo:@{NSLocalizedDescriptionKey:errorString}];
            break;
        }
    }
    
    if (handler) {
        handler(error);
    }
}


+ (BOOL)checkPackage:(Package *)package certs:(NSArray *)certs error:(NSError *__autoreleasing *)error
{
    BOOL isOK = NO;
    
    //1.检查必要属性
    if(!package.certificate || ![self checkCertificateName:package.certificate])
    {
        *error = [[NSError alloc]initWithDomain:@"" code:0 userInfo:@{NSLocalizedDescriptionKey:@"证书名称不能为空或格式有问题"}];
        
    }else if (!package.identifier)
    {
        *error = [[NSError alloc]initWithDomain:@"" code:0 userInfo:@{NSLocalizedDescriptionKey:@"identifier不能为空"}];

    }else if (!package.packageName)
    {
        *error = [[NSError alloc]initWithDomain:@"" code:0 userInfo:@{NSLocalizedDescriptionKey:@"packageName不能为空"}];

    }else if (!package.sourcePath)
    {
        *error = [[NSError alloc]initWithDomain:@"" code:0 userInfo:@{NSLocalizedDescriptionKey:@"sourcePath不能为空"}];
        
    }else if(![[NSFileManager defaultManager]fileExistsAtPath:package.sourcePath])
    {
        *error = [[NSError alloc]initWithDomain:@"" code:0 userInfo:@{NSLocalizedDescriptionKey:@"原始包不存在"}];
        
    }else if(![package.sourcePath hasSuffix:@"ipa"])
    {
        *error = [[NSError alloc]initWithDomain:@"" code:0 userInfo:@{NSLocalizedDescriptionKey:@"原始包必须是ipa格式"}];
    }else if(!package.provisionPath || ![package.provisionPath hasSuffix:@"mobileprovision"] || ![[NSFileManager defaultManager]fileExistsAtPath:package.provisionPath])
    {
        *error = [[NSError alloc]initWithDomain:@"" code:0 userInfo:@{NSLocalizedDescriptionKey:@"mobileprovisiom找不到"}];
    }
    else
    {
        isOK = YES;
    }
    
    //2.检查证书是否存在
    BOOL exist = NO;
    for (NSString *cert in certs) {
        if ([cert isEqualToString:package.certificate]) {
            exist = YES;
            break;
        }
    }
    
    if (!exist) {
        *error = [[NSError alloc]initWithDomain:@"" code:0 userInfo:@{NSLocalizedDescriptionKey:@"cert证书找不到"}];
        isOK = NO;
    }
    
    return isOK;
}


@end
