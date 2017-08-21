//
//  CodesignManager.h
//  TBRePackaging
//
//  Created by ice on 17/3/30.
//  Copyright © 2017年 tongbu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Package.h"

typedef void(^CodesignManagerHandler)(NSString *msg);

@interface CodesignManager : NSObject

+ (id)shareInstance;
- (void)resignWithPackages:(Package *)package completeHandler:(CodesignManagerHandler)handler;

@end
