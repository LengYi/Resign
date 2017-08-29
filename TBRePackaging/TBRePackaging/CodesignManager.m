//
//  CodesignManager.m
//  TBRePackaging
//
//  Created by ice on 17/3/30.
//  Copyright © 2017年 tongbu. All rights reserved.
//

#import "CodesignManager.h"
#include <CoreServices/CoreServices.h>
#include "AppPackageInfoManager.h"
#import "PathManager.h"
#import "ProvisionManager.h"
#import "Channel.h"
#import "Const.h"

@interface CodesignManager ()

@property (nonatomic,strong) Package *package;
@property (nonatomic,strong) CodesignManagerHandler handle;
@end

@implementation CodesignManager
+ (id)shareInstance{
    static CodesignManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!manager) {
            manager = [[CodesignManager alloc] init];
        }
    });
    return manager;
}

- (void)resignWithPackages:(Package *)package completeHandler:(CodesignManagerHandler)handler{
    // 保存打包信息
    self.package = package;
    self.handle = handler;
    
    if ([[[package.sourcePath pathExtension] lowercaseString] isEqualToString:@"ipa"]) {
        [[NSFileManager defaultManager] removeItemAtPath:[PathManager workingPath] error:nil];
        [[NSFileManager defaultManager] createDirectoryAtPath:[PathManager workingPath] withIntermediateDirectories:TRUE attributes:nil error:nil];
        
        // 删除旧签名包
        NSString *outPutPath = [package.baseDir stringByAppendingPathComponent:package.packageName];
        [[NSFileManager defaultManager] removeItemAtPath:outPutPath error:nil];
        
        [self unzipIPA];
    }else{
        handler(_(@"You must choose an *.ipa file"));
    }
}

- (void)unzipIPA{
    NSString *originPath = self.package.sourcePath;
    NSString *unzipPath = [PathManager unzipPath];
    // 删除旧的解压文件,重新解压
    [[NSFileManager defaultManager] removeItemAtPath:unzipPath error:nil];
    
    NSTask *unzipTask = [[NSTask alloc] init];
    [unzipTask setLaunchPath:@"/usr/bin/unzip"];
    [unzipTask setArguments:[NSArray arrayWithObjects:@"-q", originPath, @"-d",unzipPath, nil]];
    
    [unzipTask launch];
    
    self.handle(_(@"UnZip original app"));
    __weak typeof(self) weakSelf = self;
    [self addTerminationHandlerForTask:unzipTask usingBlock:^{
        weakSelf.handle(_(@"UnZip original app Finish"));
        // 修改包信息
        [weakSelf changeAppInfo];
        // 拷贝mobileprovision证书到app包
        // 拷贝完成开始重签名
        [ProvisionManager copyProvisionToApp:weakSelf.package desPath:[PathManager mobileprovisionPath] handle:^{
            weakSelf.handle(@"拷贝证书完成,开始签名");
            [weakSelf doCodeSigning];
        }];
    }];
}

- (BOOL)changeAppInfo{
   // [PathManager searchInfoPlistPath];
    //return YES;
    // 修改info.list信息
    NSString *bundleVer = self.package.bundleVersion;
    NSString *shortVer = self.package.shortVersion;
    NSString *sku = self.package.infoplistIdentifier;
    NSString *deviceType = self.package.deviceType;
    
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    if (bundleVer) {
        [dict setObject:bundleVer forKey:@"CFBundleVersion"];
    }
    
    if (shortVer) {
        [dict setObject:shortVer forKey:@"CFBundleShortVersionString"];
    }
    
    if (sku) {
        [dict setObject:sku forKey:@"CFBundleIdentifier"];
    }
    
    if (deviceType) {
        NSArray *arr = nil;
        if ([deviceType isEqualToString:@"0"]) {
            arr = @[@"1",@"2"];
        }else if([deviceType isEqualToString:@"1"]){
            arr = @[@"1"];
        }else if([deviceType isEqualToString:@"2"]){
            arr = @[@"2"];
        }
        [dict setObject:arr forKey:@"UIDeviceFamily"];
    }
    
    [AppPackageInfoManager changeInfoPlistWithDict:dict
                                              path:[PathManager infoPlistPath]];
    // 添加渠道号
    NSString *channelStr = @"";
    if (self.package.channelArray.count > 0) {
        Channel *chan =  self.package.channelArray[0];
        channelStr = chan.text;
        NSString *msg = [NSString stringWithFormat:@"修改渠道为->%@:%@",chan.name,chan.text];
        self.handle(msg);
         return [AppPackageInfoManager addChannelFileInfo:[PathManager channelPath] channelStr:channelStr];
    }
   
    return NO;
}

// 开始签名
- (BOOL)doCodeSigning{
    NSMutableArray *codeSignArr = [PathManager getCodeSignPathArray];
    NSString *path = codeSignArr[0];
    NSString *zipPath = [self.package.baseDir stringByAppendingPathComponent:self.package.packageName];
    
    NSString *fileName = @"";
    if (self.package.channelArray.count > 0) {
        Channel *chan =  self.package.channelArray[0];
        fileName = chan.name;
    }
    
    [self beginCodeSign:self.package.certificate
                   path:path
        codeSignFileArr:codeSignArr
     zipPath:zipPath
     fileName:fileName];
    return NO;
}

