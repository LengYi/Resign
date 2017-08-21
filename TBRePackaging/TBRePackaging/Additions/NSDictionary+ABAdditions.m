//
//  NSDictionary+ABAdditions.m
//  tbtui
//
//  Created by zeejun on 14-8-26.
//  Copyright (c) 2014年 厦门同步网络. All rights reserved.
//

#import "NSDictionary+ABAdditions.h"

@implementation NSDictionary (ABAdditions)

+ (NSDictionary *)ab_dictionaryFromData:(NSData *)data
{
    NSError *error = NULL;
    NSPropertyListFormat plistFormat;
    id plist = [NSPropertyListSerialization propertyListWithData:data
                                                         options:NSPropertyListImmutable
                                                          format:&plistFormat
                                                           error:&error];
    
    NSDictionary *dict = NULL;
    if ([plist isKindOfClass:[NSDictionary class]]) {
        dict = [[NSDictionary alloc] initWithDictionary:(NSDictionary *)plist];
    } else {
        //        NSLog(@"dictionaryFromData failed");
    }
    
    return dict;
}

+ (NSData *)ab_dataFromDictionary:(NSDictionary *)dict
{
    NSError *error = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:dict format:NSPropertyListXMLFormat_v1_0 options:NSPropertyListImmutable error:&error];
    return data;
}

@end
