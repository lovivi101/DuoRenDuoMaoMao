# 任务 T8b：午夜游轮 + 雪山山庄 局内美术（地块 / 家具 / 伪装物 / 机制物件 / 俯瞰图）

工作根目录：`E:\Game_Work\AI 游戏\多人躲猫猫`。只新增下表文件，**不要改动或删除任何已有资产、代码**。

## 背景

服务器已实现两张新地图，布局见 `文档/协作/T8-midnight_cruise-ascii.txt`、`文档/协作/T8-snow_lodge-ascii.txt`（字符说明在文件末尾，含区域与地面类型）。客户端按地图主题加载地块，你只负责出图。

## 硬性要求

1. **必须用 image_gen（gpt-image-2）生成**，禁止 PIL / 代码画图形；PIL 只做抠底、裁切、缩放、检查。俯瞰图允许先用 PIL 把 ascii 画成布局底稿作参考图，**成图必须是 image_gen 输出**。
2. 风格与旧宿舍楼现有资产一致（`素材/UI拆分资产/00-共享资产/12-局内精灵/` 的 `tile-*`、`prop-*`、`furn-*`，风格板 `素材/参考/风格板-v1.png`）：俯视略带 3/4 视角像素风、深色描边、夜间色调。
   - 游轮：深海蓝 + 月光银；甲板是木板，船舱是深色走廊。
   - 山庄：室外冷白雪光，室内壁炉暖橙；冷暖对比强。
3. 物件图：一次 image_gen 画一个物件，品红底或透明底，抠底后按比例居中放入目标画布（四周留 2px）；无品红残留（R>200,G<60,B>200 = 0），四角 8×8 透明。
4. **地块（tile-*）是不透明、可无缝平铺的 64×64**（自检：同一张拼成 3×3，接缝相邻像素平均色差 < 12）。墙块要一眼能和地面区分，裂墙在墙块基础上加明显裂纹。
5. 输出到 `素材/UI拆分资产/00-共享资产/12-局内精灵/`（俯瞰图到 `13-地图卡/`），并在各目录 `_T8b-生成记录.md` 记录提示词。

## 文件清单

### 地块（64×64 不透明、可平铺）
| 文件 | 内容 |
| --- | --- |
| `tile-floor-deck.png` | 甲板：月光下的浅色柚木板 |
| `tile-floor-cabin.png` | 船舱：深蓝地毯走廊 |
| `tile-wall-solid-cruise.png` | 船体墙：白色金属舱壁 + 铆钉 + 圆形舷窗感 |
| `tile-wall-cracked-cruise.png` | 同上加裂纹 |
| `tile-door-cruise.png` | 舱门（圆角金属门） |
| `tile-floor-snow.png` | 雪地：蓝白雪面，细微颗粒 |
| `tile-floor-lodge.png` | 木屋：暖色宽木地板 |
| `tile-floor-barn.png` | 柴房 / 马厩：粗糙旧木板 + 稻草 |
| `tile-wall-solid-lodge.png` | 原木墙（横向圆木） |
| `tile-wall-cracked-lodge.png` | 同上加裂纹 |
| `tile-door-lodge.png` | 木门 |

### 家具（按占格尺寸，透明底；客户端覆盖在阻挡格上）
| 文件 | 尺寸 | 内容 |
| --- | --- | --- |
| `furn-lifeboat.png` | 320×64（5×1 格横放） | 橙白救生艇，盖着帆布 |
| `furn-pine-tree.png` | 64×64（1×1） | 积雪松树（俯视，树冠为主） |
| `furn-fireplace.png` | 128×64（2×1） | 石砌壁炉，炉火橙光 |
| `furn-kitchen-counter.png` | 192×64（3×1） | 木质厨房台面，上面有锅碗 |

### 伪装物（128×128 透明，与 `prop-chair.png` 同规格）
游轮：`prop-deck-chair.png` 躺椅、`prop-life-ring.png` 救生圈、`prop-rope-coil.png` 绳索堆、`prop-barrel.png` 酒桶、`prop-suitcase.png` 行李箱
山庄：`prop-snowman.png` 雪人、`prop-firewood.png` 木柴堆、`prop-deer-head.png` 鹿头标本（放在地上的木底座上）、`prop-ski-rack.png` 滑雪板架、`prop-blanket.png` 叠好的格子毛毯

### 机制物件（128×128 透明）
| 文件 | 内容 |
| --- | --- |
| `sprite-portal-hatch.png` | 舱口楼梯：俯视圆形舱盖打开，下面是梯子 |

### 俯瞰图（不透明，布局必须与 ascii 一致）
| 文件 | 尺寸 |
| --- | --- |
| `13-地图卡/map-midnight-cruise-overview.png` | 700×340（每格 10px；上半甲板，下半船舱） |
| `13-地图卡/map-snow-lodge-overview.png` | 760×500（每格 10px；中间木屋，四周雪地与柴房 / 工具房 / 马厩） |

俯瞰图画风参考已通过的 `13-地图卡/map-old-dorm-overview.png`；舱口（E）要画出来，发电机（G）用暖黄闪电小图标标出。自检：与布局底稿 50% 叠图，墙体走向与区域划分对得上。

## 交付

最终回复列出全部 28 个文件、尺寸与自检数字（平铺色差、四角透明、品红残留）。

## 续做说明

上一次执行在出图中途中断。`C:\Temp\T8b\raw\` 里已有部分 image_gen 原图（按目标文件名命名）：先逐张检查，合格的直接抠底、缩放、自检后输出，不合格或缺失的再重新生成。