- (void)beginCodeSign:(NSString *)certificate
                 path:(NSString *)path
      codeSignFileArr:(NSMutableArray *)codeSignFileArr
              zipPath:(NSString *)zipPath
             fileName:name{
    NSString *msg = [NSString stringWithFormat:@"开始签名 %@ 渠道包",name];
    self.handle(msg);
    __weak typeof(self) weakSelf = self;
    [self doCodeSigning:certificate path:path handle:^{
        // codeSignFileArr.count <= 1 则签名完成,否则继续签名
        if (codeSignFileArr.count > 1) {
            [codeSignFileArr removeObject:path];
            [weakSelf beginCodeSign:certificate
                               path:codeSignFileArr[0]
                    codeSignFileArr:codeSignFileArr
                            zipPath:zipPath
                           fileName:name
             ];
        }else{ // 签名完成压缩文件生成IPA包
            [weakSelf zipIPAWithPath:zipPath name:name];
        }
    }];
}

- (void)doCodeSigning:(NSString *)certificate path:(NSString *)path handle:(void (^)())handle{
    if (path) {
        NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"-fs",certificate, nil];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:[PathManager entitlementsPath]]) {
            [arguments addObject:[NSString stringWithFormat:@"--entitlements=%@", [PathManager entitlementsPath]]];
        }
        
        [arguments addObjectsFromArray:[NSArray arrayWithObjects:path, nil]];
        
        NSTask *codesignTask = [[NSTask alloc] init];
        [codesignTask setLaunchPath:@"/usr/bin/codesign"];
        [codesignTask setArguments:arguments];
        
        NSPipe *pipe = [NSPipe pipe];
        [codesignTask setStandardOutput:pipe];
        [codesignTask setStandardError:pipe];
        NSFileHandle *fileHandle = [pipe fileHandleForReading];
        
        [self addTerminationHandlerForTask:codesignTask usingBlock:^{
            if (handle) {
                handle();
            }
        }];
        
        [codesignTask launch];
        [NSThread detachNewThreadSelector:@selector(watchCodesigning:)
                                 toTarget:self withObject:fileHandle];
    }
}

//- (void)doVerifySignature{
//    NSTask *verifyTask = [[NSTask alloc] init];
//    [verifyTask setLaunchPath:@"/usr/bin/codesign"];
//    [verifyTask setArguments:[NSArray arrayWithObjects:@"-v", [PathManager appPath], nil]];
//    
//    NSPipe *pipe=[NSPipe pipe];
//    [verifyTask setStandardOutput:pipe];
//    [verifyTask setStandardError:pipe];
//    NSFileHandle *handle = [pipe fileHandleForReading];
//    
//    __weak typeof(self) weakSelf = self;
//    [self addTerminationHandlerForTask:verifyTask usingBlock:^{
//        //[weakSelf checkVerificationProcess];
//    }];
//    
//    [verifyTask launch];
//    
//    [NSThread detachNewThreadSelector:@selector(watchVerificationProcess:)
//                             toTarget:self withObject:handle];
//}

- (void)zipIPAWithPath:(NSString *)path name:(NSString *)name{
    NSString *msg = [NSString stringWithFormat:@"保存 %@ 渠道包",name];
    self.handle(msg);
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:path
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
    }
    
    if([name isEqualToString:@""]){
        name = @"Resign";
    }
    
    NSString *desPath = [path stringByAppendingPathComponent:name];
    desPath = [desPath stringByAppendingPathExtension:@"ipa"];
    [[NSFileManager defaultManager] removeItemAtPath:desPath error:nil];
    
    NSTask *zipTask = [[NSTask alloc] init];
    [zipTask setLaunchPath:@"/usr/bin/zip"];
    [zipTask setCurrentDirectoryPath:[PathManager unzipPath]];
    [zipTask setArguments:[NSArray arrayWithObjects:@"-qry", desPath, @".", nil]];
    
    __weak typeof(self) weakSelf = self;
    [self addTerminationHandlerForTask:zipTask usingBlock:^{
        [weakSelf zipFinish];
    }];
    
    [zipTask launch];
}

- (void)zipFinish{
    // 打完一个渠道号包,删除已打完的渠道号,继续打包其它渠道号,直到全部完成 修改渠道号->签名->打包
    if (self.package.channelArray.count > 0) {
        [self.package.channelArray removeObjectAtIndex:0];
    }
    
    if (self.package.channelArray.count > 0) {
        // 修改渠道号
        Channel *chan = self.package.channelArray[0];
        [AppPackageInfoManager addChannelFileInfo:[PathManager channelPath] channelStr:chan.text];
        [self doCodeSigning];
    }else{
        self.handle(@"打包完成");
    }
}

- (void)watchCodesigning:(NSFileHandle*)streamHandle{
    @autoreleasepool {
        NSString *codesigningResult = [[NSString alloc] initWithData:[streamHandle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
        //NSLog(@"codesignResult = %@",codesigningResult);
    }
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
