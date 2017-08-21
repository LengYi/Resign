//
//  AppDelegate.h
//  TBRePackaging
//
//  Created by zeejun on 15-4-8.
//  Copyright (c) 2015年 tongbu. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (unsafe_unretained) IBOutlet NSTextView *textView;
@property (unsafe_unretained) IBOutlet NSTextView *baseTextView;

@property (weak) IBOutlet NSTextField *statusLabel;
@property (weak) IBOutlet NSButton *startButton;
@property (weak) IBOutlet NSButton *helperButton;
@property (weak) IBOutlet NSButton *reloadCertButon;


- (IBAction)startButtonOnclicked:(id)sender;
- (IBAction)helperButtonOnClicked:(id)sender;
- (IBAction)reloadCertButtonOnclicked:(id)sender;

@end

