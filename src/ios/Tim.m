/********* Tim.m Cordova Plugin Implementation *******/

#import <Cordova/CDV.h>
#import "Tim.h"
#import <UserNotifications/UserNotifications.h>

@interface Tim() <TIMConnListener, TIMMessageListener, UNUserNotificationCenterDelegate>

@end



NSString* TAG = @"Tim";
NSString* TOP_LIST = @"top_list";

NSString* ERROR_INVALID_PARAMETERS = @"参数格式错误";

NSNumber* sdkAppId;
int busiId = 0;
NSData *notificationToken;

long mUnreadTotal;


@implementation Tim

- (void)pluginInitialize {
}

- (void)init:(CDVInvokedUrlCommand *)command {
    
    NSDictionary *params = [command.arguments objectAtIndex:0];
    if (!params)
    {
        [self failWithCallbackID:command.callbackId withMessage:@"参数格式错误"];
        return ;
    }
    sdkAppId = params[@"sdkAppId"];
    BOOL enableLogPrint = false;
    NSString* accountType = @"0";
    if ([params objectForKey:@"enableLogPrint"])
    {
        enableLogPrint = params[@"enableLogPrint"];
    }
    if ([params objectForKey:@"accountType"])
    {
        accountType = params[@"accountType"];
    }
    if ([params objectForKey:@"busiId"])
    {
        busiId = [params[@"busiId"] intValue];
    }
    // 初始化 SDK 基本配置
    
    TIMSdkConfig *sdkConfig = [[TIMSdkConfig alloc] init];
    sdkConfig.sdkAppId = [sdkAppId intValue];
    sdkConfig.accountType = [NSString stringWithFormat:@"%@", accountType];
    sdkConfig.connListener = self;
    [[TIMManager sharedInstance] initSdk:sdkConfig];
    [self successWithCallbackID:command.callbackId withMessage:@"success"];
}

- (void)login:(CDVInvokedUrlCommand *)command {
    NSDictionary *params = [command.arguments objectAtIndex:0];
    if (!params)
    {
        [self failWithCallbackID:command.callbackId withMessage:@"参数格式错误"];
        return ;
    }
    NSString* identifier = [NSString stringWithFormat:@"%@", params[@"identifier"]];
    NSString* userSig = [NSString stringWithFormat:@"%@", params[@"userSig"]];
    NSString* appidAt3rd = [NSString stringWithFormat:@"%@", sdkAppId];
    TIMLoginParam * login_param = [[TIMLoginParam alloc]init];
    // identifier 为用户名，userSig 为用户登录凭证
    // appidAt3rd 在私有帐号情况下，填写与 sdkAppId 一样
    login_param.identifier = identifier;
    login_param.userSig = userSig;
    [[TIMManager sharedInstance] login: login_param succ:^(){
        if (busiId > 0 && notificationToken != NULL) {
            [Tim TimSetToken];
        }
        [self successWithCallbackID:command.callbackId withMessage:@"success"];
    } fail:^(int code, NSString * err) {
        //错误码 code 和错误描述 desc，可用于定位请求失败原因
        //错误码 code 列表请参见错误码表
        NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
        [json setValue: [NSString stringWithFormat:@"%d", code] forKey:@"code"];
        [json setValue: err forKey:@"desc"];
        [self failWithCallbackID:command.callbackId withDictionary: json];
    }];
}

- (void)logout:(CDVInvokedUrlCommand *)command {
    [[TIMManager sharedInstance] logout:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self successWithCallbackID:command.callbackId withMessage:@"success"];
        });
    } fail:^(int code, NSString *desc) {
        NSLog(@"logout failed. code: %d errmsg: %@", code, desc);
        NSMutableDictionary *json = [NSMutableDictionary alloc];
        [json setValue: [NSNumber numberWithInt:code] forKey:@"code"];
        [json setValue: desc forKey:@"desc"];
        [self failWithCallbackID:command.callbackId withDictionary: json];
    }];
}

