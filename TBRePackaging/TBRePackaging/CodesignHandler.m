//
//  CodesignHandler.m
//  TBRePackaging
//
//  Created by zeejun on 15-4-8.
//  Copyright (c) 2015年 tongbu. All rights reserved.
//

#import "CodesignHandler.h"
#import "NSDictionary+ABAdditions.h"
#include <CoreServices/CoreServices.h>
#import "Package.h"
#import "Channel.h"
#import "Const.h"
#import "MobileProvision.h"

/*info.plist*/
static NSString *kCFBundleShortVersionString            =      @"CFBundleShortVersionString";
static NSString *kBundleVersionPlistAppKey              =      @"CFBundleVersion";
static NSString *kCFBundleIdentifier                    =      @"CFBundleIdentifier";

/*itunesMetadata.plist*/
static NSString *kbundleVersion                         =      @"bundleVersion";
static NSString *ksoftwareVersionBundleId               =      @"softwareVersionBundleId";

static NSString *kUnzippedIPAPath                       =      @"UnzippedIPAPath";
static NSString *kPayloadDirName                        =      @"Payload";
static NSString *kInfoPlistFilename                     =      @"Info.plist";

static NSString *kChannelFileName                       =      @"channel.txt";
static NSString *kTBPackagingOutput                     =      @"TBPackagingOutput";


@interface CodesignHandler ()

@property(nonatomic, strong) NSString *codesigningResult;
@property(nonatomic, strong) NSString *verificationResult;
@property(nonatomic, strong) NSString *originalIpaPath;
@property(nonatomic, strong) NSString *appPath;
@property(nonatomic, strong) NSString *workingPath;
@property(nonatomic, strong) NSString *outputPath;

@property(nonatomic, strong) NSString *provisioningPath;

@property(nonatomic, strong) NSString *appName;
@property(nonatomic, strong) NSString *fileName;

@property(nonatomic, strong) NSArray *getCertsResult;
@property(nonatomic, strong) NSTask *certTask;
@property(nonatomic, strong) NSTask *unzipTask;
@property(nonatomic, strong) NSTask *zipTask;
@property(nonatomic, strong) NSTask *provisioningTask;
@property(nonatomic, strong) NSTask *codesignTask;
@property(nonatomic, strong) NSTask *verifyTask;

@property(nonatomic, strong) NSArray *channelArray;
@property(nonatomic, assign) NSInteger currentZipTaskIndex;

@property(nonatomic, strong) Package *package;
@property(nonatomic, strong) ResignPackagesCompleteHandler handler;
@property(nonatomic, strong) ResignPackagesProgressHandler progressHandler;

@end

@implementation CodesignHandler


- (void)resignWithPackages:(Package *)package completeHandler:(ResignPackagesCompleteHandler)handler progressHandler:(ResignPackagesProgressHandler)progressHandler
{
    //Save cert name
    self.package = package;
    self.handler = handler;
    self.progressHandler = progressHandler;
    
    _verificationResult = nil;
    
    // 原始待签名IPA包路径
    self.originalIpaPath = self.package.sourcePath;
    // 签名过程临时包存放路径
    self.workingPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"com.tongbu.tbpackaging"];
    // 实际mobileprovision证书位置
    _provisioningPath = self.package.provisionPath;
    

    if ([[[_originalIpaPath pathExtension] lowercaseString] isEqualToString:@"ipa"]) {
        
        [self updateProgress:@"Setting up working directory"];
        
        [[NSFileManager defaultManager] removeItemAtPath:_workingPath error:nil];
        [[NSFileManager defaultManager] createDirectoryAtPath:_workingPath withIntermediateDirectories:TRUE attributes:nil error:nil];
        
        // 签名完成后包存放路径
        NSString *outputPath = self.outputPath;
        [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
        
        // 解压IPA包
        [self doUnzip];
        
    } else {
        
        [self completeHandler:@"" errorString:_(@"You must choose an *.ipa file")];
        
    }
}


- (void)updateProgress:(NSString *)msg
{
    if (self.progressHandler) {
        self.progressHandler(msg);
    }
}

- (void)completeHandler:(NSString *)msg errorString:(NSString *)errorString
{
    NSError *error = nil;
    if (errorString) {
        error = [NSError errorWithDomain:@""
                                    code:0
                                userInfo:@{NSLocalizedDescriptionKey:errorString}];
    }
    self.handler(msg,error);
}


