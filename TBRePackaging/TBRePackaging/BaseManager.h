//
//  BaseManager.h
//  TBRePackaging
//
//  Created by ice on 17/3/31.
//  Copyright © 2017年 tongbu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BaseManager : NSObject

+ (void)addTerminationHandlerForTask:(NSTask *)task usingBlock:(void (^)())block;

@end
