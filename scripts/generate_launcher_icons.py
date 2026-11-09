import os
from PIL import Image, ImageDraw

def create_rounded_mask(size, radius):
    factor = 4
    mask = Image.new('L', (size[0] * factor, size[1] * factor), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([0, 0, size[0] * factor - 1, size[1] * factor - 1], radius=radius * factor, fill=255)
    return mask.resize(size, Image.Resampling.LANCZOS)

def create_circle_mask(size):
    factor = 4
    mask = Image.new('L', (size[0] * factor, size[1] * factor), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse([0, 0, size[0] * factor - 1, size[1] * factor - 1], fill=255)
    return mask.resize(size, Image.Resampling.LANCZOS)

def main():
    base = Image.open('rendered_icon_512.png').convert('RGBA')

    # Android mipmaps
    android_sizes = {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
    }

    for density, size in android_sizes.items():
        dir_path = f'android/app/src/main/res/mipmap-{density}'
        os.makedirs(dir_path, exist_ok=True)
        
        resized = base.resize((size, size), Image.Resampling.LANCZOS)

        # Standard squircle launcher icon
        squircle = resized.copy()
        squircle_mask = create_rounded_mask((size, size), radius=int(size * 0.2))
        squircle.putalpha(squircle_mask)
        squircle.save(f'{dir_path}/ic_launcher.png', 'PNG')

        # Round launcher icon
        round_icon = resized.copy()
        circle_mask = create_circle_mask((size, size))
        round_icon.putalpha(circle_mask)
        round_icon.save(f'{dir_path}/ic_launcher_round.png', 'PNG')
        print(f'Generated Android icons for mipmap-{density} ({size}x{size})')

    # Web icons
    web_icons_dir = 'web/icons'
    os.makedirs(web_icons_dir, exist_ok=True)

    for sz in [192, 512]:
        resized = base.resize((sz, sz), Image.Resampling.LANCZOS)
        # Standard icon
        icon = resized.copy()
        mask = create_rounded_mask((sz, sz), radius=int(sz * 0.18))
        icon.putalpha(mask)
        icon.save(f'{web_icons_dir}/Icon-{sz}.png', 'PNG')

        # Maskable icon (full bleed)
        resized.save(f'{web_icons_dir}/Icon-maskable-{sz}.png', 'PNG')
        print(f'Generated web icons for size {sz}x{sz}')

    # Web favicon.png (64x64)
    fav = base.resize((64, 64), Image.Resampling.LANCZOS)
    fav_mask = create_rounded_mask((64, 64), radius=12)
    fav.putalpha(fav_mask)
    fav.save('web/favicon.png', 'PNG')
    print('Generated web/favicon.png (64x64)')

if __name__ == '__main__':
    main()