#pragma mark - Unzip process

- (void)doUnzip {
    if (_originalIpaPath && [_originalIpaPath length] > 0) {
        [self updateProgress:_(@"Extracting original app")];
    }
    
    _unzipTask = [[NSTask alloc] init];
    [_unzipTask setLaunchPath:@"/usr/bin/unzip"];
    [_unzipTask setArguments:[NSArray arrayWithObjects:@"-q", _originalIpaPath, @"-d", [self unzippedIPAPath], nil]];
    [_unzipTask launch];
    
    __weak typeof(self) weakSelf = self;
    [self addTerminationHandlerForTask:_unzipTask usingBlock:^{
        [weakSelf checkUnzip];
    }];
}

- (void)checkUnzip {
    if ([_unzipTask isRunning] == 0) {
        _unzipTask = nil;
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:[[self unzippedIPAPath] stringByAppendingPathComponent:@"Payload"]]) {
            [self updateProgress:_(@"Original app extracted")];
            // 解压完成修改info.plist信息
            [self changeAppInfo];
            
            NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[[self unzippedIPAPath] stringByAppendingPathComponent:@"Payload"] error:nil];
            
            // 获取 .app 路径及名称
            for (NSString *file in dirContents) {
                if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
                    self.appName = file;
                    self.appPath = [[[self unzippedIPAPath] stringByAppendingPathComponent:@"Payload"] stringByAppendingPathComponent:file];
                    break;
                }
            }
            
            //change version
            
            if ([self.package.certificate isEqualTo:@""]) {
                [self doChannelTask];
            } else {
                [self doProvisioning];
            }
        } else {
            [self completeHandler:@"" errorString:_(@"Unzip failed")];
        }
    }
}

#pragma mark - Provisioning process

- (void)doProvisioning {
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self.appPath stringByAppendingPathComponent:@"embedded.mobileprovision"]]) {
        [[NSFileManager defaultManager] removeItemAtPath:[self.appPath stringByAppendingPathComponent:@"embedded.mobileprovision"] error:nil];
    }
    NSString *targetPath = [self.appPath stringByAppendingPathComponent:@"embedded.mobileprovision"];
    
    _provisioningTask = [[NSTask alloc] init];
    [_provisioningTask setLaunchPath:@"/bin/cp"];
    [_provisioningTask setArguments:[NSArray arrayWithObjects:_provisioningPath, targetPath, nil]];
    
    __weak typeof(self) weakSelf = self;
    [self addTerminationHandlerForTask:_provisioningTask usingBlock:^{
        [weakSelf checkProvisioning];
    }];
    
    [_provisioningTask launch];
}

