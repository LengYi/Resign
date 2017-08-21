//
//  NSDictionary+ABAdditions.h
//  tbtui
//
//  Created by zeejun on 14-8-26.
//  Copyright (c) 2014年 厦门同步网络. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDictionary (ABAdditions)

+ (NSDictionary *)ab_dictionaryFromData:(NSData *)data;

+ (NSData *)ab_dataFromDictionary:(NSDictionary *)dict;

@end
