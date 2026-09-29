# 微信 Android 插件接入

1. 在微信开放平台创建移动应用，取得 `WX_APPID`，配置包名与 SHA-1 签名。
2. 将微信 OpenSDK Android AAR 和 `WXEntryActivity` 放入 Godot Android 插件工程，导出 `WeChatSDK` singleton。
3. singleton 提供 `authorize()` 与 `auth_result(code, error)` 信号；Godot `WeChat.gd` 会优先调用该接口。
4. 服务器设置 `WX_APPID`、`WX_SECRET`，仅服务端换取 openid；客户端不保存 secret。
5. 配置 Android 签名、微信回调 scheme，并在真机验证取消、超时、成功三条路径。
6. 未安装插件时保留开发 Mock：`mock_<device-id>`，界面显示「开发模式」。