- (void)checkProvisioning {
    if ([_provisioningTask isRunning] == 0) {
        _provisioningTask = nil;
        
        NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[[self unzippedIPAPath] stringByAppendingPathComponent:@"Payload"] error:nil];
        
        for (NSString *file in dirContents) {
            if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
                self.appPath = [[[self unzippedIPAPath] stringByAppendingPathComponent:@"Payload"] stringByAppendingPathComponent:file];
                if ([[NSFileManager defaultManager] fileExistsAtPath:[_appPath stringByAppendingPathComponent:@"embedded.mobileprovision"]]) {
                    
                    BOOL identifierOK = NO;
                    BOOL certOK = NO;
                    NSDictionary *mobileProvision = [self mobileProvision];
                    
                    id value = [mobileProvision objectForKey:@"Entitlements"];
                    if ([value isKindOfClass:[NSDictionary class]]) {
                        NSDictionary *dictionary = (NSDictionary *)value;
                        //mobileprovision 中的identifier
                        /*
                         <key>Entitlements</key>
                         <dict>
                         <key>application-identifier</key>
                         <string>9CKSPC566N.*</string>
                         <key>com.apple.developer.team-identifier</key>
                         <string>9CKSPC566N</string>
                         <key>get-task-allow</key>
                         <false/>
                         <key>keychain-access-groups</key>
                         <array>
                         <string>9CKSPC566N.*</string>
                         </array>
                         </dict>
                         
                         */
                        NSString *applicationIdentifier = [dictionary objectForKey:@"application-identifier"];
                        NSString *applicationIdentifierPrefix = nil;
                        
                        /*
                         <key>ApplicationIdentifierPrefix</key>
                         <array>
                         <string>9CKSPC566N</string>
                         </array>
                         */
                        NSArray *applicationIdentifierPrefixs = [mobileProvision objectForKey:@"ApplicationIdentifierPrefix"];
                        if ([applicationIdentifierPrefixs count] > 0) {
                            applicationIdentifierPrefix = [applicationIdentifierPrefixs firstObject];
                        }
                        
                        if ([applicationIdentifier length] > [applicationIdentifierPrefix length]) {
                            NSString *identifierInProvisioning = [applicationIdentifier substringFromIndex:(applicationIdentifierPrefix.length +1)];
                            //                            NSLog(@"Mobileprovision identifier: %@",identifierInProvisioning);
                            if ([identifierInProvisioning isEqualToString:@"*"]) {
                                identifierOK = YES;
                            }else
                            {
                                NSString *fullAppIdentifier = [self appIdentifier];
                                if (identifierInProvisioning && [fullAppIdentifier rangeOfString:identifierInProvisioning].location != NSNotFound) {
                                    //                                    NSLog(@"Identifiers match");
                                    identifierOK = YES;
                                }
                            }
                        }
                    }
                    
                    //check team name
                    NSArray *certs = [mobileProvision objectForKey:@"DeveloperCertificates"];
                    if (certs.count > 0) {
                        NSString *teamName = [MobileProvision getCommonNameFormCert:certs[0]];
                        NSString *cert = self.package.certificate;
                        teamName = [teamName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                        if (teamName && cert && [cert rangeOfString:teamName].length > 0) {
                            certOK = YES;
                        }
                    }

                    
                    if (identifierOK && certOK) {
                        if (![self hasEntitlementsFile]) {
                            [self doEntitlements:mobileProvision];
                            
                            [self updateProgress:_(@"Provisioning completed")];
                            [self doChannelTask];
                        }else
                        {
                            [self updateProgress:_(@"Provisioning completed")];
                            [self doChannelTask];
                        }
                    } else {
                        [self completeHandler:@"" errorString:_(@"Product identifiers don't match")];

                    }
                } else {
                    [self completeHandler:@"" errorString:_(@"Can't find embedded.mobileprovision file")];

                }
                break;
            }
        }
    }
}

#pragma mark - Entitlements process
- (NSString *)appIdentifier
{
    return self.package.identifier;
//    NSString *appIdentifier = nil;
//    if (_appPath) {
//        NSString *infoPlitPath = [_appPath stringByAppendingPathComponent:@"Info.plist"];
//        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:infoPlitPath];
//        appIdentifier = [dict objectForKey:@"CFBundleIdentifier"];
//    }
//    return appIdentifier;
}

- (NSDictionary *)mobileProvision
{
    NSDictionary *propertyList = nil;
    NSString *targetPath = [_appPath stringByAppendingPathComponent:@"embedded.mobileprovision"];
    if (targetPath) {
        propertyList = [self mobileProvisionWithPath:targetPath];
    }
    return propertyList;
}

- (NSDictionary *)mobileProvisionWithPath:(NSString *)path
{
    NSDictionary *propertyList = nil;
    if (path) {
        
        NSData *fileData = [NSData dataWithContentsOfFile:path];
        if (fileData) {
            CMSDecoderRef decoder = NULL;
            CMSDecoderCreate(&decoder);
            CMSDecoderUpdateMessage(decoder, fileData.bytes, fileData.length);
            CMSDecoderFinalizeMessage(decoder);
            CFDataRef dataRef = NULL;
            CMSDecoderCopyContent(decoder, &dataRef);
            NSData *data = (NSData *)CFBridgingRelease(dataRef);
            CFRelease(decoder);
            if (data) {
                propertyList = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
            }
        }
    }
    return propertyList;
}


- (BOOL)hasEntitlementsFile
{
    return [[NSFileManager defaultManager] fileExistsAtPath:[self entitlementsPath]];
}


