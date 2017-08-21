//
//  ProvisionManager.h
//  TBRePackaging
//
//  Created by ice on 17/3/31.
//  Copyright © 2017年 tongbu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseManager.h"

@interface ProvisionManager : BaseManager
+ (void)copyProvisionToApp:(NSString *)originPath desPath:(NSString *)desPath handle:(void (^)())handle;

@end
