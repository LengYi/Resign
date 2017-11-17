//
//  MobileProvision.m
//  TBRePackaging
//
//  Created by zeejun on 15-4-10.
//  Copyright (c) 2015年 tongbu. All rights reserved.
//

#import "MobileProvision.h"
#import "DocumentManager.h"

@implementation MobileProvisionItem


@end


@implementation MobileProvision

+ (NSString *)getMobileProvisionPathWithTeamName:(NSString *)teamName identifier:(NSString *)identifier isWildcard:(BOOL)isWildcard
{
    NSArray *array = [MobileProvision getMobileProvisionsPathWithTeamName:teamName identifier:identifier];
    
    NSString *mobileProvisionsPath = nil;
    for (MobileProvisionItem *item in array) {
        if(item.isWildcard && [item.applicationIdentifier hasSuffix:identifier]){
            mobileProvisionsPath = item.path;
            break;
        }else{
            if (item.isWildcard == isWildcard) {
                mobileProvisionsPath = item.path;
                break;
            }
        }
    }

    return mobileProvisionsPath;
}

+ (NSArray *)getMobileProvisionsPathWithTeamName:(NSString *)teamName identifier:(NSString *)identifier
{
    NSMutableArray *mobileProvisionPathArray = [NSMutableArray array];
    
    NSArray *array = [MobileProvision mobileProvisons];
    for (NSString *fileName in array) {
        if ([fileName hasSuffix:@"mobileprovision"]) {
            NSString *fullPath = [[MobileProvision provisioningDir]stringByAppendingPathComponent:fileName];
            NSDictionary *dict = [MobileProvision mobileProvisionWithPath:fullPath];
            
            NSArray *applicationIdentifierPrefixs = [dict objectForKey:@"ApplicationIdentifierPrefix"];
            NSDictionary *entitlement = [dict objectForKey:@"Entitlements"];
            NSString *application_identifier = [entitlement objectForKey:@"application-identifier"];
            NSString *applicationIdentifier = application_identifier;
            
            NSArray *certs = [dict objectForKey:@"DeveloperCertificates"];
            if (certs.count == 0) {
                continue;
            }
            NSString *teamName = [self getCommonNameFormCert:certs[0]];
            teamName = [teamName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            //先判断机构名称
            if ([teamName rangeOfString:teamName].length > 0) {
                BOOL sameIdentifier = NO;
                //是否有通配符
                BOOL isWildcard= [application_identifier hasSuffix:@"*"];
                if (isWildcard) {
                    applicationIdentifier = [application_identifier substringToIndex:application_identifier.length - 1];
                }
                
                for (NSString *identifierPrefix in applicationIdentifierPrefixs) {
                    NSString *fullIdentifier = [NSString stringWithFormat:@"%@.%@",identifierPrefix,identifier];
                    if (isWildcard) {
                        //通配符比较前缀
                        sameIdentifier = [fullIdentifier hasPrefix:applicationIdentifier];
                    }else
                    {
                        //完全匹配
                        sameIdentifier = [fullIdentifier isEqualToString:applicationIdentifier];
                    }
                    
                    if (sameIdentifier) {
                        
                        MobileProvisionItem *item = [[MobileProvisionItem alloc]init];
                        item.path = fullPath;
                        item.applicationIdentifier = application_identifier;
                        item.isWildcard = isWildcard;
                        
                        [mobileProvisionPathArray addObject:item];
                    }
                }
            }
        }
    }
    
    return mobileProvisionPathArray;
}

+ (NSString *)provisioningDir
{
    NSString *provisioningDir = [[DocumentManager getLibraryPath]stringByAppendingPathComponent:@"MobileDevice/Provisioning Profiles"];
    return provisioningDir;
}

+ (NSArray *)mobileProvisons
{
    NSArray *array = [[NSFileManager defaultManager]contentsOfDirectoryAtPath:[MobileProvision provisioningDir] error:nil];
    return array;
}


+ (NSDictionary *)mobileProvisionWithPath:(NSString *)path
{
    NSDictionary *propertyList = nil;
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
                propertyList = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
            }
        }
    }
    return propertyList;
}


+ (NSString *)getCommonNameFormCert:(NSData *)cert
{
    SecCertificateRef certificateRef = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)cert);
    CFStringRef commonName = nil;
    SecCertificateCopyCommonName(certificateRef, &commonName);
    return (__bridge NSString *)(commonName);
}

@end
