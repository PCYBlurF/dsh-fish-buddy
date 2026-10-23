import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from build import Renderer
from promolib import get_font
from PIL import ImageDraw

out = Renderer().render(2.6)
d = ImageDraw.Draw(out)
# bottom-right repo
repo_font = get_font("mono", 20)
repo = "github.com/PCYBlurF/dsh-fish-buddy"
d.text((1920 - 64 - d.textlength(repo, font=repo_font), 1016), repo, font=repo_font, fill=(140, 160, 200))
out.convert("RGB").save("cover-v0.1.22.png", "PNG")
print("saved", out.size)
