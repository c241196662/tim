package cordova.plugin.bakaan.tim;

import android.app.Activity;
import android.app.Application;
import android.content.Context;
import android.media.Ringtone;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
import android.os.Vibrator;
import android.util.Log;

import org.apache.cordova.CordovaArgs;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;

import com.tencent.imsdk.TIMCallBack;
import com.tencent.imsdk.TIMConversation;
import com.tencent.imsdk.TIMConversationType;
import com.tencent.imsdk.TIMCustomElem;
import com.tencent.imsdk.TIMElem;
import com.tencent.imsdk.TIMElemType;
import com.tencent.imsdk.TIMImage;
import com.tencent.imsdk.TIMImageElem;
import com.tencent.imsdk.TIMLogLevel;
import com.tencent.imsdk.TIMManager;
import com.tencent.imsdk.TIMMessage;
import com.tencent.imsdk.TIMMessageListener;
import com.tencent.imsdk.TIMMessageOfflinePushSettings;
import com.tencent.imsdk.TIMOfflinePushListener;
import com.tencent.imsdk.TIMOfflinePushNotification;
import com.tencent.imsdk.TIMOfflinePushSettings;
import com.tencent.imsdk.TIMSdkConfig;
import com.tencent.imsdk.TIMTextElem;
import com.tencent.imsdk.TIMValueCallBack;
import com.tencent.imsdk.ext.message.TIMConversationExt;
import com.tencent.imsdk.ext.message.TIMManagerExt;

import org.apache.cordova.CordovaWebView;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.List;

import static android.content.Context.VIBRATOR_SERVICE;


/**
 * This class echoes a string called from JavaScript.
 */
public class Tim extends CordovaPlugin {

    private static final String TAG = Tim.class.getSimpleName();
    private final static String TOP_LIST = "top_list";

    public static final String ACTION_INIT = "init"; // 初始化
    public static final String ACTION_LOGIN = "login"; // 登录
    public static final String ACTION_LOGOUT = "logout"; // 登出
    public static final String ACTION_SEND = "send"; // 发送
    public static final String ACTION_ADDMESSAGELISTENER = "addmessagelistener"; // 增加消息接收监听
    public static final String ACTION_ADDPUSHLISTENER = "addpushlistener"; // 增加消息推送监听
    public static final String ACTION_LOADSESSION = "loadsession"; // 获取历史消息
    public static final String ACTION_LOADSESSIONLIST = "loadsessionlist"; // 获取所有人的历史消息

    public static final String ERROR_INVALID_PARAMETERS = "参数格式错误";

    protected static int sdkAppId;
    protected static int backgroundcount = 1;

    private static Context mContext;
    private static Tim instance;
    private static Activity cordovaActivity;

    private int mUnreadTotal;

