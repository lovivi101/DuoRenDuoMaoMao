# T8a 地图俯瞰图生成记录

- 生成方式：两份 T8 ASCII 用 Pillow 绘制布局参考底稿；正式成图由内置 `image_gen` 生成，只用 Pillow 缩放到目标尺寸。风格参考 `map-old-dorm-overview.png`。
- 底稿：医院 72×34，商场 72×32，每格 10px。E 为传送点，G 为暖黄闪电发电机。

## `map-night-hospital-overview.png`

提示词：`Use case: sketch-to-render. Image 1 is the EXACT hospital floor plan and object placement; Image 2 is style reference ONLY (old dorm overview). Transform into polished opaque 2D pixel-art night hospital. Keep exact 72 columns x 34 rows, perimeter, all wall and cracked lines, doors, central corridor, middle nurse station and X-ray room, west/east ward partitions. Keep each marker in its 10px cell. f hospital beds, s counters, p props, E lift/stair portals, G warm yellow lightning bolts, C cage, h/H spawn glows. Cold white-green fluorescent lighting, stainless steel, mint curtains, dark navy outlines. 720:340; full bleed, no labels.`

检查：720×340 RGB；与底稿作 50% 叠图，主墙线、走廊和区域划分相符。

## `map-night-mall-overview.png`

提示词：`Use case: sketch-to-render. Repaint this exact pixel floor-plan while preserving geometry literally. TWO SEPARATE FLOOR PLANS SIDE BY SIDE: left columns 0-34 first floor with pale polished tile and own dark central atrium; right columns 37-71 second floor with purple-red carpet and own second dark atrium. Keep two uninterrupted dark gutter columns between floors. Keep walls, cracked segments, doors, twin atria, and object markers in the same positions. Refine textures: pink-blue shop neon, glass railings, clothing racks, curtains, yellow lightning generator icons. Orthographic pixel-art game map, 720:320, opaque, no labels.`

检查：720×320 RGB；与底稿作 50% 叠图，左右楼层、双天井、中间空列、主墙线与区域划分相符。首稿误合并双楼层，第二稿恢复双楼层；交付的是对第二稿的 E 门图标定点修图。

定点修图提示词：`Use case: precise-object-edit. Keep the completed two-floor map identical in walls, doors, two atriums, floor colors, lighting, furniture, generator lightning icons and 720:320 aspect ratio. Change only six blue glowing E objects to recognizable tiny silver elevator/escalator/stair portals with blue-white arrow indicators. Target centers: (25,105), (75,155), (275,155), (445,155), (645,155), (695,305). Keep both maps and central dark gutter. No labels or new walls.`

模型局部装饰与 ASCII 中单格道具的精确数量可能有差异；布局核对以墙线、门、区域、天井及 E/G 位置为主。