- (void)send:(CDVInvokedUrlCommand *)command {
    NSDictionary *params = [command.arguments objectAtIndex:0];
    if (!params)
    {
        [self failWithCallbackID:command.callbackId withMessage:@"参数格式错误"];
        return ;
    }
    NSString* msgcontent = params[@"msg"];
    //构造一条消息并添加一个文本内容
    TIMTextElem * elem = [[TIMTextElem alloc] init];
    [elem setText:msgcontent];
    TIMMessage * msg = [[TIMMessage alloc] init];
    [msg addElem:elem];
    TIMConversation *conversation = [self getconversation:command];
    [conversation sendMessage:msg succ:^(){
        NSLog(@"发送成功");
    }fail:^(int code, NSString * err) {
        NSLog(@"SendMsg Failed:%d->%@", code, err);
    }];
    
    NSString* selto = params[@"selto"];//获取与用户/群组 的会话
    NSLog(@"coversation start: selto = %@,   msg =  %@", selto, msgcontent);
    NSLog(@"send message start");
    
    [conversation sendMessage:msg succ:^{
        NSDictionary *json = [self TIMMessage2JSONObject:msg];
        [self successWithCallbackID:command.callbackId withDictionary:json];
    } fail:^(int code, NSString *desc) {
        NSLog(@"发送失败");
        NSLog(@"send message failed. code: %d errmsg: %@", code, desc);
        NSMutableDictionary *json = [NSMutableDictionary alloc];
        [json setValue: [NSNumber numberWithInt:code] forKey:@"code"];
        [json setValue: desc forKey:@"desc"];
        [self failWithCallbackID:command.callbackId withDictionary: json];
    }];
}

- (void)loadsession:(CDVInvokedUrlCommand *)command {
    //获取会话扩展实例
    TIMConversation *con = [self getconversation: command];
    
    //获取此会话的消息
    [con getMessage:999 //获取此会话最近的 10 条消息
               last: NULL //不指定从哪条消息开始获取 - 等同于从最新的消息开始往前
               succ: ^(NSArray *msgs) {//获取消息成功
                   //遍历取得的消息
                   NSMutableArray *json = [[NSMutableArray alloc] init];
                   // 要反向取 很神秘
                   for (long i = msgs.count - 1; i >= 0; i--) {
                       TIMMessage *msg = msgs[i];
                       //可以通过 timestamp()获得消息的时间戳, isSelf()是否为自己发送的消息
                       [json addObject: [self TIMMessage2JSONObject:msg]];
                   }
                   [self successWithCallbackID:command.callbackId withArray:json];
                   
               }
               fail: ^(int code, NSString *msg) {
                   //获取消息失败
                   //接口返回了错误码 code 和错误描述 desc，可用于定位请求失败原因
                   //错误码 code 含义请参见错误码表
                   NSLog(@"TIM 读取会话 message failed. code: %d errmsg: %@", code, msg);
                   [self failWithCallbackID:command.callbackId withMessage:[NSString stringWithFormat: @"get message failed. code: %d errmsg: %@", code, msg]];
               }];
}

- (void)loadsessionlist:(CDVInvokedUrlCommand *)command {
    TIMManager *manager = [TIMManager sharedInstance];
    NSArray *TIMSessions = [manager getConversationList];
    NSMutableArray *infos = [[NSMutableArray alloc] init];
    for (int i = 0; i < TIMSessions.count; i++) {
        TIMConversation *conversation = TIMSessions[i];
        //将imsdk TIMConversation转换为UIKit SessionInfo
        NSDictionary *json = [self TIMConversation2JSONObject : conversation];
        if (json != NULL) {
            mUnreadTotal = mUnreadTotal + [json[@"unRead"] intValue];
            [infos addObject:json];
            
        }
    }
    NSLog(@"TIM 读取会话列表 %@", infos);
    [self successWithCallbackID:command.callbackId withArray:infos];
}