    public Tim() {
        instance = this;
    }

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);
        mContext = cordova.getActivity().getApplicationContext();
        cordovaActivity = cordova.getActivity();
        cordovaActivity.getApplication().registerActivityLifecycleCallbacks(new Application.ActivityLifecycleCallbacks() {
            @Override
            public void onActivityCreated(Activity activity, Bundle savedInstanceState) {

            }

            @Override
            public void onActivitySaveInstanceState(Activity activity, Bundle outState) {

            }

            @Override
            public void onActivityDestroyed(Activity activity) {

            }

            @Override
            public void onActivityStarted(Activity activity) {
                backgroundcount = 1;
                if (backgroundcount == 1) {
                    Log.e("ZXK", "foreground");
                }
            }

            @Override
            public void onActivityResumed(Activity activity) {

            }

            @Override
            public void onActivityPaused(Activity activity) {

            }

            @Override
            public void onActivityStopped(Activity activity) {
                backgroundcount = 0;
                if (backgroundcount == 0) {
                    Log.e("ZXK", "background");
                }
            }
        });
    }

    @Override
    public boolean execute(String action, CordovaArgs args, CallbackContext callbackContext) {
        switch (action) {
            case ACTION_INIT:
                this.init(args, callbackContext);
                return true;
            case ACTION_LOGIN:
                this.login(args, callbackContext);
                return true;
            case ACTION_LOGOUT:
                this.logout(args, callbackContext);
                return true;
            case ACTION_SEND:
                this.send(args, callbackContext);
                return true;
            case ACTION_ADDMESSAGELISTENER:
                this.addMessageListener(callbackContext);
                return true;
            case ACTION_ADDPUSHLISTENER:
                this.addPushListener(callbackContext);
                return true;
            case ACTION_LOADSESSION:
                this.loadsession(args, callbackContext);
                return true;
            case ACTION_LOADSESSIONLIST:
                this.loadsessionlist(args, callbackContext);
                return true;
        }
        return false;
    }

    private void init(CordovaArgs args, CallbackContext callbackContext) {

        final JSONObject params;
        try {
            params = args.getJSONObject(0);
            sdkAppId = params.getInt("sdkAppId");
            boolean enableLogPrint = params.has("enableLogPrint") ? params.getBoolean("enableLogPrint") : false;
            String accountType = params.has("accountType") ? params.getString("accountType") : "0";
            // 初始化 SDK 基本配置
            TIMSdkConfig config = new TIMSdkConfig(sdkAppId).setAccoutType(accountType).enableLogPrint(enableLogPrint) // 是否在控制台打印Log?
                    .setLogLevel(TIMLogLevel.DEBUG) // Log输出级别（debug级别会很多）
                    .setLogPath(Environment.getExternalStorageDirectory().getPath() + "/timlogs/");
            // Log文件存放在哪里？

            // 初始化 SDK
            TIMManager.getInstance().init(cordovaActivity.getApplicationContext(), config);
            sendNoResultPluginResult(callbackContext);
        } catch (JSONException e) {
            callbackContext.error(ERROR_INVALID_PARAMETERS);
            return;
        }
    }

    private void login(CordovaArgs args, final CallbackContext callbackContext) {
        final JSONObject params;
        try {
            params = args.getJSONObject(0);
            String identifier = params.getString("identifier");
            String userSig = params.getString("userSig");
            // identifier为用户名，userSig 为用户登录凭证
            TIMManager.getInstance().login(identifier, userSig, new TIMCallBack() {
                @Override
                public void onError(int code, String desc) {
                    //错误码 code 和错误描述 desc，可用于定位请求失败原因
                    //错误码 code 列表请参见错误码表
                    Log.d(TAG, "login failed. code: " + code + " errmsg: " + desc);
                    JSONObject json = new JSONObject();
                    try {
                        json.put("code", code);
                        json.put("desc", desc);
                    } catch (JSONException e) {
                        e.printStackTrace();
                    }
                    callbackContext.error(json);
                }

                @Override
                public void onSuccess() {
                    Log.d(TAG, "login succ");
                    sendNoResultPluginResult(callbackContext);
                }
            });
        } catch (JSONException e) {
            callbackContext.error(ERROR_INVALID_PARAMETERS);
            return;
        }
    }

    private void logout(CordovaArgs args, final CallbackContext callbackContext) {
        final JSONObject params;
        try {
            params = args.getJSONObject(0);
            String identifier = params.getString("identifier");
            String userSig = params.getString("userSig");
            // identifier为用户名，userSig 为用户登录凭证
            TIMManager.getInstance().logout(new TIMCallBack() {
                @Override
                public void onError(int code, String desc) {
                    Log.d(TAG, "login failed. code: " + code + " errmsg: " + desc);
                    JSONObject json = new JSONObject();
                    try {
                        json.put("code", code);
                        json.put("desc", desc);
                    } catch (JSONException e) {
                        e.printStackTrace();
                    }
                    callbackContext.error(json);
                }

                @Override
                public void onSuccess() {
                    Log.d(TAG, "login succ");
                    sendNoResultPluginResult(callbackContext);
                }
            });
        } catch (JSONException e) {
            callbackContext.error(ERROR_INVALID_PARAMETERS);
            return;
        }
    }

    private void send(CordovaArgs args, final CallbackContext callbackContext) {
        final JSONObject params;
        try {
            params = args.getJSONObject(0);
            String msgtype = params.getString("msgtype");
            //构造一条消息并添加一个文本内容
            TIMMessage msg = new TIMMessage();
            if ("text".equals(msgtype)) {
                TIMTextElem elem = new TIMTextElem();
                String msgcontent = params.getString("msg");
                elem.setText(msgcontent);
                msg.addElement(elem);
            } else if ("img".equals(msgtype)) {
                //添加图片
                TIMImageElem elem = new TIMImageElem();
                String imgurl = params.getString("imgurl");
                imgurl = imgurl.replace("file://", "");
                imgurl = imgurl.split("\\?")[0];
                elem.setPath(imgurl);
                msg.addElement(elem);
                Log.i(TAG, "imgurl: " + Environment.getExternalStorageDirectory());
                Log.i(TAG, "imgurl: " + imgurl);
            }

            String selto = params.getString("selto");//获取与用户/群组 的会话
            TIMConversation conversation = getconversation(args);
            Log.i(TAG, "send message start");
            //发送消息
            conversation.sendMessage(msg, new TIMValueCallBack<TIMMessage>() {
                @Override
                public void onError(int code, String desc) {//发送消息失败
                    //错误码 code 和错误描述 desc，可用于定位请求失败原因
                    Log.d(TAG, "send message failed. code: " + code + " errmsg: " + desc);
                    JSONObject json = new JSONObject();
                    try {
                        json.put("code", code);
                        json.put("desc", desc);
                    } catch (JSONException e) {
                        e.printStackTrace();
                    }
                    callbackContext.error(json);
                }

                @Override
                public void onSuccess(TIMMessage msg) {//发送消息成功
                    Log.e(TAG, "SendMsg ok");
                    JSONObject json = new JSONObject();
                    try {
                        json = TIMMessage2JSONObject(msg);
                    } catch (JSONException e) {
                        e.printStackTrace();
                    }
                    callbackContext.success(json);
                }
            });
        } catch (JSONException e) {
            callbackContext.error(ERROR_INVALID_PARAMETERS);
            return;
        }
    }

    private void loadsession(CordovaArgs args, final CallbackContext callbackContext) {
        final JSONObject params;
        try {
            //获取会话扩展实例
            TIMConversation con = getconversation(args);
            TIMConversationExt conExt = new TIMConversationExt(con);

            //获取此会话的消息
            conExt.getMessage(999, //获取此会话最近的 10 条消息
                    null, //不指定从哪条消息开始获取 - 等同于从最新的消息开始往前
                    new TIMValueCallBack<List<TIMMessage>>() {//回调接口
                        @Override
                        public void onError(int code, String desc) {//获取消息失败
                            //接口返回了错误码 code 和错误描述 desc，可用于定位请求失败原因
                            //错误码 code 含义请参见错误码表
                            Log.d(TAG, "get message failed. code: " + code + " errmsg: " + desc);
                            callbackContext.error("get message failed. code: " + code + " errmsg: " + desc);
                        }

                        @Override
                        public void onSuccess(List<TIMMessage> msgs) {//获取消息成功
                            //遍历取得的消息
                            JSONArray json = new JSONArray();
                            try {
                                // 要反向取 很神秘
                                for (int i = msgs.size() - 1; i >= 0; i--) {
                                    TIMMessage msg = msgs.get(i);
                                    //可以通过 timestamp()获得消息的时间戳, isSelf()是否为自己发送的消息
                                    Log.e(TAG, "get msg: " + msg.timestamp() + " self: " + msg.isSelf() + " seq: " + msg.getSeq());
                                    json.put(TIMMessage2JSONObject(msg));
                                }
                                callbackContext.success(json);
                            } catch (JSONException e) {
                                e.printStackTrace();
                                callbackContext.error("json error");
                            }
                        }
                    });
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }

    private void loadsessionlist(CordovaArgs args, CallbackContext callbackContext) {
        List<TIMConversation> TIMSessions = TIMManagerExt.getInstance().getConversationList();
        JSONArray infos = new JSONArray();
        try {
            for (int i = 0; i < TIMSessions.size(); i++) {
                TIMConversation conversation = TIMSessions.get(i);
                //将imsdk TIMConversation转换为UIKit SessionInfo
                JSONObject json = TIMConversation2JSONObject(conversation);
                if (json != null) {
                    mUnreadTotal = mUnreadTotal + json.getInt("unRead");
                    infos.put(json);

                }
            }
            callbackContext.success(infos);
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }

    private void addPushListener(final CallbackContext callbackContext) {
        TIMOfflinePushSettings settings = new TIMOfflinePushSettings();
        settings.setEnabled(true);
        //设置在 Android 设备上收到消息时的离线配置
        TIMMessageOfflinePushSettings.AndroidSettings androidSettings = new TIMMessageOfflinePushSettings.AndroidSettings();

        //推送自定义通知栏消息，接收方收到消息后单击通知栏消息会给应用回调（针对小米、华为离线推送）
        androidSettings.setNotifyMode(TIMMessageOfflinePushSettings.NotifyMode.Normal);
        TIMMessageOfflinePushSettings.IOSSettings iosSettings = new TIMMessageOfflinePushSettings.IOSSettings();
        //开启 Badge 计数
        iosSettings.setBadgeEnabled(true);
        TIMManager.getInstance().setOfflinePushSettings(settings);
        // 设置离线消息通知
        TIMManager.getInstance().setOfflinePushListener(new TIMOfflinePushListener() {

            @Override
            public void handleNotification(TIMOfflinePushNotification notification) {
                Log.d(TAG, "recv offline push backgroundcount:" + backgroundcount);
                // 判断APP是否处于激活(前台)状态
                if (backgroundcount != 1) {
                    Uri notificationuri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION);
//                    Ringtone r = RingtoneManager.getRingtone(getApplicationContext(), notification);
//                    r.play();

                    notification.setTitle("您有新的消息");
                    notification.setContent("请注意查收");
                    notification.setSound(notificationuri);
                    // 震动
                    Vibrator vibrator = (Vibrator) mContext.getSystemService(VIBRATOR_SERVICE);
                    vibrator.vibrate(1000);
                    // 这里的 doNotify 是 ImSDK 内置的通知栏提醒，应用也可以选择自己利用回调参数 notification 来构造自己的通知栏提醒
                    notification.doNotify(mContext.getApplicationContext(), mContext.getApplicationInfo().icon);
                }
            }
        });
    }

    private void addMessageListener(final CallbackContext callbackContext) {
        //设置消息监听器，收到新消息时，通过此监听器回调
        TIMManager.getInstance().addMessageListener(new TIMMessageListener() {//消息监听器
            @Override
            public boolean onNewMessages(List<TIMMessage> msgs) {//收到新消息
                //消息的内容解析请参考消息收发文档中的消息解析说明
                JSONObject json = new JSONObject();
                JSONArray msgjson = new JSONArray();
                try {
                    if (msgs.size() > 0) {
                        for (int i = 0; i < msgs.size(); i++) {
                            msgjson.put(TIMMessage2JSONObject(msgs.get(i)));
                        }
                    }
                } catch (JSONException e) {
                    e.printStackTrace();
                }
                try {
                    json.put("msgs", msgjson);
                } catch (JSONException e) {
                    e.printStackTrace();
                }

                String format = "Tim.MessageListenerCallback(%s);";
                final String js = String.format(format, json);
                cordovaActivity.runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        instance.webView.loadUrl("javascript:" + js);
                    }
                });
                TIMOfflinePushNotification notification = new TIMOfflinePushNotification();
                // 判断APP是否处于激活(前台)状态
                if (backgroundcount != 1) {
                    Uri notificationuri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION);
//                    Ringtone r = RingtoneManager.getRingtone(getApplicationContext(), notification);
//                    r.play();

                    notification.setTitle("您有新的消息");
                    notification.setContent("请注意查收");
                    notification.setSound(notificationuri);
                    // 震动
                    Vibrator vibrator = (Vibrator) mContext.getSystemService(VIBRATOR_SERVICE);
                    vibrator.vibrate(1000);
                    // 这里的 doNotify 是 ImSDK 内置的通知栏提醒，应用也可以选择自己利用回调参数 notification 来构造自己的通知栏提醒
                    notification.doNotify(mContext.getApplicationContext(), mContext.getApplicationInfo().icon);
                }
                return true; //返回true将终止回调链，不再调用下一个新消息监听器
            }
        });
    }

    private void sendNoResultPluginResult(CallbackContext callbackContext) {
        // send no result and keep callback
//        PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
//        result.setKeepCallback(true);
//        callbackContext.sendPluginResult(result);
        callbackContext.success("success");
    }

    /**
     * 获取回话, 读取/发送消息用
     *
     * @param args
     * @return
     */
    private TIMConversation getconversation(CordovaArgs args) throws JSONException {

        final JSONObject params;
        try {
            params = args.getJSONObject(0);
            int conversationType = params.has("conversationType") ? params.getInt("conversationType") : 1;

            //获取会话
            String selto = params.getString("selto");//获取与用户/群组 的会话
            TIMConversation conversation = TIMManager.getInstance().getConversation(
                    conversationType == 1 ? TIMConversationType.C2C : TIMConversationType.Group,    //会话类型：单聊/群组
                    selto);                      //会话对方用户帐号//对方ID/群组 ID
            return conversation;
        } catch (JSONException e) {
            return null;
        }
    }

    private JSONObject TIMMessage2JSONObject(TIMMessage msg) throws JSONException {
        JSONObject json = new JSONObject();
        JSONArray elements = new JSONArray();
        long count = msg.getElementCount();
        for (int i = 0; (long) i < count; ++i) {
            JSONObject element = new JSONObject();
            TIMElem elem = msg.getElement(i);
            if (elem != null) {
                element.put("Type", elem.getType());
                if (elem.getType() == TIMElemType.Text) {
                    TIMTextElem textElem = (TIMTextElem) elem;
                    element.put("Content", textElem.getText());
                } else if (elem.getType() == TIMElemType.Image) {
                    //图片元素
                    TIMImageElem e = (TIMImageElem) elem;
                    for (TIMImage image : e.getImageList()) {

                        //获取图片类型, 大小, 宽高
                        Log.d(TAG, "image type: " + image.getType() +
                                " image size " + image.getSize() +
                                " image height " + image.getHeight() +
                                " image width " + image.getWidth());
                        Log.d(TAG, "image getUrl: " + image.getUrl());
                        element.put("Content", "<img src=\"" + image.getUrl() + "\" bigImgUrl='" + image.getUrl() + "' onclick='imageClick(this)' />");
                    }
                } else if (elem.getType() == TIMElemType.Custom) {
                    TIMCustomElem customElem = (TIMCustomElem) elem;
                    element.put("desc", customElem.getDesc());
                    element.put("data", customElem.getData());
                    element.put("ext", customElem.getExt());
                }
                elements.put(element);
            }
        }

        json.put("ConverstaionType", msg.getConversation().getType());
        json.put("ConversationId", msg.getConversation().getPeer());
        json.put("MsgId", msg.getMsgId());
        json.put("MsgSeq", msg.getSeq());
        json.put("Rand", msg.getRand());
        json.put("time", msg.timestamp());
        json.put("isSelf", msg.isSelf());
        json.put("Status", msg.status());
        json.put("Sender", msg.getSender());
        json.put("elements", elements);
        return json;
    }

    //    buildTIMMessageJSONObject
    private JSONObject TIMConversation2JSONObject(TIMConversation session) throws JSONException {
        TIMConversationExt ext = new TIMConversationExt(session);
        TIMMessage msg = ext.getLastMsg();
        if ("".equals(session.getPeer()) || session.getPeer() == null) {
            return null;
        }
        if (msg == null) {
            return null;
        }
        JSONObject json = TIMMessage2JSONObject(msg);
        json.put("unRead", ext.getUnreadMessageNum());
        return json;
    }

    public static Context getAppContext() {
        return mContext;
    }
}
