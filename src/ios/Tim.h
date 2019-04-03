
#import <Cordova/CDV.h>
#import <ImSDK/ImSDK.h>

#define IOS10_OR_LATER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 10.0)
#define IOS9_OR_LATER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 9.0)
#define IOS8_OR_LATER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)
#define IOS7_OR_LATER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0)

@interface Tim : CDVPlugin
@property (nonatomic, strong) NSString *currentCallbackId;

- (void)init:(CDVInvokedUrlCommand *)command;

- (void)login:(CDVInvokedUrlCommand *)command;

- (void)logout:(CDVInvokedUrlCommand *)command;

- (void)send:(CDVInvokedUrlCommand *)command;

- (void)loadsession:(CDVInvokedUrlCommand *)command;

- (void)loadsessionlist:(CDVInvokedUrlCommand *)command;

- (void)addpushlistener:(CDVInvokedUrlCommand *)command;

- (void)addmessagelistener:(CDVInvokedUrlCommand *)command;

+ (void)registerDeviceToken:(NSData *)deviceToken;

+ (void)TimSetToken;
@end
