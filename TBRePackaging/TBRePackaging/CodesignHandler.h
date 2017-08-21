//
//  CodesignHandler.h
//  TBRePackaging
//
//  Created by zeejun on 15-4-8.
//  Copyright (c) 2015年 tongbu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Package.h"

typedef void(^ResignPackagesCompleteHandler)(NSString *msg,NSError *error);
typedef void(^ResignPackagesProgressHandler)(NSString *msg);


@interface CodesignHandler : NSObject

- (void)resignWithPackages:(Package *)package completeHandler:(ResignPackagesCompleteHandler)handler progressHandler:(ResignPackagesProgressHandler)progressHandler;

@end
