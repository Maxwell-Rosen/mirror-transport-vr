"""Prepare the museum's framed prints from the original photographs in photos/."""

from io import BytesIO
from pathlib import Path

from PIL import Image, ImageCms, ImageOps


ROOT = Path(__file__).resolve().parents[1]
PRINTS = {
    "ammar-hakim": "ammar-hakim.webp",
    "greg-hammett": "hammett_gregory.jpg",
    "maxwell-rosen": "20241121_PPiPP Grad Students_Individual_0254  (1).png",
    "spring-courtyard": "IMG20240330155316.jpg",
    "evening-tower": "IMG20241024175437.jpg",
    "graduate-students": "20241121_PPiPP Grad Students_Group_0023.png",
    "poster-session": "IMG-20241011-WA0012.jpg",
    "around-the-table": "IMG20240412191611.jpg",
    "orchestra-rehearsal": "IMG_9893_Edited.jpg",
    "string-players": "IMG-20231210-WA0017.jpg",
    "gkeyll-group-dinner": "img_8319.jpg",
    "thanksgiving-at-ammars": "IMG_5327 (1).jpg",
    "improv-group": "IMG-20261118-WA0000.jpg",
    "evening-with-friends": "IMG20260524015642.jpg",
    "campfire": "IMG-20220822-WA0018.jpg",
    "autumn-lawn": "IMG20241124145133.jpg",
}


def main():
    output = ROOT / "museum/photographs"
    output.mkdir(exist_ok=True)
    srgb = ImageCms.createProfile("sRGB")
    for name, source in PRINTS.items():
        with Image.open(ROOT / "photos" / source) as original:
            photo = ImageOps.exif_transpose(original)
            if name == "ammar-hakim":
                # Match the headroom and eye level of Greg Hammett's square print.
                photo = photo.resize((750, 750), Image.Resampling.LANCZOS, box=(236, 110, 1100, 974))
            else:
                photo.thumbnail((1280, 1280), Image.Resampling.LANCZOS)
            profile = original.info.get("icc_profile")
            if profile:
                photo = ImageCms.profileToProfile(photo, ImageCms.ImageCmsProfile(BytesIO(profile)), srgb, outputMode="RGB")
            photo.convert("RGB").save(output / f"{name}.webp", quality=92, method=6)


if __name__ == "__main__":
    main()