- (void)doEntitlements:(NSDictionary *)mobileProvision
{
    id value = [mobileProvision objectForKey:@"Entitlements"];
    
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = (NSDictionary *)value;
        NSString *appIdentifier = [self appIdentifier];
        
        NSString *applicationIdentifierPrefix = nil;
        NSArray *applicationIdentifierPrefixs = [mobileProvision objectForKey:@"ApplicationIdentifierPrefix"];
        if ([applicationIdentifierPrefixs count] > 0) {
            applicationIdentifierPrefix = [applicationIdentifierPrefixs firstObject];
        }
        
        NSString *applicationIdentifierForEntitlements = [NSString stringWithFormat:@"%@.%@",applicationIdentifierPrefix,appIdentifier];
        NSString *applicationIdentifierForEntitlementsPrefix = [NSString stringWithFormat:@"%@.",applicationIdentifierPrefix];
        
        NSMutableDictionary *entitlementDict = [NSMutableDictionary dictionary];
        for (NSString *key in dictionary.allKeys) {
            
            id object = [dictionary objectForKey:key];
            if ([object isKindOfClass:[NSString class]]) {
                if ([object hasPrefix:applicationIdentifierForEntitlementsPrefix]) {
                    [entitlementDict setObject:applicationIdentifierForEntitlements forKey:key];
                }else
                {
                    [entitlementDict setObject:object forKey:key];
                }
            }else if ([object isKindOfClass:[NSArray class]])
            {
                //
                NSMutableArray *tempArray = [NSMutableArray array];
                for (id obj in (NSArray *)object) {
                    if ([obj isKindOfClass:[NSString class]]) {
                        if ([obj hasPrefix:applicationIdentifierForEntitlementsPrefix]) {
                            [tempArray addObject:applicationIdentifierForEntitlements];
                        }else
                        {
                            [tempArray addObject:obj];
                        }
                    }else
                    {
                        [tempArray addObject:obj];
                    }
                }
                [entitlementDict setObject:tempArray forKey:key];
            }else
            {
                [entitlementDict setObject:object forKey:key];
            }
        }
        
        
        // 合并
        if (self.package.entitlementsPath)
        {
            NSString *customEntitlements = self.package.entitlementsPath;
            NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:customEntitlements];
            if (dict) {
                for (NSString *key in dict.allKeys) {
                    
                    //$(AppIdentifierPrefix)
                    id object = [dict objectForKey:key];
                    if ([object isKindOfClass:[NSString class]]) {
                        if ([object hasPrefix:@"$(AppIdentifierPrefix)"]) {
                            [entitlementDict setObject:applicationIdentifierForEntitlements forKey:key];
                        }else
                        {
                            [entitlementDict setObject:object forKey:key];
                        }
                    }else if ([object isKindOfClass:[NSArray class]])
                    {
                        //
                        NSMutableArray *tempArray = [NSMutableArray array];
                        for (id obj in (NSArray *)object) {
                            if ([obj isKindOfClass:[NSString class]]) {
                                if ([obj hasPrefix:@"$(AppIdentifierPrefix)"]) {
                                    [tempArray addObject:applicationIdentifierForEntitlements];
                                }else
                                {
                                    [tempArray addObject:obj];
                                }
                            }else
                            {
                                [tempArray addObject:obj];
                            }
                        }
                        [entitlementDict setObject:tempArray forKey:key];
                    }
                }
            }
        }
        
        //        NSLog(@"entitlements: %@",entitlementDict);
        [entitlementDict writeToFile:[self entitlementsPath] atomically:YES];
    }
}

#pragma mark - 修改info.plist
- (void)changeAppInfo
{
    // 修改Info.plist信息
    [self changeInfoPlist:[self packageAppinfoPlistChangeInfo]];
    // 修改Metadatain 信息
    [self changeITunesMetadatainfoPlist:[self packageItunesMetadataChangeInfo]];
}

- (NSArray *)packageAppinfoPlistChangeInfo
{
    NSMutableArray *tArray = [[NSMutableArray alloc] init];
    
    /*修改开发版本号*/
    if (self.package.bundleVersion && self.package.bundleVersion.length > 0) {
        NSDictionary *dic = [NSDictionary dictionaryWithObjectsAndKeys:self.package.bundleVersion,kBundleVersionPlistAppKey, nil];
        [tArray addObject:dic];
    }
    
    /*修改发行版本号*/
    if (self.package.shortVersion && self.package.shortVersion.length > 0){
        NSDictionary *dic = [NSDictionary dictionaryWithObjectsAndKeys:self.package.shortVersion,kCFBundleShortVersionString, nil];
        [tArray addObject:dic];
    }
    
    /*修改sku*/
    if (self.package.infoplistIdentifier && self.package.infoplistIdentifier.length > 0) {
        NSDictionary *dic = [NSDictionary dictionaryWithObjectsAndKeys:self.package.infoplistIdentifier,kCFBundleIdentifier, nil];
        [tArray addObject:dic];
    }
    NSLog(@"新的info.plist---> %@",tArray);
    return tArray;
}

