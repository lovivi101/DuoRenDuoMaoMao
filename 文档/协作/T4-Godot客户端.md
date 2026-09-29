# 任务 T4：《熄灯》Godot 4 客户端（初版 App，横屏）

你是客户端工程师。工作目录：`E:\Game_Work\AI 游戏\多人躲猫猫\客户端\Godot_Client`（当前为空，从零搭建）。
Godot：`E:\Game_Work\Godot\Godot_v4.7.2-stable_win64_console.exe`（命令行/无头用这个）。语言 **GDScript**（静态类型标注）。
必读：
- `文档/《熄灯》策划案.md`（尤其 3、11 章）
- `文档/01-策划分析与素材需求.md`（MVP 范围、19 页清单）
- `文档/02-网络协议.md`（**契约，严格遵守**；实现以服务器源码 `服务器端/TS_Server/src` 为准，发现冲突以服务器为准并记录）
- UI 设计：`素材/UI流程图/单页界面/*.png`（每个界面照此还原布局）、`素材/UI流程图/流程总览/*.png`（跳转关系）
- 资产：`素材/UI拆分资产/00-共享资产/**`、`ASSET_MANIFEST.md`、`NINE_PATCH.json`

## 工程约定

- 基准分辨率 **1334×750 横屏**，`display/window/stretch/mode=canvas_items`、`aspect=expand`，`handheld/orientation=landscape`；UI 用锚点适配 16:9～20:9 并避开刘海安全区（`DisplayServer.get_display_safe_area()`）。
- 资产：写 `tools/sync_assets.ps1`，把 `素材/UI拆分资产/00-共享资产` 复制到 `assets/ui/`（保留子目录，目录名去掉数字前缀改英文：`bg, logo, panel, button, icon, avatar, role, decor, item, event, hud, sprite, mapcard`）。像素精灵与 tile 的导入设置用 Nearest 过滤。
- 字体：下载开源可商用中文字体放 `assets/fonts/`（标题用像素风如 Fusion Pixel / Ark Pixel，正文用 Noto Sans SC 或思源黑体子集），附带 LICENSE；做一个全局 `Theme`（`assets/theme/main_theme.tres`），按钮/面板用 `NinePatchRect`/`StyleBoxTexture` + `NINE_PATCH.json` 的边距。
- 目录：`autoload/`（`Config`、`Api`、`Net`、`Session`、`Router`、`Audio`、`WeChat`）、`scenes/ui/`、`scenes/game/`、`scenes/common/`（通用按钮、弹窗、Toast、加载遮罩）、`scripts/`、`tests/`。

## 界面（与 19 页效果图一一对应）

01 启动闪屏（Logo 动画 → 版本检查 `GET /api/notice` → 公告弹窗 → 有 token 自动 `GET /api/me` 直达主界面）；02 登录；03 手机验证码登录（60s 倒计时，开发模式把 `devCode` 以 Toast 提示）；04 账号密码登录（登录/注册 Tab，密码显隐）；05 创建角色（随机昵称、8 色形象）；06 主界面；07 快速匹配中（60s 后出现「AI 补位开局」）；08 创建房间；09 加入房间（6 位码 + 数字键盘 + 粘贴）；10 房间等待（复制房间码、邀请好友、房主加 AI/踢人/开始、准备）；11 地图投票；12 角色分配；13/14/15/16 局内（见下）；17 结算（再来一局/返回主界面/分享=复制文本到剪贴板）；18 好友与邀请；19 设置（音量、静音视觉增强、色弱模式、震动、画质、左手模式、退出登录，保存到 `user://settings.cfg`）。衣柜/商店/战绩/任务按钮点击弹「敬请期待」。

**登录**：
- 微信快捷登录：`autoload/WeChat.gd` 抽象层——若 `Engine.has_singleton("WeChatSDK")`（Android 插件，后续接入）则调用原生授权拿 code；否则（PC/编辑器/未接入）走开发 mock：code=`mock_` + 设备 ID，并在界面角标提示「开发模式」。在 `docs/wechat-android-plugin.md` 写清后续接入微信 OpenSDK Android 插件的步骤与需要的 AppID/签名。
- 用户协议未勾选时点击任何登录按钮 → 抖动勾选框 + Toast「请先阅读并同意用户协议」。
- token 存 `user://session.cfg`；设置页可退出登录。

## 局内（scenes/game）