- (void)addpushlistener:(CDVInvokedUrlCommand *)command {
    [self replyPushNotificationAuthorization:[UIApplication sharedApplication]];
}
- (void)addmessagelistener:(CDVInvokedUrlCommand *)command {
    
    TIMManager *manager = [TIMManager sharedInstance];
    //设置消息监听器，收到新消息时，通过此监听器回调
    [manager addMessageListener: self];
}
- (void) onNewMessage:(NSArray *)msgs {
    //消息的内容解析请参考消息收发文档中的消息解析说明
    NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
    NSMutableArray *msgjson = [[NSMutableArray alloc] init];
    if ([msgs count] > 0) {
        for (int i = 0; i < [msgs count]; i++) {
            NSDictionary *msg = [self TIMMessage2JSONObject: msgs[i]];
            [msgjson addObject: msg];
            [self sendLocalNotification: msg];
        }
    }
    [json setValue:msgjson forKey:@"msgs"];
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingPrettyPrinted error:&error];
    NSString *stringData = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSString *event = @"tim.messagelistener";
    //    NSString *js = [NSString stringWithFormat:@"%@(%@);", event, jsonData];
    NSString *evaljs = [NSString stringWithFormat:@"cordova.fireDocumentEvent('%@', %@)", event, stringData];
    //    NSLog(@"TIM 消息的内容解析请参考消息收发文档中的消息解析说明 Tim.MessageListenerCallback %@", jsonData);
    //    NSLog(@"TIM 消息的内容解析请参考消息收发文档中的消息解析说明 Tim.MessageListenerCallback %@", stringData);
    //    NSLog(@"TIM 消息的内容解析请参考消息收发文档中的消息解析说明 js %@", js);
    //    NSLog(@"TIM 消息的内容解析请参考消息收发文档中的消息解析说明 evaljs2 %@", evaljs);
    [self.commandDelegate evalJs:evaljs];
}
- (void)sendLocalNotification:(NSDictionary *) msg {
    //设置5秒之后
    NSDate *date = [NSDate dateWithTimeIntervalSinceNow:3];
    /*
     NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
     [formatter setDateFormat:@"HH:mm:ss"];
     NSDate *now = [formatter dateFromString:@"15:00:00"];//触发通知的时间
     */
    // 一个本地推送
    
    UILocalNotification *note = [[UILocalNotification alloc] init];
    
    if (note) {
        //内容
        NSString *body;
        NSDictionary *elem = [msg valueForKey:@"elements"];
        if ([[elem valueForKey:@"Type"][0] intValue] == 1) {
            body = [elem valueForKey:@"Content"][0];
        } else if ([[elem valueForKey:@"Type"][0] intValue] == 6) {
            body = @"[custom msg]";
        }
        note.alertBody = body;
        note.fireDate = date;
        UIUserNotificationSettings *local = [UIUserNotificationSettings settingsForTypes:1 << 2 categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:local];
        
        [[UIApplication sharedApplication] scheduleLocalNotification:note];
    }
}

- (void)onConnSucc {
    NSLog(@"conn success");
}
- (void)onConnFailed:(int)code err:(NSString *)err {
    NSLog(@"conn failed. code: %d errmsg: %@", code, err);
}
- (void)onDisconnect:(int)code err:(NSString *)err {
    NSLog(@"disconnect (duanwangla). code: %d errmsg: %@", code, err);
}
- (void)onConnecting {
    NSLog(@"conn onConnecting");
}

-(TIMConversation *)getconversation:(CDVInvokedUrlCommand *) command {
    
    NSDictionary *params = [command.arguments objectAtIndex:0];
    int conversationType = 1;
    
    if ([params objectForKey: @"conversationType"]) {
        conversationType = [params[@"conversationType"] intValue];
    }
    //获取会话
    NSString* selto = params[@"selto"];//获取与用户/群组 的会话
    TIMConversation *conv = [[TIMManager sharedInstance]
                             getConversation: (conversationType == 1 ? TIM_C2C : TIM_GROUP)//会话类型：单聊/群组
                             receiver:[NSString stringWithFormat:@"%@", selto]];//会话对方用户帐号//对方ID/群组 ID
    return conv;
}

