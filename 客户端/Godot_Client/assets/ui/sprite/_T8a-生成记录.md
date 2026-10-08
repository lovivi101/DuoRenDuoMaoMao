# T8a 局内精灵生成记录

- 生成方式：内置 `image_gen`，逐个物件独立生成；本地 Pillow 只用于裁切、抠底、等比缩放、居中与检查。未以代码绘制最终精灵。
- 风格约束（每条提示词共用）：`Use case: stylized-concept. 2D night hide-and-seek game sprite, top-down slight 3/4 pixel art, chunky pixels, dark navy outlines. Hospital uses cold pale-green fluorescent light, stainless steel and white tile; mall uses pink-blue neon reflections, polished tile, glass and carpet. One object only; fully visible and centered; transparent background or pure #FF00FF chroma-key background; no floor or extra objects.`
- 地块共用约束：`One opaque, full-bleed, seamless square game-map texture. Opposite left/right and top/bottom edges must join visually; no border, letters, or room scene.`
- 续作说明：下表标为“续用”的 6 张原图来自 `C:\Temp\T8a-raw`，原始生成提示词未随文件保存；表内为按原图内容编写的**复现提示词**，不冒充上次的原文。其余条目记录本次实际发送的主体提示词；通用风格和地块约束见上。

| 文件 | 来源 | 主体提示词 / 复现提示词 | 裁切 (x,y,边长) | 接缝 H/V |
| --- | --- | --- | --- | --- |
| `tile-floor-corridor.png` | 续用 | `Night hospital long corridor, pale gray-green vinyl floor, one mint guide stripe running vertically through the center.` | 0,0,1254 | 0.74 / 2.39 |
| `tile-floor-clinic.png` | 续用 | `Night hospital nurse station and X-ray room floor, white marble square tiles with faint cool green veining.` | 652,480,350 | 3.30 / 3.40 |
| `tile-floor-ward.png` | 续用 | `Night hospital ward floor, small pale cyan square ceramic tiles with dark grout.` | 152,152,950 | 3.49 / 5.17 |
| `tile-wall-solid-hospital.png` | 本次重生 | `Pale ivory hospital brick wall tile with a horizontal mint-green wainscot band confined to the middle third. Top and bottom edge strips identical pale ivory brick; left and right match.` | 115,108,1100 | 7.02 / 5.15 |
| `tile-wall-cracked-hospital.png` | 本次重生 | `Pale ivory hospital brick wall tile with horizontal mint-green wainscot band in the middle third, plus one prominent dark branching crack. All opposite edges match.` | 272,203,950 | 7.78 / 9.51 |
| `tile-door-hospital.png` | 续用 | `Night hospital pale mint-metal double door, small blue glass windows and stainless handles, overhead game-map tile.` | 22,2,1200 | 2.74 / 10.05 |
| `tile-floor-mall.png` | 本次重生 | `Small regular orthogonal pale gray polished square tiles and subtle cyan/pink neon reflections. Uniform lighting and repeating grid, no diagonal perspective.` | 695,421,500 | 2.08 / 1.96 |
| `tile-floor-carpet.png` | 本次 | `Deep burgundy-purple patterned shopping mall carpet, subtle repeating geometric floral motifs, dark navy outlines, pink-blue neon reflections.` | 77,77,1100 | 2.28 / 2.60 |
| `tile-wall-solid-mall.png` | 本次 | `Pale gray shopping mall brick wall face with a thin horizontal pink and cyan neon light strip, brighter than floor.` | 364,392,650 | 2.41 / 1.89 |
| `tile-wall-cracked-mall.png` | 本次重生 | `Pale gray mall brick wall tile with pink and cyan neon stripe in middle third and prominent dark branching crack; top/bottom pale gray brick.` | 189,57,1050 | 6.25 / 6.28 |
| `tile-door-mall.png` | 本次重生 | `Closed shop glass automatic sliding doorway laid flat in the middle of polished mall floor, blue glass panels and silver frame; same pale floor texture on all four outer edges.` | 227,227,800 | 2.97 / 2.72 |
| `tile-curtain.png` | 本次 | `Single horizontal line of gathered deep red velvet fitting-room curtain seen from above, subtle pleats, mall floor visible above and below.` | 397,60,800 | 7.81 / 8.97 |
| `tile-atrium.png` | 本次 | `Shopping mall atrium void seen top-down, dark navy lower-floor drop, subtle pink/cyan reflections, glass safety railing at edge.` | 439,383,400 | 6.89 / 7.47 |

