# 熄灯（DuoRenDuoMaoMao）

2D 俯视角多人非对称躲猫猫手游：1～2 名猎手在熄灯的宿舍楼里追捕 6～10 名藏者，黑暗视野、声音波纹、伪装、道具与周期事件。横屏 App，登录支持微信快捷登录、手机短信、账号密码与游客。

## 目录

| 路径 | 内容 |
| --- | --- |
| `文档/《熄灯》策划案.md` | 策划案 |
| `文档/01-策划分析与素材需求.md` | 策划分析、MVP 范围、19 页 UI 清单、资产需求 |
| `文档/02-网络协议.md` | 客户端 ↔ 服务器协议（HTTP + WebSocket） |
| `文档/协作/` | 各阶段任务书与审查意见 |
| `素材/参考/` | 风格板、UI 元素总图、主界面参考 |
| `素材/UI流程图/` | 19 张单页效果图 + 6 张流程总览（1334×750 横屏） |
| `素材/UI拆分资产/` | 透明 PNG 生产资产（`00-共享资产` 为母版，各页目录为副本） |
| `服务器端/TS_Server/` | Node 22 + TypeScript 服务端（服务端权威 20Hz 对局、AI 机器人） |
| `客户端/Godot_Client/` | Godot 4.7 客户端（GDScript） |

## 快速运行

```powershell
# 服务器
cd 服务器端/TS_Server
npm install
npm run build
npm start            # http://127.0.0.1:8787，/ws

# 客户端（另开终端）
cd 客户端/Godot_Client
Godot_v4.7.2-stable_win64.exe --path .
```

开发时可缩短对局：启动服务器前设置 `DEV_HUNT_SEC=90`、`DEV_HIDE_SEC=5`、`MATCH_MIN_PLAYERS=1`，建房后加 AI 即可单人完整试玩。微信与短信在未配置服务商时为 mock 模式（见服务器 README）。

## 验证

- 服务器：`npm test`（34 个测试）、`npm run sim`（无头模拟一局）、`npm run sim:batch -- --n 30`（平衡统计，默认 10 分钟局藏者胜率约 50%）。
- 客户端：`tests/scene_load.gd`（19 个界面 + 局内场景加载）、`tests/smoke_flow.gd`（端到端协议流程）、`-- --autoplay`（连真服务器打完整一局并截图到 `docs/screenshots/`）。