-(NSDictionary *) TIMMessage2JSONObject:(TIMMessage *) msg {
    NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
    NSMutableArray *elements = [[NSMutableArray alloc] init];
    int count = msg.elemCount;
    for (int i = 0; i < count; ++i) {
        NSMutableDictionary *element = [[NSMutableDictionary alloc] init];
        TIMElem *elem = [msg getElem:i];
        if (elem != NULL) {
            if ([elem isKindOfClass:[TIMTextElem class]]) {
                TIMTextElem *textElem = (TIMTextElem *)elem;
                [element setValue:[NSNumber numberWithInt: 1] forKey:@"Type"];
                [element setValue:textElem.text forKey:@"Content"];
            } else if ([elem isKindOfClass:[TIMCustomElem class]]) {
                TIMCustomElem *customElem = (TIMCustomElem *) elem;
                [element setValue:[NSNumber numberWithInt: 6] forKey:@"Type"];
                [element setValue:customElem.desc forKey:@"desc"];
                [element setValue:customElem.data forKey:@"data"];
                [element setValue:customElem.ext forKey:@"ext"];
            }
            [elements addObject:element];
        }
    }
    [json setValue:[NSNumber numberWithInt: 0] forKey:@"ConverstaionType"];
    [json setValue:[[msg getConversation] getReceiver] forKey:@"ConversationId"];
    [json setValue:msg.msgId forKey:@"MsgId"];
    [json setValue:[NSNumber numberWithLong: [msg.timestamp timeIntervalSince1970]] forKey:@"time"];
    [json setValue:[NSNumber numberWithBool: msg.isSelf] forKey:@"isSelf"];
    [json setValue:msg.sender forKey:@"Status"];
    [json setValue:msg.sender forKey:@"Sender"];
    [json setValue:elements forKey:@"elements"];
    return json;
}

//    buildTIMMessageJSONObject
-(NSDictionary *)TIMConversation2JSONObject:(TIMConversation *) session {
    TIMMessage *msg = [session getLastMsg];
    if ([session getReceiver] == NULL || [[session getReceiver] isEqual:@""]) {
        return NULL;
    }
    if (msg == NULL) {
        return NULL;
    }
    NSDictionary *json = [self TIMMessage2JSONObject:msg];
    
    [json setValue:[NSNumber numberWithInt:[session getUnReadMessageNum]] forKey:@"unRead"];
    return json;
}

- (void)successWithCallbackID:(NSString *)callbackID
{
    [self successWithCallbackID:callbackID withMessage:@"OK"];
}

- (void)successWithCallbackID:(NSString *)callbackID withMessage:(NSString *)message
{
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:message];
    [self.commandDelegate sendPluginResult:commandResult callbackId:callbackID];
}
- (void)successWithCallbackID:(NSString *)callbackID withDictionary:(NSDictionary *)message
{
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
    [self.commandDelegate sendPluginResult:commandResult callbackId:callbackID];
}
- (void)successWithCallbackID:(NSString *)callbackID withArray:(NSArray *)message
{
    //    NSLog(@"TIM successWithCallbackID %@", message);
    //    NSMutableArray *newarray = [[NSMutableArray alloc] init];
    //    for (int i = 0; i < [message count]; i++) {
    //        NSLog(@"TIM successWithCallbackID dic %@", message[i]);
    //        NSError *error = nil;
    //        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:message[i] options:0 error:&error];
    //        NSLog(@"TIM successWithCallbackID jsonData %@", jsonData);
    //        //print out the data contents
    //        NSString* text =[[NSString alloc] initWithData:jsonData
    //                                              encoding:NSUTF8StringEncoding];
    //        NSLog(@"TIM successWithCallbackID text %@", text);
    //        [newarray addObject:text];
    //    }
    //    NSLog(@"TIM successWithCallbackID newarray %@", newarray);
    //    NSLog(@"TIM successWithCallbackID newarray %@", newarray);
    //    NSArray *array = [[NSArray alloc] initWithArray:message];
    //    NSLog(@"TIM successWithCallbackID array %@", array);
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray: message];
    [self.commandDelegate sendPluginResult:commandResult callbackId:callbackID];
}
- (void)failWithCallbackID:(NSString *)callbackID withError:(NSError *)error
{
    [self failWithCallbackID:callbackID withMessage:[error localizedDescription]];
}

