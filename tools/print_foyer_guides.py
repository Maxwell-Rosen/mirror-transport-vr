"""Print the foyer's folded brochure covers, admission tickets and botanical studies."""
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
STOCK = "#f5efdd"
INK = "#173e38"
CLAY = "#a74d32"
GOLD = "#e5c17e"
sheet = Image.new("RGB", (512, 512), STOCK)
draw = ImageDraw.Draw(sheet)


def words(x, y, value, size, color=INK, serif=False):
    family = "DejaVuSerif" if serif else "DejaVuSans"
    font = ImageFont.truetype(str(ROOT / f"museum/fonts/{family}.ttf"), size)
    for line in value.splitlines():
        draw.text((x, y), line, font=font, fill=color, anchor="la")
        y += round(size * 1.22)


def rings(x, y, width, height, spacing, color, weight):
    for step in range(3):
        left = x + step * spacing
        draw.ellipse((left, y, left + width, y + height), outline=color, width=weight)


# The pocket brochures lie cover-up on the counter.
draw.rectangle((0, 0, 255, 399), fill=INK)
words(20, 20, "MUSEUM OF", 15, STOCK)
words(20, 40, "PLASMA PHYSICS", 15, STOCK)
draw.line((20, 72, 236, 72), fill=GOLD, width=2)
words(18, 90, "Mirror", 43, STOCK, serif=True)
words(18, 143, "Transport", 43, STOCK, serif=True)
rings(57, 207, 78, 88, 32, GOLD, 4)
draw.rectangle((0, 320, 255, 399), fill=STOCK)
words(20, 344, "Visitor guide", 29, serif=True)

# A perforated tear-off ticket fits beneath the cover.
draw.rectangle((4, 404, 251, 507), outline=CLAY, width=3)
draw.rectangle((9, 409, 198, 502), outline=CLAY, width=1)
words(19, 422, "Mirror Transport", 16, CLAY, serif=True)
words(17, 452, "ADMIT ONE", 29)
for y in range(411, 500, 10):
    draw.line((204, y, 204, y + 4), fill=INK, width=2)
rings(213, 434, 15, 40, 6, CLAY, 2)

# Two ink studies for the bench alcove, in the spare margin of the same sheet.
def leaf(base, tip, width, color):
    x, y = base
    dx, dy = tip[0] - x, tip[1] - y
    nx, ny = -dy * width / math.hypot(dx, dy), dx * width / math.hypot(dx, dy)
    draw.polygon([(x, y), (x + .28*dx + nx, y + .28*dy + ny),
                  (x + .68*dx + .8*nx, y + .68*dy + .8*ny), tip,
                  (x + .48*dx - nx, y + .48*dy - ny)], fill=color)
    draw.line([base, (x + .79*dx, y + .79*dy)], fill=STOCK)


for top, count in [(16, 7), (144, 15)]:
    stem = []
    for n in range(count + 1):
        t = n / count
        stem.append((272 + 17 + 189*t, top + 95 - 61*t - 10*math.sin(t*math.pi)))
    draw.line(stem, fill=INK, width=2)
    for n, (x, y) in enumerate(stem[1:-1], 1):
        size = math.sin(math.pi * n / count) ** .5
        width = 6.2 if count == 7 else 2.8
        leaf((x, y), (x + 11, y - 8 - 27*size), width * size, "#466452")
        leaf((x + 5, y - 1), (x + 21 + 12*size, y + 19*size), width * size, "#687b5c")
    leaf(stem[-2], stem[-1], 3.0, INK)

if __name__ == "__main__":
    sheet.save(ROOT / "museum/foyer/printed_paper.png", optimize=True)
