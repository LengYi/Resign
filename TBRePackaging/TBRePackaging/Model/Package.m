//
//  Package.m
//  TBRePackaging
//
//  Created by zeejun on 15-4-8.
//  Copyright (c) 2015年 tongbu. All rights reserved.
//

#import "Package.h"

NSString *const PackageBaseDir             = @"BaseDir";
NSString *const PackageName                = @"Name";
NSString *const PackageSourcePath          = @"SourcePath";
NSString *const PackageCertificate         = @"Certificate";
NSString *const PackageIdentifier          = @"Identifier";
NSString *const PackageShortVersion        = @"ShortVersion";
NSString *const PackageBundleVersion       = @"BundleVersion";
NSString *const PackageEntitlementsPath    = @"EntitlementsPath";
NSString *const PackageProvisionPath       = @"ProvisionPath";
NSString *const PackageChannels            = @"Channels";
NSString *const PackagePlistIdentifier     = @"InfoPlistIdentifier";
NSString *const PackageDeviceType          = @"DeviceType";

@interface Package()

@end

@implementation Package

- (instancetype)init
{
    self = [super init];
    if (self) {
        _channelArray = [[NSMutableArray alloc]init];
    }
    return self;
}


- (void)addChannelArray:(NSArray *)objects{
    [_channelArray addObjectsFromArray:objects];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"BaseDir:%@\nName:%@\nSourcePath:%@\nCertificate:%@\nIdentifier:%@\nShortVersion:%@\nBundleVersion:%@\nEntitlementsPath:%@\nProvisionPath:%@\nChannels:%@", _baseDir,_packageName,_sourcePath,_certificate,_identifier,_shortVersion,_bundleVersion,_entitlementsPath,_provisionPath,_channelArray];
}

@end