- 地图：用 `game.start.map` 解码 tiles，`TileMapLayer` 渲染（tile 资产来自 `sprite/tile-*`），墙体生成碰撞与 `LightOccluder2D`；`game.wall` 实时更新。
- 黑暗与视野：`CanvasModulate` 暗蓝紫 + 本地玩家 `PointLight2D`（阴影开启，半径=`you.visionRadius`），猎手额外扇形手电光（可用带扇形纹理的 PointLight2D）；最终 30s 红色暗角叠加 `hud-vignette-red`。
- 玩家：`sprite-hider` 按 `color` 着色、`sprite-hunter`（红眼发光）、`sprite-ghost` 半透明；伪装时显示 `prop-*` 贴图；被抓「抓到了！」定格 0.3s + 屏震。
- 网络：本地玩家客户端预测 + 服务器校正（平滑回拉）；其他玩家 100ms 插值缓冲；`game.input` 摇杆变化时发送且 ≥10Hz。
- 表现：波纹（白色扩散圆，猎手红）、脚印淡出、发电机进度、道具落点光柱、牢笼、标记。
- HUD（按策划案 11.2 与 13/14 效果图）：左上存活 x/y（点击展开名单）、顶部计时器（最后 30s 变红放大）、右上事件预警 + 小地图（只画墙体/发电机/落点）；左下虚拟摇杆（内圈走外圈跑）+ 体力条；右下扇形：主按钮（藏者交互/猎手拍打，按住类操作有圆环读条）、技能（藏者伪装轮盘：按住弹出、滑动选择、松手确认；猎手手电开关）、道具 1/2（品质边框颜色 + 冷却遮罩）、情境指认按钮。幽灵：阵营选择弹窗（10s）+ 技能按钮 + 观战切换。屏幕边缘箭头指示屏外落点/大波纹。
- 桌面调试键位：WASD 移动、Shift 跑、Space 主按钮、Q 技能、1/2 道具、F 指认；左手模式镜像 HUD。
- 事件预警：顶部横幅（图标 + 名称 + 5s 倒计时），生效期间对应表现（停电=压暗光圈等）。

## 联调与自检（必须完成）

1. 起服务器：`cd 服务器端/TS_Server; npm install; npm run build; npm start`（后台）。若需要缩短对局用于测试，可在服务器**只追加**开发用环境变量（如 `DEV_GAME_DURATION_SEC`、`DEV_HIDE_SEC`），默认值不变，并写进服务器 README。
2. 无头导入：`Godot_v4.7.2-stable_win64_console.exe --headless --path . --import` 无 error。
3. 写 `tests/smoke_flow.gd`（`--headless --script` 运行），不点 UI、直接驱动 autoload：游客登录 → 设置资料 → 建房 → 加 AI 到 8 人 → 开始 → 收到 `game.start`/`game.snap`/`game.result` → 再来一局回到 waiting → 退出码 0。
4. 写 `tests/scene_load.gd`：逐个实例化 19 个界面场景与局内场景各运行若干帧，无脚本错误。
5. 用非无头模式启动游戏截图（`--write-movie` 或在游戏内 `get_viewport().get_texture().get_image().save_png()` 的调试命令行参数 `--shot=<scene>`），把 02 登录、06 主界面、10 房间等待、13 藏者 HUD、14 猎手 HUD、17 结算 的实际运行截图保存到 `客户端/Godot_Client/docs/screenshots/`，并与效果图对比，布局明显偏差要修。
6. 配 `export_presets.cfg`：Android（横屏、arm64）与 Windows Desktop 预设（不需要真正导出 APK）。
7. 写 `README.md`：运行、键位、服务器地址配置（`Config.gd` + 设置页隐藏调试入口可改服务器地址）、目录说明、已知问题。

不要修改 `素材/` 与 `文档/`（除追加 `文档/02-网络协议.md` 的「客户端实现备注」），服务器只允许追加开发用环境变量。

## 补充说明（统筹，第 1 轮执行）

- 用户目标：**最终效果必须可以玩**。优先级：可玩的完整流程（登录 → 主界面 → 建房/匹配 → 房间 → 投票 → 分配 → 对局 → 结算 → 再来一局）> 界面还原度 > 细节动效。
- **直接根据 `素材/UI流程图/单页界面/*.png` 参考图编码**，布局、配色、按钮位置照图还原；视觉风格以 `素材/参考/风格板.png`、`素材/参考/UI元素总图.png` 为准。
- 拆分资产（T3）正在另一个 Codex 里并行生成，`素材/UI拆分资产/00-共享资产` 可能还不全。做法：`tools/sync_assets.ps1` 照常写；代码里按需求文档第 6 节的**文件名**引用资产，写一个 `UiAssets.gd` 加载器——文件不存在时回退为 `StyleBoxFlat` 程序化样式（深蓝紫面板 + 暖黄描边 + 圆角），保证现在就能运行，资产到位后自动替换，无需改代码。
- 服务器（T2）也在另一个 Codex 里收尾，**不要修改 `服务器端/`**（包括不要加环境变量，这轮先不加）。联调时若服务器还不能构建，就先完成客户端和 `tests/scene_load.gd`，在 README 已知问题里写明，`smoke_flow.gd` 留到下一轮。
- 局内光照：黑暗要真的黑（`CanvasModulate` 接近 #0c0a1a），只有光圈和手电照亮区域可见，这是玩法核心。

## 续跑说明

上一轮执行被中途切换模型打断。开始前先检查磁盘上已有的产出（文件、脚本、代码），在其基础上继续，不要推倒重来；已合格的部分直接保留。

