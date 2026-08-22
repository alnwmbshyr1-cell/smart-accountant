from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
size = 1024
image = Image.new('RGBA', (size, size), (13, 71, 161, 255))
draw = ImageDraw.Draw(image)

# calculator body
body = (170, 150, 854, 910)
draw.rounded_rectangle(body, radius=90, fill=(255, 193, 7, 255))
inner = (235, 215, 789, 845)
draw.rounded_rectangle(inner, radius=48, fill=(245, 245, 245, 255))

# display
draw.rounded_rectangle((295, 270, 729, 385), radius=28, fill=(13, 71, 161, 255))
# keypad
for row in range(3):
    for col in range(3):
        x = 295 + col * 145
        y = 470 + row * 105
        draw.rounded_rectangle((x, y, x + 78, y + 62), radius=16, fill=(13, 71, 161, 255))
# total/check mark
draw.rounded_rectangle((295, 790, 729, 835), radius=18, fill=(13, 71, 161, 255))

out = root / 'assets' / 'images' / 'accountant_icon.png'
out.parent.mkdir(parents=True, exist_ok=True)
image.save(out)

res_root = root / 'android' / 'app' / 'src' / 'main' / 'res'
for density, target in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
    folder = res_root / f'mipmap-{density}'
    folder.mkdir(parents=True, exist_ok=True)
    image.resize((target, target), Image.Resampling.LANCZOS).save(folder / 'ic_launcher.png')

for name in ('icon.png', 'splash-icon.png', 'favicon.png', 'android-icon-foreground.png'):
    target = root / 'assets' / 'images' / name
    image.save(target)
