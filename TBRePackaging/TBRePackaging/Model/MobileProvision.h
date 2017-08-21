//
//  MobileProvision.h
//  TBRePackaging
//
//  Created by zeejun on 15-4-10.
//  Copyright (c) 2015年 tongbu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MobileProvisionItem : NSObject

@property(nonatomic, strong) NSString *path;
@property(nonatomic, strong) NSString *applicationIdentifier;
@property(nonatomic, assign) BOOL isWildcard;

@end


@interface MobileProvision : NSObject

+ (NSString *)getMobileProvisionPathWithTeamName:(NSString *)teamName identifier:(NSString *)identifier isWildcard:(BOOL)isWildcard;

+ (NSArray *)getMobileProvisionsPathWithTeamName:(NSString *)teamName identifier:(NSString *)identifier;

+ (NSDictionary *)mobileProvisionWithPath:(NSString *)path;

+ (NSString *)getCommonNameFormCert:(NSData *)cert;

@end
