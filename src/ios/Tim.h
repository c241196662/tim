//
//  CDVWechat.h
//  cordova-plugin-adam-wechat
//
//  Created by xu.li on 12/23/13.
//
//

#import <Cordova/CDV.h>

@interface CDVWechat:CDVPlugin <WXApiDelegate>

- (void)coolMethod:(CDVInvokedUrlCommand*)command;

@end
