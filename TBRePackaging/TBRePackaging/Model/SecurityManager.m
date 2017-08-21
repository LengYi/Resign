//
//  SecurityManager.m
//  TBRePackaging
//
//  Created by zeejun on 15-4-15.
//  Copyright (c) 2015年 tongbu. All rights reserved.
//

#import "SecurityManager.h"

@interface SecurityManager()

@property(nonatomic, strong)  NSTask *certTask;
@property(nonatomic, strong)  NSArray *certs;
@property(nonatomic, strong) SecurityManagerGetCertCompleteHandler handler;

@end

@implementation SecurityManager

+ (instancetype)shareInstance
{
    static SecurityManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[SecurityManager alloc]init];
    });
    
    return manager;
}

- (void)getCertsWithHandler:(SecurityManagerGetCertCompleteHandler)handler
{
    self.handler = handler;
    
    _certTask = [[NSTask alloc] init];
    [_certTask setLaunchPath:@"/usr/bin/security"];
    [_certTask setArguments:[NSArray arrayWithObjects:@"find-identity", @"-v", @"-p", @"codesigning", nil]];
    
    NSPipe *pipe=[NSPipe pipe];
    [_certTask setStandardOutput:pipe];
    [_certTask setStandardError:pipe];
    NSFileHandle *handle=[pipe fileHandleForReading];
    
    [_certTask launch];
    
    __weak typeof(self) weakSelf = self;
    [self addTerminationHandlerForTask:_certTask usingBlock:^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [weakSelf watchGetCerts:handle];
        });
    }];
}

- (void)watchGetCerts:(NSFileHandle*)streamHandle {
    
    @autoreleasepool {
        NSString *securityResult = [[NSString alloc] initWithData:[streamHandle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
        NSArray *rawResult = [securityResult componentsSeparatedByString:@"\""];
        if(rawResult.count > 2){
            NSMutableArray *tempGetCertsResult = [NSMutableArray arrayWithCapacity:20];
            for (int i = 0; i <= [rawResult count] - 2; i+=2) {
                if (i+1 >= [rawResult count]) {
                }
                [tempGetCertsResult addObject:[rawResult objectAtIndex:i+1]];
            }
            self.certs = tempGetCertsResult;
        }
    }
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (weakSelf.handler) {
            weakSelf.handler(nil);
        }
    });
}


- (void)addTerminationHandlerForTask:(NSTask *)task usingBlock:(void (^)())block {
    
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
@end
