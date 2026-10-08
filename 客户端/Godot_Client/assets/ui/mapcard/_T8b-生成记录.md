# T8b 俯瞰图生成记录

两张成图均由 image_gen（gpt-image-2）输出，随后仅等比缩放至目标像素。PIL 从 ASCII 绘制了仅供 image_gen 参考的布局底稿，未作为最终成图。第二张参考图是已通过的 `map-old-dorm-overview.png`，只用于风格。

## `map-midnight-cruise-overview.png`（700×340）

提示词：Create the final top-down 2D pixel-art gameplay overview of a midnight cruise ship at night. Image 1 is a strict 70-column by 34-row layout blueprint at 10 pixels per cell: preserve its exact canvas aspect ratio, every outer wall, every interior wall and doorway, all major rectangular room boundaries, the horizontal deck/void/cabin separation, and object markers' positions. Replace crude flat colors with polished pixel-art textures. Upper half: moonlit pale teak ship deck, four horizontal groups of lifeboats at top and bottom, small central bridge room, silver rail/blue sea accents. Lower half: dark-blue cabin carpet, symmetric small cabins either side of two horizontal corridors, silver bulkheads, pale doors. Cyan cells marked E are visible round open hatch/ladder portals; yellow G cells become tiny warm yellow lightning generator icons. Retain placement and footprint of all rooms exactly. Reference Image 2 is a style reference ONLY: hand-crafted slightly 3/4 pixel-art architectural overview, dark outlines, night lighting and selective warm lights. No text, no labels, no legend, no enlarged inset. Final image must be a crisp rectangular map, edge to edge.

参考底稿：`文档/协作/T8-midnight_cruise-ascii.txt` 转成 700×340 像素布局图。自检：50% 叠图人工对照外墙、甲板/虚空/船舱分区、中央驾驶室、上下船舱房间走向、E 舱口和 G 发电机。

## `map-snow-lodge-overview.png`（760×500）

提示词：Create the final top-down 2D pixel-art gameplay overview of a snowy mountain lodge map. Image 1 is a strict 76-column by 50-row layout blueprint at 10 pixels per cell: preserve its exact canvas aspect ratio, every wall, cracked-wall segment, doorway, all room boundaries, and the positions of structures and icons. Blue-white open snow field fills most area; three warm brown outbuildings: left top woodshed, right top tool shed, bottom central stable; central large warm timber lodge with its precise internal walls, fireplace and counters. Cold moonlit snow versus warm amber cabin windows, strong contrast. Yellow G cells become small warm yellow lightning generator icons at exactly the marked positions. No E hatch in this map. Sparse pines and props only where the blueprint allows; do not obstruct paths. Reference Image 2 is a style reference ONLY: crafted top-down slightly 3/4 pixel-art gameplay map, dark outlines, crisp blocky forms, cozy night lighting. No text, no labels, no legend, no inset. Final image must be one edge-to-edge rectangular map.

参考底稿：`文档/协作/T8-snow_lodge-ascii.txt` 转成 760×500 像素布局图。自检：50% 叠图人工对照左右上角附属建筑、中央木屋、下方马厩、雪地范围和 G 发电机。
