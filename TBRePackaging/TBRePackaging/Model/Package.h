//
//  Package.h
//  TBRePackaging
//
//  Created by zeejun on 15-4-8.
//  Copyright (c) 2015年 tongbu. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const PackageBaseDir;
extern NSString *const PackageName;
extern NSString *const PackageSourcePath;
extern NSString *const PackageCertificate;
extern NSString *const PackageIdentifier;
extern NSString *const PackageShortVersion;
extern NSString *const PackageBundleVersion;
extern NSString *const PackageEntitlementsPath;
extern NSString *const PackageProvisionPath;
extern NSString *const PackageChannels;
extern NSString *const PackagePlistIdentifier;
extern NSString *const PackageDeviceType;
extern NSString *const PackageShouldAttach;

@class Channel;

@interface Package : NSObject

@property(nonatomic, strong) NSString *baseDir;
@property(nonatomic, strong) NSString *packageName;
@property(nonatomic, strong) NSString *sourcePath;
@property(nonatomic, strong) NSString *certificate;
@property(nonatomic, strong) NSString *identifier;             // 用于匹配证书的identifier
@property(nonatomic, strong) NSString *infoplistIdentifier;    // 写入infoplist中的 identifier
@property(nonatomic, strong) NSString *shortVersion;
@property(nonatomic, strong) NSString *bundleVersion;
@property(nonatomic, strong) NSString *entitlementsPath;
@property(nonatomic, strong) NSString *provisionPath;
@property(nonatomic, strong) NSMutableArray *channelArray;
@property(nonatomic, strong) NSString *outPutPath;              // 重签名完成后包存放路径
@property(nonatomic, strong) NSString *deviceType;
@property(nonatomic, assign) BOOL     shouldAttach;             // 是否允许xcode附加当前程序(改变get-task-allow的值)

- (void)addChannelArray:(NSArray *)objects;

@end
