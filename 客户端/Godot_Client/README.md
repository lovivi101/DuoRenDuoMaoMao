# 《熄灯》Godot 客户端

Godot 4.7.2、GDScript 静态类型、1334×750 横屏。主流程已接入协议：登录（微信 Mock/游客/短信/账号密码）→创建角色→大厅→匹配/建房/加入→等待→投票→身份→局内 HUD→结算。

## 运行

```powershell
cd "E:\Game_Work\AI 游戏\多人躲猫猫\客户端\Godot_Client"
& "E:\Game_Work\Godot\Godot_v4.7.2-stable_win64_console.exe" --editor --path .
```

服务器默认 `http://127.0.0.1:8787`，可用 `--server=http://host:8787` 覆盖；设置页保存的调试地址写入 `user://settings.cfg`。先在 `服务器端/TS_Server` 运行 `npm install; npm run build; npm start`。

## 自动试玩截图（调试）

先按开发时长启动服务器（例如 `DEV_HUNT_SEC=90`、`DEV_HIDE_SEC=5`），再运行：

```powershell
& "E:\Game_Work\Godot\Godot_v4.7.2-stable_win64_console.exe" --path . -- --autoplay
```

`scripts/AutoPlay.gd` 会以游客身份连真服务器，建房补满 AI 打完整一局，把主界面、房间、投票、身份、追捕期（3/12/25/45 秒）、被抓、结算截图存到 `docs/screenshots/live-*.png`，然后退出。

追加 `--autoplay-seek`（`-- --autoplay --autoplay-seek`）时，若身份是藏者会主动走向猎手出生点等待被抓，用于验证被抓 → 幽灵阵营选择（15 页停留 10 秒后回到局内）这段流程；日志里的 `AUTOPLAY caught +Ns page=` 逐秒记录当前页面。

## 键位与局内

桌面端使用 UI 按钮；对接摇杆后 `WASD` 移动、`Shift` 跑、`Space` 主按钮、`Q` 技能、`1/2` 道具、`F` 指认。客户端发送 `game.input`（变化时，≥10Hz）和协议约定的 `game.action`。黑暗通过 `CanvasModulate` 色值 #0c0a1a 和本地视野 UI 表现；服务器快照负责权威位置/可见玩家/事件。

## 目录

- `autoload/`：Config、Api、Net、Session、Router、Audio、WeChat。
- `scripts/`：程序化页面、资产回退样式和 HUD。
- `scenes/`：主场景；页面由 Router 运行时创建，保留 19 页编号映射。
- `assets/theme/`、`assets/fonts/`、`assets/ui/`：全局主题、Noto Sans SC/Fusion Pixel、共享资产同步目录。
- `tools/sync_assets.ps1`：将 `素材/UI拆分资产/00-共享资产` 同步到 `assets/ui`，数字前缀改为英文目录名。
- `tests/`：`scene_load.gd` 逐页实例化；`smoke_flow.gd` 无 UI 驱动主循环。

## 资产与字体

运行 `powershell -ExecutionPolicy Bypass -File tools/sync_assets.ps1`。资产未到位时自动使用深蓝紫面板、暖黄描边和圆角 StyleBoxFlat；资产到位后按文件名加载。Noto Sans SC 使用 SIL OFL；Fusion Pixel 使用 SIL OFL，许可证在 `assets/fonts/`。

## 已知问题

服务器当前 `vote.start` 按源码固定发送三张 `old_dorm`，客户端按服务器契约显示三个同图投票卡；`room.again` 在服务器结算 15 秒阶段只记录准备，服务器回到 waiting 后客户端收到 `room.state`。本轮没有修改服务器端。素材拆分目录可能仍在生成，运行时回退样式保证可玩；局内地图 TileMapLayer、完整 LightOccluder2D 与精灵资产接入将在素材到齐后替换当前 HUD/程序化地图表现。Android 微信插件仍需原生接入。
