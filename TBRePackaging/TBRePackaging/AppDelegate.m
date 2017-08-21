//
//  AppDelegate.m
//  TBRePackaging
//
//  Created by zeejun on 15-4-8.
//  Copyright (c) 2015年 tongbu. All rights reserved.
//

#import "AppDelegate.h"
#import "PackageHandler.h"
#import "Package.h"
#import "Const.h"
#import "MobileProvision.h"
#import "PackageChecker.h"
#import "SecurityManager.h"
#import "CodesignManager.h"
#import "CodesignHandler.h"

NSString *const NSUserDefault_BaseTextKey       = @"BaseTextKey";
NSString *const NSUserDefault_PackageTextKey    = @"PackageTextKey";


@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property(nonatomic, strong) NSMutableArray *packagesArray;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification{
    self.baseTextView.string = @"BaseDir:\nSourcePath:\nShortVersion:\nBundleVersion:\nEntitlementsPath:";
    self.textView.string = @"Name:\nCertificate:\nIdentifier:\nInfoPlistIdentifier:\nChannels:";
    self.statusLabel.stringValue = @"";
    
    NSString *baseTextKey = [[NSUserDefaults standardUserDefaults]objectForKey:NSUserDefault_BaseTextKey];
    if (baseTextKey) {
        self.baseTextView.string = baseTextKey;
    }
    
    NSString *packageTextKey = [[NSUserDefaults standardUserDefaults]objectForKey:NSUserDefault_PackageTextKey];
    if (packageTextKey) {
        self.textView.string = packageTextKey;
    }
        
    //获取证书
    [self reloadCertButtonOnclicked:nil];
    
}

- (IBAction)startButtonOnclicked:(id)sender{
    if (!self.textView.string || [self.textView.string isEqualToString:@""]) {
        [self showErrorWithTitle:_(@"Error") message:@"text is null"];
        return;
    }
    
    [self disableControl];
    self.statusLabel.stringValue = @"检查中...";
    // 文件路径基本信息
    NSString *content = self.textView.string;
    // 签名信息
    NSString *baseContent = self.baseTextView.string;
    
    // 暂存信息,下次运行至今显示上次录入的信息
    [[NSUserDefaults standardUserDefaults]setObject:baseContent forKey:NSUserDefault_BaseTextKey];
    [[NSUserDefaults standardUserDefaults]setObject:content forKey:NSUserDefault_PackageTextKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    __weak typeof(self) weakSelf = self;
    [PackageHandler anaylyzeWithBase:baseContent packageContents:content completeHandler:^(NSArray *array, NSError *error) {
        if ([array count] > 0) {
            for (Package *package in array) {
                if(!package.provisionPath)
                {
                    // 获取mobileprovision 在电脑上的具体路径  /Users/ice/Library/MobileDevice/Provisioning Profiles/788fbd0a-1cd7-46db-b943-dce748fc0475.mobileprovision
                    package.provisionPath = [MobileProvision getMobileProvisionPathWithTeamName:package.certificate identifier:package.identifier isWildcard:NO];
                }
            }
            
            //check
            [PackageChecker checkPackages:array certs:[SecurityManager shareInstance].certs completeHandler:^(NSError *error) {
                if (!error) {
                    if(!_packagesArray){
                        _packagesArray = [[NSMutableArray alloc] init];
                    }
                    
                    [_packagesArray removeAllObjects];
                    [_packagesArray addObjectsFromArray:array];
                    [weakSelf packageNext];
                }else
                {
                    [weakSelf showErrorWithTitle:@"Error" message:[error localizedDescription]];
                    [weakSelf enableControl];
                    weakSelf.statusLabel.stringValue = @"完成";
                }
            }];
        }
    }];
}

- (void)package:(Package *)package{    
      __weak typeof(self) weakSelf = self;
    [[CodesignManager shareInstance] resignWithPackages:package
                        completeHandler:^(NSString *msg) {
                             weakSelf.statusLabel.stringValue = msg;
                    
                            if ([msg isEqualToString:@"打包完成"]) {
                                if (_packagesArray.count > 0) {
                                    [_packagesArray removeObjectAtIndex:0];
                                }
                                [weakSelf packageNext];
                            }
                        }];
}

- (void)packageNext{
    if (_packagesArray.count > 0) {
        Package *package = [_packagesArray firstObject];
        [self package:package];
    }else{
        [self enableControl];
    }
}

// 重新获取证书
- (IBAction)reloadCertButtonOnclicked:(id)sender{
    self.startButton.enabled = NO;
    self.reloadCertButon.enabled = NO;
    
    __weak typeof(self) weakSelf = self;
    self.statusLabel.stringValue = @"获取证书...";
    [[SecurityManager shareInstance]getCertsWithHandler:^(NSError *error) {
        weakSelf.startButton.enabled = YES;
        weakSelf.reloadCertButon.enabled = YES;
        weakSelf.statusLabel.stringValue = @"获取证书完成";
    }];
}

// 签名工具 key 使用说明
- (IBAction)helperButtonOnClicked:(id)sender{
    NSString *path = [[NSBundle mainBundle]pathForResource:@"helper" ofType:@"txt"];
    NSString *string = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    
    [self showErrorWithTitle:@"ok" message:string];
}

- (void)showErrorWithTitle:(NSString *)title message:(NSString *)message{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:title];
    [alert setMessageText:message];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        
    }];
}

- (void)enableControl{
    self.textView.editable = YES;
    self.baseTextView.editable = YES;
    self.startButton.enabled = YES;
    self.reloadCertButon.enabled = YES;
}

- (void)disableControl{
    self.textView.editable = NO;
    self.baseTextView.editable = NO;
    self.startButton.enabled = NO;
    self.reloadCertButon.enabled = NO;
}

@end
