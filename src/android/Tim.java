package cordova.plugin.bakaan.tim;

import android.app.Activity;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.Environment;
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
import com.tencent.imsdk.TIMGroupSystemElem;
import com.tencent.imsdk.TIMGroupSystemElemType;
import com.tencent.imsdk.TIMLogLevel;
import com.tencent.imsdk.TIMManager;
import com.tencent.imsdk.TIMMessage;
import com.tencent.imsdk.TIMMessageListener;
import com.tencent.imsdk.TIMSdkConfig;
import com.tencent.imsdk.TIMTextElem;
import com.tencent.imsdk.TIMValueCallBack;
import com.tencent.imsdk.ext.message.TIMConversationExt;
import com.tencent.imsdk.ext.message.TIMManagerExt;

import org.apache.cordova.CordovaWebView;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

import cn.jpush.android.api.JPushInterface;

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
    public static final String ACTION_LOADSESSION = "loadsession"; // 获取历史消息

    public static final String ERROR_INVALID_PARAMETERS = "参数格式错误";

    protected static int sdkAppId;

    private static Context mContext;
    private static Activity cordovaActivity;

    private Set<String> mTopList;
    private SharedPreferences mSessionPreferences;

    private int mUnreadTotal;

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);
        mContext = cordova.getActivity().getApplicationContext();

        JPushInterface.init(mContext);

        cordovaActivity = cordova.getActivity();
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
            case ACTION_LOADSESSION:
                this.loadsession(args, callbackContext);
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
            String msgcontent = params.getString("msg");
            //构造一条消息并添加一个文本内容
            TIMMessage msg = new TIMMessage();
            TIMTextElem elem = new TIMTextElem();
            elem.setText(msgcontent);
            msg.addElement(elem);

            String selto = params.getString("selto");//获取与用户/群组 的会话
            Log.i(TAG, "coversation start: selto = " + selto + ",   msg = " + msgcontent);
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
                        json = buildTIMMessageJSONObject(msg);
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

    private void loadsession(CordovaArgs args, CallbackContext callbackContext) {
        final JSONObject params;
        List<TIMConversation> TIMSessions = TIMManagerExt.getInstance().getConversationList();
        JSONArray infos = new JSONArray();
        try {
            for (int i = 0; i < TIMSessions.size(); i++) {
                TIMConversation conversation = TIMSessions.get(i);
                //将imsdk TIMConversation转换为UIKit SessionInfo
                SessionInfo sessionInfo = TIMConversation2SessionInfo(conversation);
                if (sessionInfo != null) {
                    mUnreadTotal = mUnreadTotal + sessionInfo.getUnRead();
                    infos.put(new JSONObject(sessionInfo.toString()));

                }
            }
            callbackContext.success(infos);
        } catch (JSONException e) {
            e.printStackTrace();
        }
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
                            msgjson.put(buildTIMMessageJSONObject(msgs.get(i)));
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
                callbackContext.success(json);
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

    private JSONObject buildTIMMessageJSONObject(TIMMessage msg) throws JSONException {
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

    /**
     * TIMConversation转换为SessionInfo
     *
     * @param session
     * @return
     */
    private SessionInfo TIMConversation2SessionInfo(TIMConversation session) {
        TIMConversationExt ext = new TIMConversationExt(session);
        TIMMessage message = ext.getLastMsg();
        if (message == null)
            return null;
        SessionInfo info = new SessionInfo();
        TIMConversationType type = session.getType();
        if (type == TIMConversationType.System) {
            if (message.getElementCount() > 0) {
                TIMElem ele = message.getElement(0);
                TIMElemType eleType = ele.getType();
                if (eleType == TIMElemType.GroupSystem) {
                    TIMGroupSystemElem groupSysEle = (TIMGroupSystemElem) ele;
                    // 群系统消息处理，不需要显示信息的
                    // groupSystMsgHandle(groupSysEle);
                }
            }
            return null;
        }

        boolean isGroup = type == TIMConversationType.Group;
        info.setLastMessageTime(message.timestamp() * 1000);
        MessageInfo msg = MessageInfoUtil.TIMMessage2MessageInfo(message, isGroup);
        info.setLastMessage(msg);
        if (isGroup)
            info.setTitle(session.getGroupName());
        else
            info.setTitle(session.getPeer());
        info.setPeer(session.getPeer());
        info.setGroup(session.getType() == TIMConversationType.Group);
        if (ext.getUnreadMessageNum() > 0)
            info.setUnRead((int) ext.getUnreadMessageNum());
        return info;
    }


    public static Context getAppContext() {
        return mContext;
    }
}
