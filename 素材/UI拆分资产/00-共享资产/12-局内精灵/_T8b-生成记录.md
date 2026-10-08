# T8b 局内精灵生成记录

生成方式：所有原图均由 image_gen（gpt-image-2）生成。`C:\Temp\T8b\raw\` 中断前遗留的 23 张原图没有保存逐字提示词；下表“恢复图规格提示词”是依据任务书、原图和输出用途重建的提示词，不冒充原始逐字日志。本次补生的图记录了实际提示词。PIL 只用于透明背景抠底、裁切、缩放和检查；没有用代码绘制成品。

共通规格：俯视略带 3/4 视角的 Q 版夜间像素风，深色描边；游轮为深海蓝、月光银和柚木，山庄为冷白雪光与暖橙火光。地块不透明、正方形、满幅纹理；家具和物件为单个主体、居中留白、透明底。目标尺寸与文件名见下表。

| 文件 | 提示词或恢复图规格提示词 |
| --- | --- |
| `tile-floor-deck.png` | 恢复图规格：月光下的浅色柚木甲板，横向木板纹，64×64 无缝地面。此文件在本次开始前已存在，本次未改动。 |
| `tile-floor-cabin.png` | 本次实际提示词：Single repeatable top-down 2D pixel-game floor texture for a 64x64 ship-cabin tile. ONLY a flat overhead view of midnight-blue woven carpet, subtle low-contrast navy geometric nautical pattern, sparse silver flecks, night palette. Fill entire square edge-to-edge with uniform texture, no walls, no corridor perspective, no doors, no border, no vignette, no lighting gradient, no isolated objects. Designed to crop a seamless 64x64 square; dark pixel-art outlines and clean pixel clusters. |
| `tile-wall-solid-cruise.png` | 恢复图规格：白银色铆钉船体舱壁，中间蓝色圆形舷窗，深蓝描边，可重复墙块。 |
| `tile-wall-cracked-cruise.png` | 恢复图规格：白银色铆钉舱壁与蓝色圆形舷窗，墙面多条清晰裂纹，夜间像素风。 |
| `tile-door-cruise.png` | 恢复图规格：白色圆角金属舱门、蓝色圆形视窗、船舱木板背景，俯视像素风。 |
| `tile-floor-snow.png` | 本次实际提示词：Single 64x64 repeatable top-down pixel-art GAME FLOOR TEXTURE. Cold blue-white freshly fallen snow with very sparse fine icy blue speckles. Make all four outer edges visually matching for a mathematically seamless repeat: same near-white blue tone and fine texture at every edge. Almost flat, gently granular, no wind ridges, no footprints, no trees, no objects, no shadows, no vignette, no border, no perspective. Fill square edge to edge. Crisp readable pixel clusters, nighttime cool white snow. |
| `tile-floor-lodge.png` | 恢复图规格：山庄室内暖橙色宽木板，横向拼缝、木纹、暖火光，俯视像素地面。 |
| `tile-floor-barn.png` | 本次实际提示词：Single 64x64 repeatable top-down pixel-art GAME FLOOR TEXTURE. Rustic old wood floorboards and only a few tiny straw strands in a snowy mountain barn. Make all four outer edges visually matching for a mathematically seamless repeat: wood grain and plank seams exit exactly the same height on left and right; color and grain at top match bottom. Uniform color and illumination from edge to edge. Simple low-contrast evenly spaced horizontal worn boards in dark warm walnut, sparse straw strictly away from outer border, no perspective, no furniture, no vignette, no border. Fill square edge to edge. Crisp chunky pixel clusters and deep outline style. |
| `tile-wall-solid-lodge.png` | 恢复图规格：横向堆叠原木墙，圆木纹理和深色缝隙，暖棕色、像素风。 |
| `tile-wall-cracked-lodge.png` | 恢复图规格：横向圆木墙、深色缝隙，中部明显不规则裂纹，暖棕色像素风。 |
| `tile-door-lodge.png` | 恢复图规格：厚重木门、黑色铁箍和门环，山庄夜间像素风。 |
| `furn-lifeboat.png` | 恢复图规格：单艘横向橙白色救生艇，深蓝帆布覆盖，俯视略 3/4，透明底。 |
| `furn-pine-tree.png` | 恢复图规格：单棵积雪松树，俯视树冠为主，蓝白雪光、深蓝描边，透明底。 |
| `furn-fireplace.png` | 恢复图规格：单个横向石砌壁炉，旺盛炉火与暖橙光，深色描边，透明底。 |
| `furn-kitchen-counter.png` | 恢复图规格：单个横向木质厨房台面，锅碗、案板与食材，暖棕色透明底。 |
| `prop-deck-chair.png` | 恢复图规格：单张木制帆布躺椅，俯视略 3/4，深色描边，透明底。 |
| `prop-life-ring.png` | 恢复图规格：单个橙白救生圈，外绕绳索，俯视像素风，透明底。 |
| `prop-rope-coil.png` | 恢复图规格：单堆盘好的粗麻绳，俯视像素风，透明底。 |
| `prop-barrel.png` | 恢复图规格：单只深色木质酒桶，蓝黑铁箍，俯视略 3/4，透明底。 |
| `prop-suitcase.png` | 恢复图规格：单只棕色皮革行李箱，金属包角，俯视略 3/4，透明底。 |
| `prop-snowman.png` | 恢复图规格：单个两层积雪雪人，蓝围巾、胡萝卜鼻，像素风，品红底供抠底。 |
| `prop-firewood.png` | 恢复图规格：单堆捆好的劈柴，暖棕色木头与深蓝绑带，透明底。 |
| `prop-deer-head.png` | 恢复图规格：单件鹿头标本放在地面木底座上，角清晰，透明底。 |
| `prop-ski-rack.png` | 恢复图规格：单个木质滑雪板架，彩色成对滑雪板与杖，透明底。 |
| `prop-blanket.png` | 本次实际提示词：Draw ONE neatly folded thick plaid wool blanket resting alone, visible top and side folds, burgundy, cream, muted forest green tartan grid, strong dark navy 2px-style pixel outline, chunky readable pixel clusters, cool nighttime shadow and a little warm lodge firelight. Isolated object centered with generous blank margin, flat vivid magenta #FF00FF background, no cast shadow outside the object, no labels, no other objects. Match cozy yet moody game sprite style. |
| `sprite-portal-hatch.png` | 本次实际提示词：Draw ONE opened circular ship hatch seen from above with slight three-quarter pixel-game perspective: silver white riveted metal circular hinged lid folded open to one side, dark round opening, clearly visible short brass ladder descending inside. Deep sea blue shadows, moonlight silver highlights, crisp dark navy pixel outline and chunky readable pixel clusters. Object centered with blank margin on flat vivid magenta #FF00FF background; no deck, no words, no other objects. |

处理：地块从生成图按边缘匹配选方形区域，再缩到 64×64；透明图以 alpha 或品红色抠底，裁掉外围空白后等比缩放并居中，四周至少 2px。地块自检采用 3×3 重复平铺时相邻边 RGB 每通道绝对差的平均值，水平与垂直边分别统计。完整数值见交付回复。
