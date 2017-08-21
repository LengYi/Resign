//
//  PathManager.m
//  TBRePackaging
//
//  Created by ice on 17/3/31.
//  Copyright © 2017年 tongbu. All rights reserved.
//

#import "PathManager.h"

@implementation PathManager

+ (NSString *)workingPath{
    NSString *workingPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"com.tongbu.tbpackaging"];
    return workingPath;
}

+ (NSString *)unzipPath{
    NSString *path = [[self workingPath] stringByAppendingPathComponent:@"UnzipIPA"];
    return path;
}

+ (NSString *)payloadPath{
    NSString *path = [[self unzipPath] stringByAppendingPathComponent:@"Payload"];
    return path;
}

+ (NSString *)appPath{
    NSString *payloadPath = [self payloadPath];
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:payloadPath error:nil];
    NSString *path = @"";
    
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            path = [NSString stringWithFormat:@"%@/%@",payloadPath,file];
            break;
        }
    }
    return path;
}

+ (NSString *)infoPlistPath{
    NSString *payloadPath = [self payloadPath];
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:payloadPath error:nil];
    NSString *infoPlistPath = nil;
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            infoPlistPath = [[payloadPath stringByAppendingPathComponent:file]stringByAppendingPathComponent:@"Info.plist"];
            break;
        }
    }
    
    return infoPlistPath;
}

+ (NSMutableArray *)searchInfoPlistPath:(NSString *)path{
    NSString *payloadPath = [self payloadPath];
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:payloadPath error:nil];
    NSMutableArray *infoPlistArr = [[NSMutableArray alloc] init];
    for (NSString *file in dirContents) {
        NSLog(@"file = %@",file);
        NSString *fullPath = [path stringByAppendingPathComponent:file];
        BOOL isDir = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir] && isDir){
            
        }
    }
    
    return infoPlistArr;
}

+ (NSString *)ItunesMedataInfoPlistPath{
    return @"";
}

+ (NSString *)entitlementsPath{
    NSString *path = [[self appPath] stringByAppendingPathComponent:@"entitlements.plist"];
    return path;
}

+ (NSString *)mobileprovisionPath{
    NSString *path = [[self appPath] stringByAppendingPathComponent:@"embedded.mobileprovision"];
    return path;
}

+ (NSString *)channelPath{
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[[self unzipPath] stringByAppendingPathComponent:@"Payload"] error:nil];
    NSString *path = @"";
    
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            path = [NSString stringWithFormat:@"%@/%@/%@/%@", [self unzipPath], @"Payload", file, @"channel.txt"];
            break;
        }
    }
    return path;
}

+ (NSString *)skuIDPath{
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[[self unzipPath] stringByAppendingPathComponent:@"Payload"] error:nil];
    NSString *path = @"";
    
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            path = [NSString stringWithFormat:@"%@/%@/%@/%@", [self unzipPath], @"Payload", file, @"skuID.txt"];
            break;
        }
    }
    return path;
}

// 遍历需要被签名的文件路径
+ (NSMutableArray *)getCodeSignPathArray{
    NSString *appPath = [self appPath];
    
    NSMutableArray *codeSignFileArr = [[NSMutableArray alloc] init];
    [self searchNeedCodesignFileWithPath:appPath codeSignFileArr:codeSignFileArr];
    
    // 遍历完成之后 .app 也需要被签名
    [codeSignFileArr addObject:appPath];
    NSLog(@"待签名路径----- %@",codeSignFileArr);
    return codeSignFileArr;
}

+ (void)searchNeedCodesignFileWithPath:(NSString *)path codeSignFileArr:(NSMutableArray *)codeSignFileArr{
    NSArray *contentArr = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
    if (contentArr && contentArr.count > 0) {
        for (NSString *file in contentArr){
            NSString *fullPath = [path stringByAppendingPathComponent:file];
            BOOL isDir = NO;
            NSString *pathEx = [[file pathExtension] lowercaseString];
            if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir] && isDir){
                // 目录
                [self searchNeedCodesignFileWithPath:fullPath codeSignFileArr:codeSignFileArr];
  
                if ([pathEx isEqualToString:@"app"]) {
                    [codeSignFileArr addObject:fullPath];
                }else if([pathEx isEqualToString:@"appex"]){
                    [codeSignFileArr addObject:fullPath];
                }else if([pathEx isEqualToString:@"framework"]){
                    [codeSignFileArr addObject:fullPath];
                }else if([pathEx isEqualToString:@"momd"]){
                    [codeSignFileArr addObject:fullPath];
                }
            }else{
                // 非目录
                if ([pathEx isEqualToString:@"dylib"] || [pathEx isEqualToString:@"framework"] || [pathEx isEqualToString:@"acv"] || [pathEx isEqualToString:@"mom"] || [pathEx isEqualToString:@"omo"]) {
                    [codeSignFileArr addObject:fullPath];
                }
            }
        }
    }
}

@end
