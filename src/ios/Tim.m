/********* Tim.m Cordova Plugin Implementation *******/

#import <Cordova/CDV.h>
#import "Tim.h"

@interface Tim() <TIMConnListener, TIMMessageListener>

@end



NSString* TAG = @"Tim";
NSString* TOP_LIST = @"top_list";

NSString* ERROR_INVALID_PARAMETERS = @"参数格式错误";

NSNumber* sdkAppId;
int busiId;

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
        busiId = params[@"busiId"];
    }
    // 初始化 SDK 基本配置
    
    TIMSdkConfig *sdkConfig = [[TIMSdkConfig alloc] init];
    sdkConfig.sdkAppId = (int)sdkAppId;
    sdkConfig.accountType = accountType;
    sdkConfig.connListener = self;
    [[TIMManager sharedInstance] initSdk:sdkConfig];
    [self successWithCallbackID:self.currentCallbackId];
}

- (void)login:(CDVInvokedUrlCommand *)command {
    NSDictionary *params = [command.arguments objectAtIndex:0];
    if (!params)
    {
        [self failWithCallbackID:command.callbackId withMessage:@"参数格式错误"];
        return ;
    }
    NSString* identifier = params[@"identifier"];
    NSString* userSig = params[@"userSig"];
    // identifier为用户名，userSig 为用户登录凭证
    TIMLoginParam *param = [[TIMLoginParam alloc] init];
    param.identifier = identifier;
    param.userSig = userSig;
    [[TIMManager sharedInstance] login:param succ:^{
        NSLog(@"login succ");
    } fail:^(int code, NSString *desc) {
        //错误码 code 和错误描述 desc，可用于定位请求失败原因
        //错误码 code 列表请参见错误码表
        NSLog(@"login failed. code: %d errmsg: %@", code, desc);
        [self successWithCallbackID:self.currentCallbackId];
    }];
}

- (void)logout:(CDVInvokedUrlCommand *)command {
    [[TIMManager sharedInstance] logout:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self successWithCallbackID:self.currentCallbackId];
        });
    } fail:^(int code, NSString *msg) {
        NSLog(@"logout failed. code: %d errmsg: %@", code, msg);
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
        [self successWithCallbackID:self.currentCallbackId withDictionary:json];
    } fail:^(int code, NSString *desc) {
        NSLog(@"发送失败");
        NSLog(@"send message failed. code: %d errmsg: %@", code, desc);
        NSDictionary *json = [NSDictionary alloc];
        [json setValue: [NSNumber numberWithInt:code] forKey:@"code"];
        [json setValue: desc forKey:@"desc"];
        [self successWithCallbackID:self.currentCallbackId withDictionary: json];
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
                   for (unsigned long i = msgs.count - 1; i >= 0; i--) {
                       TIMMessage *msg = msgs[i];
                       //可以通过 timestamp()获得消息的时间戳, isSelf()是否为自己发送的消息
                       NSLog(@"get msg: %@ self: %@ sender: %@", msg.timestamp, msg.isSelf, msg.sender);
                       [json addObject: [self TIMMessage2JSONObject:msg]];
                   }
                   [self successWithCallbackID:self.currentCallbackId withArray:json];
                   
               }
               fail: ^(int code, NSString *msg) {
                   //获取消息失败
                   //接口返回了错误码 code 和错误描述 desc，可用于定位请求失败原因
                   //错误码 code 含义请参见错误码表
                   NSLog(@"get message failed. code: %d errmsg: %@", code, msg);
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
    [self successWithCallbackID:self.currentCallbackId withArray:infos];
}

- (void)addPushListener {
    [self registNotification];
}
- (void)addMessageListener {
    
    TIMManager *manager = [TIMManager sharedInstance];
    //设置消息监听器，收到新消息时，通过此监听器回调
    [manager addMessageListener: self];
}
- (void) onNewMessage:(NSArray *)msgs {
    //消息的内容解析请参考消息收发文档中的消息解析说明
    NSDictionary *json = [[NSDictionary alloc] init];
    NSMutableArray *msgjson = [[NSMutableArray alloc] init];
    if ([msgs count] > 0) {
        for (int i = 0; i < [msgs count]; i++) {
            [msgjson addObject: [self TIMMessage2JSONObject: msgs[i]]];
        }
    }
    [json setValue:msgjson forKey:@"msgs"];
    
    NSString* js = [NSString stringWithFormat:@"Tim.MessageListenerCallback(%@);", json];
    [self.commandDelegate evalJs:[NSString stringWithFormat:@"cordova.fireDocumentEvent('%@', %@)", js, json]];
}
- (void)sendNoResultPluginResult {
    // send no result and keep callback
    //        PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
    //        result.setKeepCallback(true);
    //        callbackContext.sendPluginResult(result);
    [self successWithCallbackID:self.currentCallbackId withMessage:@"success"];
}

-(TIMConversation *)getconversation:(CDVInvokedUrlCommand *) command {
    
    NSDictionary *params = [command.arguments objectAtIndex:0];
    int conversationType = 1;
    
    if ([params objectForKey: @"conversationType"]) {
        conversationType = params[@"conversationType"];
    }
    //获取会话
    NSString* selto = params[@"selto"];//获取与用户/群组 的会话
    TIMConversation *conv = [[TIMManager sharedInstance]
                             getConversation: conversationType//会话类型：单聊/群组
                             receiver:selto];//会话对方用户帐号//对方ID/群组 ID
    return conv;
}

-(NSDictionary *) TIMMessage2JSONObject:(TIMMessage *) msg {
    NSDictionary *json = [[NSDictionary alloc] init];
    NSMutableArray *elements = [[NSMutableArray alloc] init];
    int count = msg.elemCount;
    for (int i = 0; i < count; ++i) {
        NSDictionary *element = [[NSDictionary alloc] init];
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
    [json setValue:msg.timestamp forKey:@"time"];
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
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsMultipart:message];
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
- (void)registNotification
{
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)
    {
        [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge) categories:nil]];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    }
    else
    {
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes: (UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert)];
    }
}
/**
 *  在AppDelegate的回调中会返回DeviceToken，需要在登录后上报给腾讯云后台
 **/
-(void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    [self configOnAppRegistAPNSWithDeviceToken:deviceToken];
}
- (void)configOnAppRegistAPNSWithDeviceToken:(NSData *)deviceToken
{
    NSLog(@"didRegisterForRemoteNotificationsWithDeviceToken:%ld", (unsigned long)deviceToken.length);
    NSString *token = [NSString stringWithFormat:@"%@", deviceToken];
    [[TIMManager sharedInstance] log:TIM_LOG_INFO tag:@"SetToken" msg:[NSString stringWithFormat:@"My Token is :%@", token]];
    TIMTokenParam *param = [[TIMTokenParam alloc] init];
    /* 用户自己到苹果注册开发者证书，在开发者帐号中下载并生成证书(p12 文件)，将生成的 p12 文件传到腾讯证书管理控制台，控制台会自动生成一个证书 ID，将证书 ID 传入一下 busiId 参数中。*/
    param.busiId = busiId;
    [param setToken:deviceToken];
    //    [[TIMManager sharedInstance] setToken:param];
    [[TIMManager sharedInstance] setToken:param succ:^{
        NSLog(@"-----> 上传 token 成功 ");
    } fail:^(int code, NSString *msg) {
        NSLog(@"-----> 上传 token 失败 ");
    }];
}
@end
