//
//  DocumentManager.m
//  TBRePackaging
//
//  Created by zeejun on 15-4-10.
//  Copyright (c) 2015年 tongbu. All rights reserved.
//

#import "DocumentManager.h"

@implementation DocumentManager

+ (NSString *)getLibraryPath
{
    NSString *path = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    if ([paths count] > 0) {
        path = [paths objectAtIndex:0];
    }
    return path;
}

@end