- (NSArray *)packageItunesMetadataChangeInfo
{
    NSMutableArray *tArray = [[NSMutableArray alloc] init];
    
    /*修改发行版本号*/
    if (self.package.shortVersion && self.package.shortVersion.length > 0){
        NSDictionary *dic = [NSDictionary dictionaryWithObjectsAndKeys:self.package.shortVersion,kbundleVersion, nil];
        [tArray addObject:dic];
    }
    
    /*修改sku*/
    if (self.package.infoplistIdentifier && self.package.infoplistIdentifier.length > 0) {
        NSDictionary *dic = [NSDictionary dictionaryWithObjectsAndKeys:self.package.infoplistIdentifier,ksoftwareVersionBundleId, nil];
        [tArray addObject:dic];
    }
    
    return tArray;
}

- (BOOL)changeITunesMetadatainfoPlist:(NSArray *)infoArray {
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self unzippedIPAPath] error:nil];
    NSString *infoPlistPath = nil;
    
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"plist"]) {
            infoPlistPath = [[self unzippedIPAPath] stringByAppendingPathComponent:file];
            break;
        }
    }
    
    if (!infoPlistPath) {
        return NO;
    }
    
    if (!infoArray)
    {
        return NO;
    }
    
    BOOL success = NO;
    for (int i = 0; i < infoArray.count; i++)
    {
        NSDictionary *dict = [infoArray objectAtIndex:i];
        NSString *key = [[dict allKeys] objectAtIndex:0];
        NSString *value = [dict objectForKey:key];
        success |= [self changePlist:infoPlistPath key:key value:value plistOutOptions:NSPropertyListBinaryFormat_v1_0];
    }
    
    return success;
}

- (BOOL)changeInfoPlist:(NSArray *)infoArray {
    
    if (!infoArray || infoArray.count <= 0)
    {
        return NO;
    }
    
    NSString *payloadPath = [[self unzippedIPAPath] stringByAppendingPathComponent:kPayloadDirName];
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:payloadPath error:nil];
    
    NSString *infoPlistPath = nil;
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            infoPlistPath = [[payloadPath stringByAppendingPathComponent:file]stringByAppendingPathComponent:kInfoPlistFilename];
            break;
        }
    }
    
    BOOL success = NO;
    for (int j = 0; j < infoArray.count; j++)
    {
        NSDictionary *dict = [infoArray objectAtIndex:j];
        if ([dict.allKeys count] > 0) {
            NSString *key = [[dict allKeys] objectAtIndex:0];
            NSString *value = [dict objectForKey:key];
            success |= [self changePlist:infoPlistPath key:key value:value plistOutOptions:NSPropertyListBinaryFormat_v1_0];
        }
    }
    
    return success;
}

- (BOOL)changePlist:(NSString *)filePath key:(NSString *)key value:(NSString *)value plistOutOptions:(NSPropertyListWriteOptions)options {
    
    NSMutableDictionary *plist = nil;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        plist = [[NSMutableDictionary alloc] initWithContentsOfFile:filePath];
        [plist setObject:value forKey:key];
        
        NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:plist format:options options:kCFPropertyListImmutable error:nil];
        
        return [xmlData writeToFile:filePath atomically:YES];
    }
    
    return NO;
}

#pragma mark - Channel process

- (void)doChannelTask {
    if (_channelArray) {
        _channelArray = nil;
    }
    if ([self.package.channelArray count] > 0) {
        _channelArray = self.package.channelArray;
        _currentZipTaskIndex = 0;
        
        if (_channelArray.count > 0) {
            Channel *channel = [_channelArray objectAtIndex:0];
            [self createChannelFile:channel.text];
        } else {
            [self completeHandler:@"" errorString:_(@"Unrecognizable channel file")];

        }
    } else {
        [self doCodeSigning];
    }
}

- (void)createChannelFile:(NSString *)channelStr {
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self channelPath]]) {
        [[NSFileManager defaultManager] removeItemAtPath:[self channelPath] error:nil];
    }
    NSData *channelData = [channelStr dataUsingEncoding:NSASCIIStringEncoding];
    
    if (channelStr.length > 0) {
        if ([channelData writeToFile:[self channelPath] atomically:YES]) {
            [self doCodeSigning];
        } else {
            [self completeHandler:@"" errorString:_(@"Create channel failed")];
        }
    }else
    {
        [self doCodeSigning];
    }

}

