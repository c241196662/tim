
#import <Cordova/CDV.h>
#import <ImSDK/ImSDK.h>

@interface Tim : CDVPlugin
@property (nonatomic, strong) NSString *currentCallbackId;

- (void)init:(CDVInvokedUrlCommand *)command;

- (void)login:(CDVInvokedUrlCommand *)command;

- (void)logout:(CDVInvokedUrlCommand *)command;

- (void)send:(CDVInvokedUrlCommand *)command;

- (void)loadsession:(CDVInvokedUrlCommand *)command;

- (void)loadsessionlist:(CDVInvokedUrlCommand *)command;

- (void)addPushListener;

- (void)addMessageListener;

@end
