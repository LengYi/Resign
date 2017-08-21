//
//  PackageChecker.h
//  TBRePackaging
//
//  Created by zeejun on 15-4-10.
//  Copyright (c) 2015年 tongbu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Package.h"

@interface PackageChecker : NSObject

+ (BOOL)checkPackage:(Package *)package certs:(NSArray *)certs  error:(NSError **)error;

+ (void)checkPackages:(NSArray *)packages certs:(NSArray *)certs completeHandler:(void(^)(NSError *error))handler;

@end
