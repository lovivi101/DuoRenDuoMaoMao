# 熄灯 TS Server

Node 22 + TypeScript strict + ESM 的服务端初版，HTTP 默认 `8787`，WebSocket 为 `/ws`。数据默认写入 `data/xideng.db`，底层使用 `node:sqlite`（Node 22.20 可用时）并保留内存 Store 接口。

## 启动

`package-lock.json` 使用官方源 `registry.npmjs.org`。国内安装慢时在本机配置镜像即可（npm 会自动把锁文件里的官方源替换为所配源），不要把镜像地址提交进锁文件：`npm config set registry https://registry.npmmirror.com`。

```powershell
npm install
Copy-Item .env.example .env
npm run dev       # tsx watch
npm run build
npm start
npm test
npm run sim
npm run sim:batch -- --n 30
npm run map:ascii
npm run bots -- --room 123456 --n 3
```

`JWT_SECRET`、`PORT`、`MATCH_MIN_PLAYERS`、`MAP_DURATION_SEC` 可在 `.env` 调整。生产环境（`NODE_ENV=production`）必须设置自己的 `JWT_SECRET`（≥32 字符），未设置或沿用开发默认值 / `.env.example` 示例值时服务器拒绝启动。开发模式下微信接受 `mock_` 开头的 code；短信验证码会打印日志并在响应中返回 `devCode`。生产环境请配置微信服务商与短信服务商并关闭开发回显。

`DEV_HUNT_SEC`、`DEV_HIDE_SEC`、`DEV_ASSIGN_SEC`、`DEV_RESULT_SEC`、`DEV_VOTE_SEC` 是可选的开发时长覆盖值，单位秒；未设置时使用原有时长，生产环境忽略。值须大于 0 且不超过 3600。例如联调可设 `DEV_HUNT_SEC=90`、`DEV_HIDE_SEC=5`。`MATCH_MIN_PLAYERS` 保持原有含义。

`sim:batch` 默认用种子 1～30 跑 30 局，也可传 `--n`、`--seed`，统计藏者胜率、曾被抓的独立藏者比例（获救者也计入）、至少修好一台发电机的局数和平均时长（不含结算）。

### 平衡结果（全 AI，8 人局 1 猎手 7 藏者）

| 追捕时长 | 藏者胜率（种子 1～30 / 101～130） | 说明 |
| --- | --- | --- |
| 600 秒（房间默认） | 53.3% / 46.7% | 落在策划目标 45%～55% |
| 480 秒 | 66.7% / 56.7% | 略偏藏者 |
| 300 秒 | 90.0% / 70.0% | 房主可选的短局，时间短天然利于藏者 |

调参方式：AI 行为参数集中在 `src/game/config.ts` 的 `AI`，开发时可用 `AI_TUNE='{"rescueChance":0.8}'` 临时覆盖后跑 `sim:batch`（生产环境忽略）。主要 AI 调整：伪装中的藏者不再因猎手靠近而慌张现身；逃出猎手视线后就近伪装；决定救援后坚持到底；发电机全修后潜伏更久。该统计只衡量 AI 对战样本，真人对局仍需实测。

### 与策划案的差异

- **发电机缩时按比例**：每修好 1 台，剩余时间减少「追捕时长 × 10%」。默认 600 秒局正好是策划的 60 秒；300/480 秒局按比例减 30/48 秒，避免短局修完 3 台后追捕期被砍到只剩 2 分钟。其他第 9 节数值未改动。
- 房间默认时长为 600 秒（策划「默认 10 分钟」）。
旧宿舍楼现在有 64 个伪装点，覆盖协议中的 8 种物品。地图 `legend` 末尾追加 `6: furniture`（阻挡移动，视线可通过）和 `7: shelf`（阻挡移动及视线）；原有 0～5 保持不变。室内墙有约 40% 可破坏。`game.phase` 在发电机修好、追捕截止时间提前（默认 60 秒）时也会以相同 `phase` 和新的 `endsAt` 广播；这是计时更新，`npm run sim` 将其记为 `timer updated`。

匹配、建房、准备、踢人、加 AI、开始、再来一局均通过协议定义的 WebSocket 消息完成。单人联调可以把 `MATCH_MIN_PLAYERS=1`，房主开始时再按 `aiFill` 补足机器人。
