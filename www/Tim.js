var exec = require('cordova/exec');


module.exports = {
    /**
     * 初始化腾讯云通信
     *
     * @example
     * <code>
     * Tim.init({
     *     sdkAppId: 0, //从云通信控制台创建应用获取到的sdkappid
     *     accountType: 0, //用户类型,自建还是依托于腾讯
     *     enableLogPrint: true // 是否开启打印日志,默认为false
     * }, function () {
     *     alert("Success");
     * }, function (reason) {
     *     alert("Failed: " + reason);
     * });
     * </code>
     */
    init: function (message, onSuccess, onError) {
        exec(onSuccess, onError, "Tim", "init", [message]);
    },
    /**
     * 登录
     *
     * @example
     * <code>
     * Tim.login({
     *     identifier: 0, // 用户名
     *     userSig: 0 // 用户登录凭证
     * }, function () {
     *     alert("Success");
     * }, function (reason) {
     *     alert("Failed: " + reason);
     * });
     * </code>
     */
    login: function (message, onSuccess, onError) {
        exec(onSuccess, onError, "Tim", "login", [message]);
    },
    /**
     * 登出
     *
     * @example
     * <code>
     * Tim.logout({}, function () {
     *     alert("Success");
     * }, function (reason) {
     *     alert("Failed: " + reason);
     * });
     * </code>
     */
    logout: function (message, onSuccess, onError) {
        exec(onSuccess, onError, "Tim", "logout", [message]);
    },
    /**
     * 发送消息
     *
     * @example
     * <code>
     * Tim.send({
     *     msg: 'a bew test msg' // 文本内容
     * }, function (msg) {
     *     alert("msg: " + msg);
     * }, function (reason) {
     *     alert("Failed: " + reason);
     * });
     * </code>
     */
    send: function (message, onSuccess, onError) {
        exec(onSuccess, onError, "Tim", "send", [message]);
    },
    /**
     * 接收消息
     *
     * @example
     * <code>
     * Tim.addmessagelistener({}, function (msgs) {
     *     alert("msgs: " + msgs);
     * }, function (reason) {
     *     alert("Failed: " + reason);
     * });
     * </code>
     */
    addmessagelistener: function (message, onSuccess, onError) {
        exec(onSuccess, onError, "Tim", "addmessagelistener", [message]);
    }
};
