//
//  BaseManager.m
//  TBRePackaging
//
//  Created by ice on 17/3/31.
//  Copyright © 2017年 tongbu. All rights reserved.
//

#import "BaseManager.h"

@implementation BaseManager

+ (void)addTerminationHandlerForTask:(NSTask *)task usingBlock:(void (^)())block {
    
    __block id taskComplete;
    taskComplete = [[NSNotificationCenter defaultCenter]
                    addObserverForName:NSTaskDidTerminateNotification
                    object:nil
                    queue:nil
                    usingBlock:^(NSNotification *note)
                    {
                        [[NSNotificationCenter defaultCenter] removeObserver:taskComplete];
                        if ([task isEqual:note.object]) {
                            block();
                        }
                        
                    }];
}

+ (NSError *)errWithMsg:(NSString *)msg{
    NSError *error = nil;
    if (msg) {
        error = [NSError errorWithDomain:@""
                                    code:0
                                userInfo:@{NSLocalizedDescriptionKey:msg}];
    }
    
    return error;
}
@end
