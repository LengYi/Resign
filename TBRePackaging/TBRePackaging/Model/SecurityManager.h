//
//  SecurityManager.h
//  TBRePackaging
//
//  Created by zeejun on 15-4-15.
//  Copyright (c) 2015年 tongbu. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^SecurityManagerGetCertCompleteHandler)(NSError *error);

@interface SecurityManager : NSObject

@property(nonatomic, readonly)  NSArray *certs;

+ (instancetype)shareInstance;

- (void)getCertsWithHandler:(SecurityManagerGetCertCompleteHandler)handler;

@end