#pragma mark - Codesigning process

- (void)doCodeSigning {
    if (_appPath) {
        
        
        NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"-fs", self.package.certificate, nil];
        
        SInt32 minor;
        Gestalt(gestaltSystemVersionMinor, &minor);
        if (minor < 9)
        {
            NSString *resourceRulesPath = [[NSBundle mainBundle] pathForResource:@"ResourceRules" ofType:@"plist"];
            NSString *resourceRulesArgument = [NSString stringWithFormat:@"--resource-rules=%@",resourceRulesPath];
            [arguments addObject:resourceRulesArgument];
        }else
        {            NSString *infoPath = [NSString stringWithFormat:@"%@/Info.plist", _appPath];
            NSMutableDictionary *infoDict = [NSMutableDictionary dictionaryWithContentsOfFile:infoPath];
            if ([infoDict.allKeys containsObject:@"CFBundleResourceSpecification"]) {
                [infoDict removeObjectForKey:@"CFBundleResourceSpecification"];
                //                [infoDict writeToFile:infoPath atomically:YES];
                NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:infoDict format:NSPropertyListBinaryFormat_v1_0 options:kCFPropertyListImmutable error:nil];
                [xmlData writeToFile:infoPath atomically:YES];
            }
        }
        
        //        if (![[_entitlementField stringValue] isEqualToString:@""]) {
        //            [arguments addObject:[NSString stringWithFormat:@"--entitlements=%@", [_entitlementField stringValue]]];
        //
        //        } else {
        // Check if original entitlements exist
        if ([[NSFileManager defaultManager] fileExistsAtPath:[self entitlementsPath]]) {
            [arguments addObject:[NSString stringWithFormat:@"--entitlements=%@", [self entitlementsPath]]];
        }
        //        }
        
        [arguments addObjectsFromArray:[NSArray arrayWithObjects:_appPath, nil]];
        
        _codesignTask = [[NSTask alloc] init];
        [_codesignTask setLaunchPath:@"/usr/bin/codesign"];
        [_codesignTask setArguments:arguments];
        
        NSPipe *pipe = [NSPipe pipe];
        [_codesignTask setStandardOutput:pipe];
        [_codesignTask setStandardError:pipe];
        NSFileHandle *handle = [pipe fileHandleForReading];
        
        __weak typeof(self) weakSelf = self;
        [self addTerminationHandlerForTask:_codesignTask usingBlock:^{
            [weakSelf checkCodesigning];
        }];
        
        [_codesignTask launch];
        [NSThread detachNewThreadSelector:@selector(watchCodesigning:)
                                 toTarget:self withObject:handle];
    }
}

