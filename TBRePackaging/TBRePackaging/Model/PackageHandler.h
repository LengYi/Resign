//
//  PackageHandler.h
//  TBRePackaging
//
//  Created by zeejun on 15-4-8.
//  Copyright (c) 2015年 tongbu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PackageHandler : NSObject

+ (BOOL)checkPackage:(NSString *)content;

+ (void)anaylyzeWithBase:(NSString *)baseContent
         packageContents:(NSString *)packageContents
         completeHandler:(void(^)(NSArray *array,NSError *error))handler;

@end