- (void)failWithCallbackID:(NSString *)callbackID withMessage:(NSString *)message
{
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
    [self.commandDelegate sendPluginResult:commandResult callbackId:callbackID];
}
- (void)failWithCallbackID:(NSString *)callbackID withDictionary:(NSDictionary *)message
{
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:message];
    [self.commandDelegate sendPluginResult:commandResult callbackId:callbackID];
}
- (void)failWithCallbackID:(NSString *)callbackID withArray:(NSArray *)message
{
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsMultipart:message];
    [self.commandDelegate sendPluginResult:commandResult callbackId:callbackID];
}
/**
 *  在AppDelegate的回调中会返回DeviceToken，需要在登录后上报给腾讯云后台
 **/
-(void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    [Tim registerDeviceToken:deviceToken];
}
+ (void)registerDeviceToken:(NSData *)deviceToken
{
    // 如果在其他插件中有用到推送功能(如极光推送), 那么需要找到相应插件的返回token操作,并调用该函数[Tim registerDeviceToken];
    NSLog(@"didRegisterForRemoteNotificationsWithDeviceToken:%ld", (unsigned long)deviceToken.length);
    //    [[TIMManager sharedInstance] setToken:param];
    notificationToken = deviceToken;
    if (busiId > 0 && notificationToken != NULL) {
        [Tim TimSetToken];
    }
}
+ (void) TimSetToken {
    TIMTokenParam *param = [[TIMTokenParam alloc] init];
    /* 用户自己到苹果注册开发者证书，在开发者帐号中下载并生成证书(p12 文件)，将生成的 p12 文件传到腾讯证书管理控制台，控制台会自动生成一个证书 ID，将证书 ID 传入一下 busiId 参数中。*/
    NSString *token = [NSString stringWithFormat:@"%@", notificationToken];
    [[TIMManager sharedInstance] log:TIM_LOG_INFO tag:@"SetToken" msg:[NSString stringWithFormat:@"My Token is :%@", token]];
    param.busiId = busiId;
    [param setToken:notificationToken];
    [[TIMManager sharedInstance] setToken:param succ:^{
    } fail:^(int code, NSString *msg) {
        NSLog(@"code: %d, msg: %@", code, msg);
    }];
}

#pragma mark - 申请通知权限
// 申请通知权限
- (void)replyPushNotificationAuthorization:(UIApplication *)application{
    
    if (IOS10_OR_LATER) {
        //iOS 10 later
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        //必须写代理，不然无法监听通知的接收与点击事件
        center.delegate = self;
        [center requestAuthorizationWithOptions:(UNAuthorizationOptionBadge | UNAuthorizationOptionSound | UNAuthorizationOptionAlert) completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (!error && granted) {
                //用户点击允许
                NSLog(@"注册成功");
            }else{
                //用户点击不允许
                NSLog(@"注册失败");
            }
        }];
        
        // 可以通过 getNotificationSettingsWithCompletionHandler 获取权限设置
        //之前注册推送服务，用户点击了同意还是不同意，以及用户之后又做了怎样的更改我们都无从得知，现在 apple 开放了这个 API，我们可以直接获取到用户的设定信息了。注意UNNotificationSettings是只读对象哦，不能直接修改！
        [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
        }];
    }else if (IOS8_OR_LATER){
        //iOS 8 - iOS 10系统
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound categories:nil];
        [application registerUserNotificationSettings:settings];
    }else{
        //iOS 8.0系统以下
        [application registerForRemoteNotificationTypes:UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeSound];
    }
    
    //注册远端消息通知获取device token
    [application registerForRemoteNotifications];
}
@end