- (void)watchCodesigning:(NSFileHandle*)streamHandle {
    @autoreleasepool {
        self.codesigningResult = [[NSString alloc] initWithData:[streamHandle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
    }
}

- (void)checkCodesigning {
    if ([_codesignTask isRunning] == 0) {
        _codesignTask = nil;
        //        NSLog(@"Codesigning done");
//        [_statusLabel setStringValue:_(@"Codesigning completed")];
        [self updateProgress:_(@"Codesigning completed")];
        [self doVerifySignature];
    }
}

#pragma mark - Verification process

- (void)doVerifySignature {
    if (_appPath) {
        _verifyTask = [[NSTask alloc] init];
        [_verifyTask setLaunchPath:@"/usr/bin/codesign"];
        [_verifyTask setArguments:[NSArray arrayWithObjects:@"-v", _appPath, nil]];
        
        [self updateProgress:[NSString stringWithFormat:_(@"Verifying %@"),_appName]];

        NSPipe *pipe=[NSPipe pipe];
        [_verifyTask setStandardOutput:pipe];
        [_verifyTask setStandardError:pipe];
        NSFileHandle *handle=[pipe fileHandleForReading];
        
        __weak typeof(self) weakSelf = self;
        [self addTerminationHandlerForTask:_verifyTask usingBlock:^{
            [weakSelf checkVerificationProcess];
        }];
        
        [_verifyTask launch];
        
        [NSThread detachNewThreadSelector:@selector(watchVerificationProcess:)
                                 toTarget:self withObject:handle];
        
    }
}

- (void)watchVerificationProcess:(NSFileHandle*)streamHandle {
    @autoreleasepool {
        self.verificationResult = [[NSString alloc] initWithData:[streamHandle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
    }
}

- (void)checkVerificationProcess {
    if ([_verifyTask isRunning] == 0) {
        _verifyTask = nil;
        if ([_verificationResult length] == 0) {
            //            NSLog(@"Verification done");
            [self updateProgress:_(@"Verification completed")];

            [self doZip];
        } else {
            [self completeHandler:@"" errorString:_(@"Signing failed")];
        }
    }
}

#pragma mark - Zip process

- (void)doZip {
    if (_appPath) {
        NSString *destinationPath = self.outputPath;
        if (![[NSFileManager defaultManager] fileExistsAtPath:destinationPath]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:destinationPath
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:nil];
        }
        destinationPath = [destinationPath stringByAppendingPathComponent:[self zippedNameForZipTaskIndex:_currentZipTaskIndex]];
        
        
        _zipTask = [[NSTask alloc] init];
        [_zipTask setLaunchPath:@"/usr/bin/zip"];
        [_zipTask setCurrentDirectoryPath:[self unzippedIPAPath]];
        [_zipTask setArguments:[NSArray arrayWithObjects:@"-qry", destinationPath, @".", nil]];
        
        [self updateProgress:[NSString stringWithFormat:_(@"Saving %@"),[self zippedNameForZipTaskIndex:_currentZipTaskIndex]]];

        __weak typeof(self) weakSelf = self;
        [self addTerminationHandlerForTask:_zipTask usingBlock:^{
            [weakSelf checkZip];
        }];
        
        [_zipTask launch];
    }
}

- (NSString *)zippedNameForZipTaskIndex:(NSInteger)taskIndex {
    
    NSString *zippedName = @"";
    if (_channelArray.count > taskIndex) {
        Channel *channel = [_channelArray objectAtIndex:taskIndex];
        zippedName = channel.name;
        zippedName = [zippedName stringByAppendingPathExtension:@"ipa"];
    } else {
        zippedName = [_originalIpaPath lastPathComponent];
        zippedName = [zippedName substringToIndex:[zippedName length]-4];
        zippedName = [zippedName stringByAppendingString:@"-packaged"];
        zippedName = [zippedName stringByAppendingPathExtension:@"ipa"];
    }
    return zippedName;
    
}

- (void)checkZip {
    if ([_zipTask isRunning] == 0) {
        _zipTask = nil;
        //        NSLog(@"Zipping done");
        [self updateProgress:[NSString stringWithFormat:_(@"Saved %@"),[self zippedNameForZipTaskIndex:_currentZipTaskIndex]]];
        // Check if all zip task done
        if (_channelArray.count > 0) {
            if (_currentZipTaskIndex < _channelArray.count - 1) {
                // Do next zip task
                _currentZipTaskIndex++;
                Channel *channel = [_channelArray objectAtIndex:_currentZipTaskIndex];
                [self createChannelFile:channel.text];
                
                return;
            }
        }
        [[NSFileManager defaultManager] removeItemAtPath:_workingPath error:nil];
        
        if (self.handler) {
            self.handler(@"成功",nil);
        }
    }
}

#pragma mark - Help methods

- (NSString *)outputPath
{
    return [self.package.baseDir stringByAppendingPathComponent:self.package.packageName];
}

- (NSString *)channelPath {
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[[self unzippedIPAPath] stringByAppendingPathComponent:kPayloadDirName] error:nil];
    NSString *channelPath = @"";
    
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            channelPath = [NSString stringWithFormat:@"%@/%@/%@/%@", [self unzippedIPAPath], kPayloadDirName, file, kChannelFileName];
            break;
        }
    }
    return channelPath;
}

- (NSString *)appPath {
    NSString *theAppPath = @"";;
    
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[[self unzippedIPAPath] stringByAppendingPathComponent:@"Payload"] error:nil];
    
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            theAppPath = [[[self unzippedIPAPath] stringByAppendingPathComponent:@"Payload"] stringByAppendingPathComponent:file];
            break;
        }
    }
    return theAppPath;
}

- (NSString *)unzippedIPAPath {
    return [_workingPath stringByAppendingPathComponent:kUnzippedIPAPath];
}

- (NSString *)entitlementsPath {
    return [_workingPath stringByAppendingString:@"/entitlements.plist"];
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
