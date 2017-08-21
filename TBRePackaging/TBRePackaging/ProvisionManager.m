//
//  ProvisionManager.m
//  TBRePackaging
//
//  Created by ice on 17/3/31.
//  Copyright © 2017年 tongbu. All rights reserved.
//

#import "ProvisionManager.h"
#import "PathManager.h"
#import "AppPackageInfoManager.h"

@implementation ProvisionManager

+ (void)copyProvisionToApp:(NSString *)originPath desPath:(NSString *)desPath handle:(void (^)())handle{
    if ([[NSFileManager defaultManager] fileExistsAtPath:desPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:desPath error:nil];
    }
    
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/cp"];
    [task setArguments:[NSArray arrayWithObjects:originPath, desPath, nil]];
    
    [self addTerminationHandlerForTask:task usingBlock:^{
        [self checkProvisioningWithPath:desPath];
        if (handle) {
            handle();
        }
    }];
    
    [task launch];
}


+ (void)checkProvisioningWithPath:(NSString *)provisionPath{
    BOOL identifierOK = NO;
    BOOL certOK = NO;
    
    NSDictionary *mobileProvision = [self getMobileProvisionWithPath:provisionPath];
    if(mobileProvision){
        id value = [mobileProvision objectForKey:@"Entitlements"];
        if (value && [value isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dictionary = (NSDictionary *)value;
            NSString *appIdentifier = dictionary[@"application-identifier"];
            NSString *appIdentiferPrefix = @"";
            NSArray *appIdentiferPrefixArr = mobileProvision[@"ApplicationIdentifierPrefix"];
            if (appIdentiferPrefixArr.count > 0) {
                appIdentiferPrefix = [appIdentiferPrefixArr firstObject];
            }
            
            if ([appIdentifier length] > [appIdentiferPrefix length]) {
                NSString *identifierPro = [appIdentifier substringFromIndex:appIdentiferPrefix.length + 1];
                if ([identifierPro isEqualToString:@"*"]) {
                    identifierOK = YES;
                }else{
                    
                }
            }
        }
    }
    
    
    if (1) {
        NSString *path = [provisionPath stringByDeletingLastPathComponent];
        path = [path stringByAppendingPathComponent:@"/entitlements.plist"];
        [self doEntitlements:mobileProvision path:path];
    }
}

+ (void)doEntitlements:(NSDictionary *)mobileProvision path:(NSString *)path{
    id value = [mobileProvision objectForKey:@"Entitlements"];
    if ([value isKindOfClass:[NSDictionary class]]){
         NSDictionary *dictionary = (NSDictionary *)value;
        
        NSString *applicationIdentifierPrefix = nil;
        NSArray *applicationIdentifierPrefixs = [mobileProvision objectForKey:@"ApplicationIdentifierPrefix"];
        if ([applicationIdentifierPrefixs count] > 0) {
            applicationIdentifierPrefix = [applicationIdentifierPrefixs firstObject];
        }
        
        NSString *ident = dictionary[@"application-identifier"];
        NSString *appIdentifier = nil;
        if ([ident length] > [applicationIdentifierPrefix length]) {
            appIdentifier = [ident substringFromIndex:applicationIdentifierPrefix.length + 1];
        }

        if (!appIdentifier) {
            NSLog(@"证书sku为空 application-identifier = %@,applicationIdentifierPrefix = %@",appIdentifier,applicationIdentifierPrefix);
            return;
        }
        NSString *applicationIdentifierForEntitlements = [NSString stringWithFormat:@"%@.%@",applicationIdentifierPrefix,appIdentifier];
        NSString *applicationIdentifierForEntitlementsPrefix = [NSString stringWithFormat:@"%@.",applicationIdentifierPrefix];
        
        NSMutableDictionary *entitlementDict = [NSMutableDictionary dictionary];
        for (NSString *key in dictionary.allKeys) {
            
            id object = [dictionary objectForKey:key];
            if ([object isKindOfClass:[NSString class]]) {
                if ([object hasPrefix:applicationIdentifierForEntitlementsPrefix]) {
                    [entitlementDict setObject:applicationIdentifierForEntitlements forKey:key];
                }else
                {
                    [entitlementDict setObject:object forKey:key];
                }
            }else if ([object isKindOfClass:[NSArray class]])
            {
                //
                NSMutableArray *tempArray = [NSMutableArray array];
                for (id obj in (NSArray *)object) {
                    if ([obj isKindOfClass:[NSString class]]) {
                        if ([obj hasPrefix:applicationIdentifierForEntitlementsPrefix]) {
                            [tempArray addObject:applicationIdentifierForEntitlements];
                        }else
                        {
                            [tempArray addObject:obj];
                        }
                    }else
                    {
                        [tempArray addObject:obj];
                    }
                }
                [entitlementDict setObject:tempArray forKey:key];
            }else
            {
                [entitlementDict setObject:object forKey:key];
            }
        }
        
        // 合并entitlemen
        [entitlementDict writeToFile:path atomically:YES];
        
        // 记录teamID
        [AppPackageInfoManager addSkuIDWithPath:[PathManager skuIDPath] skuID:applicationIdentifierPrefix];
    }else{
        NSLog(@"Entitlements 生成失败");
    }
    
}

+ (NSDictionary *)getMobileProvisionWithPath:(NSString *)path{
    NSDictionary *provisionDict = nil;
    if (path) {
        
        NSData *fileData = [NSData dataWithContentsOfFile:path];
        if (fileData) {
            CMSDecoderRef decoder = NULL;
            CMSDecoderCreate(&decoder);
            CMSDecoderUpdateMessage(decoder, fileData.bytes, fileData.length);
            CMSDecoderFinalizeMessage(decoder);
            CFDataRef dataRef = NULL;
            CMSDecoderCopyContent(decoder, &dataRef);
            NSData *data = (NSData *)CFBridgingRelease(dataRef);
            CFRelease(decoder);
            if (data) {
                provisionDict = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
            }
        }
    }
    return provisionDict;
}

@end
