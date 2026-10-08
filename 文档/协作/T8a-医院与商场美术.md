# 任务 T8a：深夜医院 + 夜间商场 局内美术（地块 / 家具 / 伪装物 / 机制物件 / 俯瞰图）

工作根目录：`E:\Game_Work\AI 游戏\多人躲猫猫`。只新增下表文件，**不要改动或删除任何已有资产、代码**。

## 背景

服务器已实现两张新地图，布局见 `文档/协作/T8-night_hospital-ascii.txt`、`文档/协作/T8-night_mall-ascii.txt`（字符说明在文件末尾，含区域与地面类型）。客户端按地图主题加载地块，你只负责出图。

## 硬性要求

1. **必须用 image_gen（gpt-image-2）生成**，禁止 PIL / 代码画图形；PIL 只做抠底、裁切、缩放、检查。俯瞰图允许先用 PIL 把 ascii 画成布局底稿作参考图，**成图必须是 image_gen 输出**。
2. 风格与旧宿舍楼现有资产一致（`素材/UI拆分资产/00-共享资产/12-局内精灵/` 的 `tile-*`、`prop-*`、`furn-*`，风格板 `素材/参考/风格板-v1.png`）：俯视略带 3/4 视角像素风、深色描边、夜间色调。
   - 医院：惨白偏绿的冷光，瓷砖、不锈钢、浅绿帘子。
   - 商场：店铺招牌的粉蓝霓虹，抛光地砖、玻璃、地毯。
3. 物件图：一次 image_gen 画一个物件，品红底或透明底，抠底后按比例居中放入目标画布（四周留 2px）；无品红残留（R>200,G<60,B>200 = 0），四角 8×8 透明。
4. **地块（tile-*）是不透明、可无缝平铺的 64×64**：左右、上下边缘要能拼接（自检：把同一张拼成 3×3，接缝处相邻像素平均色差 < 12）。墙块要一眼能和地面区分（更亮、有砖缝或墙裙），裂墙在墙块基础上加明显裂纹。
5. 输出到 `素材/UI拆分资产/00-共享资产/12-局内精灵/`（俯瞰图到 `13-地图卡/`），并在各目录 `_T8a-生成记录.md` 记录提示词。

## 文件清单

### 地块（64×64 不透明、可平铺）
| 文件 | 内容 |
| --- | --- |
| `tile-floor-corridor.png` | 医院长走廊：浅灰绿塑胶地板，中间一条导向色带 |
| `tile-floor-clinic.png` | 护士站 / X 光室：白色大理石纹地砖 |
| `tile-floor-ward.png` | 病房：浅青色小方格地砖 |
| `tile-wall-solid-hospital.png` | 医院墙：白墙 + 浅绿墙裙 |
| `tile-wall-cracked-hospital.png` | 同上加明显裂纹 |
| `tile-door-hospital.png` | 医院门（俯视，浅绿金属门） |
| `tile-floor-mall.png` | 商场一层：浅色抛光地砖，有反光 |
| `tile-floor-carpet.png` | 商场二层：深紫红花纹地毯 |
| `tile-wall-solid-mall.png` | 商场墙：浅灰墙面 + 霓虹灯条 |
| `tile-wall-cracked-mall.png` | 同上加裂纹 |
| `tile-door-mall.png` | 店铺玻璃自动门（俯视） |
| `tile-curtain.png` | 试衣间帘子（深红丝绒帘，俯视看是一道帘） |
| `tile-atrium.png` | 天井：边缘玻璃护栏 + 下方深色楼层落差（可平铺） |

### 家具（按占格尺寸，透明底；客户端覆盖在阻挡格上）
| 文件 | 尺寸 | 内容 |
| --- | --- | --- |
| `furn-hospital-bed.png` | 64×128（1×2 格竖放） | 病床：白色床单、枕头在上、金属床栏 |
| `furn-clothes-rack.png` | 192×64（3×1 格横放） | 服装店挂衣架，挂一排彩色衣服 |

### 伪装物（128×128 透明，与 `prop-chair.png` 同规格）
`prop-iv-stand.png` 输液架、`prop-wheelchair.png` 轮椅、`prop-folding-screen.png` 医用屏风、`prop-gurney.png` 病床推车、`prop-medicine-cabinet.png` 药品柜、`prop-mannequin.png` 人体模特（白色塑料、穿一件外套）、`prop-shopping-cart.png` 购物车、`prop-vending-machine.png` 自动售货机、`prop-promo-stand.png` 促销立牌

### 机制物件（128×128 透明）
| 文件 | 内容 |
| --- | --- |
| `sprite-portal-elevator.png` | 电梯：俯视的一对金属门 + 上下箭头指示灯 |
| `sprite-portal-escalator.png` | 扶梯口：俯视扶梯踏板与扶手 |
| `sprite-portal-stairs.png` | 消防楼梯口：绿色安全出口标识 + 台阶 |
| `sprite-ecg-monitor.png` | 心电监护仪：绿色心电波形屏幕的小推车 |
| `sprite-broadcast-mic.png` | 广播室话筒台（带红色「ON AIR」灯） |

### 俯瞰图（不透明，布局必须与 ascii 一致）
| 文件 | 尺寸 |
| --- | --- |
| `13-地图卡/map-night-hospital-overview.png` | 720×340（每格 10px） |
| `13-地图卡/map-night-mall-overview.png` | 720×320（左半一层、右半二层，中间两列是楼层间隔） |

俯瞰图画风参考已通过的 `13-地图卡/map-old-dorm-overview.png`；电梯 / 扶梯 / 楼梯位置（ascii 里的 E）要画出来，发电机（G）用暖黄闪电小图标标出。自检：与布局底稿 50% 叠图，墙体走向与区域划分对得上。

## 交付

最终回复列出全部 31 个文件、尺寸与自检数字（平铺色差、四角透明、品红残留）。

## 续做说明

上一次执行在出图中途中断。`C:\Temp\T8a-raw\` 里已有部分 image_gen 原图（按目标文件名命名）：先逐张检查，合格的直接抠底、缩放、自检后输出，不合格或缺失的再重新生成。