以下物件逐件调用 `image_gen`；提示词在上述共用风格约束后加入所列主体描述，要求透明底、无地板、单件完整居中。医院物件用冷绿光，商场物件用霓虹光。`prop-vending-machine` 和 `prop-promo-stand` 为避免品红像素另加 `CYAN and WARM AMBER only; absolutely no pink or magenta pixels anywhere` 后重生。

| 文件 | 主体提示词 |
| --- | --- |
| `furn-hospital-bed.png` | `A single hospital bed for a 1x2 vertical footprint, white sheet and pillow at the TOP, mint mattress hints and stainless side rails.` |
| `furn-clothes-rack.png` | `A single long horizontal clothing rack holding a continuous row of colorful jackets and shirts, steel bar and feet, for a 3x1 footprint.` |
| `prop-iv-stand.png` | `Single stainless steel IV infusion pole on five casters, two clear saline bags hanging from top hooks.` |
| `prop-wheelchair.png` | `Single empty hospital wheelchair, dark steel frame, mint padded seat, large spoked rear wheels and small front casters.` |
| `prop-folding-screen.png` | `Single medical privacy folding screen with three hinged pale mint fabric panels and thin steel frame on casters.` |
| `prop-gurney.png` | `Single hospital gurney trolley, white padded mattress and folded sheet, stainless side rails and caster wheels.` |
| `prop-medicine-cabinet.png` | `Single tall hospital medicine cabinet with pale green metal frame, glass front and shelves of medicine boxes and bottles.` |
| `prop-mannequin.png` | `Single fully clothed retail fashion display figure: featureless white plastic head and hands, buttoned navy overcoat and long trousers, small display base; inanimate shop fixture.` |
| `prop-shopping-cart.png` | `Single empty silver wire shopping trolley, rectangular open basket on four caster wheels, teal push handle.` |
| `prop-vending-machine.png` | `Single upright snack vending machine in dark blue casing, display and buttons glow cyan and warm amber only, no pink or magenta.` |
| `prop-promo-stand.png` | `Single mall promotional sandwich board, dark blue frame, graphic only cyan, warm amber and white, no lettering or magenta.` |
| `sprite-portal-elevator.png` | `Single elevator portal: pair of closed brushed steel lift doors with illuminated up and down arrow indicator above.` |
| `sprite-portal-escalator.png` | `Single mall escalator entrance from above: short run of ribbed moving steps, paired silver handrails with blue illuminated edges.` |
| `sprite-portal-stairs.png` | `Single fire escape stairwell portal: gray descending steps, metal rails, illuminated green safety exit sign with simple running-person pictogram.` |
| `sprite-ecg-monitor.png` | `Single hospital ECG heart monitor cart, black display with luminous green heartbeat waveform, light-green housing and wheeled stand.` |
| `sprite-broadcast-mic.png` | `Single hospital broadcast room microphone desk: tabletop gooseneck microphone, control buttons and red ON AIR indicator.` |

自检方法：地块缩到 64×64 后比较左右、上下边缘相邻像素的 RGB 三通道绝对差均值，13 张地块两方向最大为 10.05，均小于 12。16 张透明物件均为 RGBA，四角 8×8 的 alpha 最大值 0；可见像素中满足 `R>200,G<60,B>200` 的像素均为 0。
