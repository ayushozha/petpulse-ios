"""Builds the PetPulse pitch video: HTML slides -> 4K stills, edge-tts narration, ffmpeg assembly.

Usage (from the repo root, on Windows):
    python video/build.py audio     # narration only, prints total length
    python video/build.py           # everything -> video/PetPulse-demo-4k.mp4

Needs ffmpeg, the edge-tts Python module, Microsoft Edge, and the source images in the repo root.
"""
import html
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "video"
BUILD = OUT / "build"
EDGE = os.environ.get("EDGE_PATH", r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe")
VOICE = os.environ.get("TTS_VOICE", "en-US-AvaMultilingualNeural")
RATE = os.environ.get("TTS_RATE", "-9%")
ENCODER = os.environ.get("VIDEO_ENCODER", "libx264")
FPS, LEAD, TAIL, FADE = 30, 0.5, 0.7, 0.5

WA = "WhatsApp Image 2026-10-10 at "
PHOTO = {
    "poster": WA + "9.19.36 PM (1).jpeg",
    "closeup": WA + "9.05.26 PM (1).jpeg",
    "sit": WA + "9.05.26 PM.jpeg",
    "sleep": WA + "9.04.08 PM.jpeg",
    "stretch": WA + "9.06.45 PM.jpeg",
    "table": WA + "9.09.53 PM.jpeg",
}


def uri(path: Path) -> str:
    return path.resolve().as_uri()


def photo(key: str) -> str:
    return uri(ROOT / PHOTO[key])


def screen(n: int) -> str:
    return uri(BUILD / "screens" / f"s{n}.png")


LOGO = """<svg viewBox="0 0 150 100" class="logo"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
<stop offset="0" stop-color="#5FD39A"/><stop offset=".55" stop-color="#23A9AC"/><stop offset="1" stop-color="#3D9BE0"/></linearGradient></defs>
<path fill="url(#g)" d="M50 28C44 4 4 6 4 34c0 30 34 46 46 62 12-16 46-32 46-62C96 6 56 4 50 28z"/>
<g fill="#fff"><ellipse cx="50" cy="58" rx="13" ry="11"/><ellipse cx="31" cy="44" rx="6" ry="8"/><ellipse cx="43" cy="33" rx="6" ry="8"/>
<ellipse cx="57" cy="33" rx="6" ry="8"/><ellipse cx="69" cy="44" rx="6" ry="8"/></g>
<polyline fill="none" stroke="#23A9AC" stroke-width="4" stroke-linecap="round" stroke-linejoin="round" points="92,60 108,60 114,40 122,80 128,54 134,60 148,60"/></svg>"""
WORDMARK = '<span class="wm"><b class="navy">Pet</b><b class="teal">Pulse</b></span>'

CSS = """
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:1920px;height:1080px;overflow:hidden}
body{font-family:'Segoe UI Variable Display','Segoe UI',sans-serif;color:#2B3A4A;
 background:linear-gradient(150deg,#fff 0%,#EAF7F4 55%,#CFEFE9 100%);position:relative}
.blob{position:absolute;border-radius:50%;filter:blur(70px);opacity:.55}
.b1{width:620px;height:620px;background:#BDEBE2;left:-180px;bottom:-220px}
.b2{width:520px;height:520px;background:#D5E9FB;right:-140px;top:-180px}
.navy{color:#1D3557}.teal{color:#23A9AC}
.logo{height:1em;vertical-align:-.12em;margin-right:.12em}
.brand{position:absolute;left:96px;top:64px;font-size:40px;display:flex;align-items:center}
.wm b{font-weight:700;letter-spacing:-.01em}
.wrap{position:absolute;inset:0;display:flex;align-items:center;padding:150px 110px 90px 110px;gap:80px}
.copy{flex:1;min-width:0}
.kicker{font-size:30px;font-weight:700;letter-spacing:.16em;text-transform:uppercase;color:#23A9AC;margin-bottom:26px}
h1{font-size:84px;line-height:1.08;font-weight:700;color:#1D3557;letter-spacing:-.02em}
h1 em{font-style:normal;color:#23A9AC}
p.sub{font-size:40px;line-height:1.4;color:#56677A;margin-top:34px;max-width:900px}
ul{list-style:none;margin-top:40px}
li{font-size:38px;line-height:1.35;color:#2B3A4A;margin-bottom:22px;padding-left:58px;position:relative}
li:before{content:'';position:absolute;left:0;top:.28em;width:30px;height:30px;border-radius:50%;
 background:linear-gradient(135deg,#4CC5B4,#23A9AC)}
.phone{height:900px;border-radius:54px;border:12px solid #fff;box-shadow:0 40px 90px rgba(29,53,87,.22);display:block}
.pic{width:760px;height:860px;object-fit:cover;border-radius:48px;border:12px solid #fff;
 box-shadow:0 40px 90px rgba(29,53,87,.22);display:block}
.chips{display:flex;gap:26px;margin-top:44px;flex-wrap:wrap}
.chip{background:#fff;border-radius:28px;padding:22px 34px;font-size:36px;font-weight:600;color:#1D3557;
 box-shadow:0 12px 30px rgba(29,53,87,.10)}
.chip b{color:#E5484D;font-size:52px;margin-right:12px}
.center{flex-direction:column;justify-content:center;text-align:center;gap:0}
.strike{font-size:60px;color:#8A99A8;text-decoration:line-through;margin-bottom:36px}
.big{font-size:124px;line-height:1.05;font-weight:700;color:#1D3557;letter-spacing:-.02em}
.stats{display:grid;grid-template-columns:1fr 1fr;gap:34px;width:100%;margin-top:50px}
.stat{background:#fff;border-radius:36px;padding:38px 46px;text-align:left;box-shadow:0 16px 40px rgba(29,53,87,.10)}
.stat b{display:block;font-size:120px;line-height:1;font-weight:700;color:#23A9AC;letter-spacing:-.03em}
.stat span{display:block;font-size:34px;color:#2B3A4A;margin-top:14px;line-height:1.3}
.src{font-size:24px;color:#70808F;margin-top:30px}
.pillars{display:grid;grid-template-columns:repeat(4,1fr);gap:30px;width:100%;margin-top:60px}
.pillar{background:#fff;border-radius:36px;padding:44px 30px;box-shadow:0 16px 40px rgba(29,53,87,.10)}
.pillar b{display:block;font-size:46px;color:#1D3557}
.pillar span{display:block;font-size:30px;color:#56677A;margin-top:14px;line-height:1.3}
.vs{font-size:38px;color:#8A99A8;margin-top:26px}
.banner{margin-top:50px;font-size:44px;font-weight:600;color:#fff;padding:26px 54px;border-radius:999px;
 background:linear-gradient(90deg,#4CC5B4,#23A9AC);display:inline-block}
.steps{display:flex;align-items:center;justify-content:center;gap:22px;margin-top:70px;width:100%}
.step{background:#fff;border-radius:32px;padding:36px 34px;font-size:36px;font-weight:600;color:#1D3557;
 box-shadow:0 16px 40px rgba(29,53,87,.10);flex:1}
.step small{display:block;font-size:26px;font-weight:400;color:#70808F;margin-top:10px}
.step.on{background:linear-gradient(135deg,#4CC5B4,#23A9AC);color:#fff}.step.on small{color:#E4F5F2}
.arrow{font-size:54px;color:#23A9AC}
.hand{font-family:'Segoe Print','Ink Free',cursive;color:#23A9AC;font-size:64px;line-height:1.25;margin-top:40px}
.poster{position:absolute;right:120px;top:0;width:860px;height:1080px;overflow:hidden;
 -webkit-mask-image:linear-gradient(90deg,transparent 0,#000 14%,#000 86%,transparent 100%)}
.poster img{width:860px;display:block}
"""


def page(body: str, brand: bool = True) -> str:
    mark = f'<div class="brand">{LOGO}{WORDMARK}</div>' if brand else ""
    return (f'<!doctype html><html><head><meta charset="utf-8"><style>{CSS}</style></head><body>'
            f'<div class="blob b1"></div><div class="blob b2"></div>{mark}{body}</body></html>')


def copy(kicker: str, title: str, sub: str = "", bullets=(), extra: str = "") -> str:
    items = "".join(f"<li>{b}</li>" for b in bullets)
    return (f'<div class="copy"><div class="kicker">{kicker}</div><h1>{title}</h1>'
            + (f'<p class="sub">{sub}</p>' if sub else "") + (f"<ul>{items}</ul>" if items else "") + extra + "</div>")


def with_phone(n: int, *args, **kwargs) -> str:
    return page(f'<div class="wrap">{copy(*args, **kwargs)}<img class="phone" src="{screen(n)}"></div>')


def with_photo(key: str, *args, position: str = "center", **kwargs) -> str:
    return page(f'<div class="wrap">{copy(*args, **kwargs)}'
                f'<img class="pic" style="object-position:{position}" src="{photo(key)}"></div>')


def centered(inner: str) -> str:
    return page(f'<div class="wrap center">{inner}</div>')


# (slide html, narration)
SCENES = [
    (page(f'<div class="poster"><img src="{photo("poster")}"></div><div class="wrap"><div class="copy" style="max-width:1000px">'
          f'<div style="font-size:150px;display:flex;align-items:center">{LOGO}{WORDMARK}</div>'
          '<h1 style="margin-top:30px">Know your pet. <em>Sooner.</em></h1>'
          '<p class="sub">Personalized pet health monitoring for a happier, healthier tomorrow.</p></div></div>', brand=False),
     "Meet PetPulse. Know your pet, sooner."),

    (with_photo("closeup", "The problem", "Pets can't tell us when something hurts.",
                "They speak through small changes in appetite, play and routine."),
     "Our pets can't tell us when something hurts. They speak through tiny changes. "
     "A little less food. A little less play. A quieter day."),

    (with_photo("stretch", "The problem", "The signals are easy to miss.",
                bullets=["Skipping dry food may not be fussiness. It may be dental pain.",
                         "By the time we notice, the problem has often grown."]),
     "For first-time owners, those signals are easy to miss. A cat who stops eating dry food may not be picky. "
     "She may have a toothache. And by the time we notice, the problem has often grown."),

    (centered('<div class="kicker">The insight</div><div class="strike">Is this normal for a cat?</div>'
              '<div class="big">Is this normal for <span class="teal">my</span> cat?</div>'),
     "Most advice online is generic. It asks, is this normal for a cat? "
     "PetPulse asks a better question. Is this normal for my cat?"),

    (with_phone(2, "Step 1", "Start with a simple profile.",
                bullets=["Name, species and breed", "Age, sex and weight", "Medical history"]),
     "It starts with a simple profile. Name, breed, age, weight, and medical history."),

    (with_phone(4, "Step 2", "A daily check-in, in about a minute.",
                bullets=["Food and water", "Stool and urination", "Activity, coat, skin and eyes", "Photos and notes"]),
     "Then, once a day, a quick check-in. Food, water, stool, activity, coat and eyes, with photos and notes. "
     "It takes about a minute."),

    (with_phone(5, "Step 3", "It learns <em>your</em> pet's baseline.",
                "How much Mochi usually eats, drinks and plays, learned from her own history."),
     "Over time, PetPulse learns your pet's personal baseline. How much Mochi usually eats, drinks, and plays."),

    (with_phone(3, "Every day", "Most days, reassurance.",
                "One clear answer on the home screen: no meaningful change detected."),
     "Most days, the answer is reassuring. No meaningful change detected."),

    (with_phone(6, "When it matters", "When something shifts, it notices.",
                extra='<div class="chips"><div class="chip"><b>&darr; 40%</b>dry food</div>'
                      '<div class="chip"><b>&darr; 30%</b>activity</div></div>'
                      '<p class="sub">What changed, what it could mean, and what to do next.</p>'),
     "But when something shifts, PetPulse notices. Dry food, down forty percent. Activity, down thirty percent. "
     "It explains what changed, what it could mean, and what to do next. Keep monitoring, or see your vet."),

    (with_phone(7, "History", "One health timeline.", "Every check-in, photo and report, in order."),
     "Every check-in, every photo, and every report lives on one health timeline."),

    (with_phone(8, "For your vet", "A vet-ready summary in one tap.",
                bullets=["Key changes against baseline", "A clear timeline", "Photos and owner notes"]),
     "And with one tap, something feels wrong becomes a vet-ready summary. Clear changes, a clear timeline, "
     "and photos your veterinarian can use."),

    (centered('<div class="kicker">The need is real</div><h1>Pet health changes every day.<br>Vets only see snapshots.</h1>'
              '<div class="stats"><div class="stat"><b>94M</b><span>U.S. households own a pet</span></div>'
              '<div class="stat"><b>~49M</b><span>U.S. households own a cat</span></div>'
              '<div class="stat"><b>52%</b><span>of owners have skipped or declined needed vet care</span></div>'
              '<div class="stat"><b>94%</b><span>of vets say client finances limit recommended care</span></div></div>'
              '<div class="src">Care figures: PetSmart Charities&ndash;Gallup. Household figures: team market research.</div>'),
     "The need is real. Ninety-four million American households own a pet. About forty-nine million own a cat. "
     "Fifty-two percent of owners have skipped or declined needed veterinary care. "
     "And ninety-four percent of veterinarians say cost limits the care they can recommend."),

    (centered('<div class="kicker">Why PetPulse is different</div><h1>Change from <em>your</em> pet\'s normal, over time.</h1>'
              '<div class="pillars"><div class="pillar"><b>Personalized</b><span>Your pet\'s own baseline</span></div>'
              '<div class="pillar"><b>Longitudinal</b><span>Trends, not one moment</span></div>'
              '<div class="pillar"><b>Multimodal</b><span>Food, behavior, photos and more</span></div>'
              '<div class="pillar"><b>Actionable</b><span>Monitor, or see the vet</span></div></div>'
              '<div class="banner">No new hardware. Just your phone.</div>'),
     "Other tools look at one symptom, one photo, one moment. PetPulse is designed to be personalized, longitudinal, "
     "multimodal, and actionable. With no new hardware. Just your phone, and the signals your pet already gives you every day."),

    (with_photo("table", "Our promise", "Supports your vet. Never replaces them.",
                "Early change detection, monitoring and triage support. Not a diagnosis."),
     "PetPulse doesn't replace your veterinarian. It helps you reach them sooner, with better information."),

    (centered('<div class="kicker">Where we start</div><h1>First-time cat owners first.</h1>'
              '<div class="steps"><div class="step on">First-time cat owners<small>Our starting point</small></div>'
              '<div class="arrow">&rarr;</div><div class="step">All cat owners<small>Next</small></div>'
              '<div class="arrow">&rarr;</div><div class="step">Dog owners<small>Then</small></div>'
              '<div class="arrow">&rarr;</div><div class="step">Clinics and insurers<small>Future partners</small></div></div>'),
     "We begin with first-time cat owners. Then all cat owners, then dogs. "
     "And in time, partners like clinics and insurers."),

    (page(f'<div class="wrap"><div class="copy"><div style="font-size:120px;display:flex;align-items:center">{LOGO}{WORDMARK}</div>'
          '<div class="hand">Small changes make<br>a big difference &hearts;</div>'
          '<p class="sub">Because every pet deserves a longer, healthier life.</p></div>'
          f'<img class="phone" src="{screen(1)}"></div>', brand=False),
     "PetPulse. Small changes make a big difference. Because every pet deserves a longer, healthier life."),
]


def run(*args: str) -> str:
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout


def duration(path: Path) -> float:
    return float(run("ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)))


def narrate(i: int) -> float:
    path = BUILD / f"n{i:02d}.mp3"
    run(sys.executable, "-m", "edge_tts", "--voice", VOICE, f"--rate={RATE}", "--text", SCENES[i][1],
        "--write-media", str(path))
    return duration(path)


def render_slide(i: int) -> None:
    src = BUILD / f"slide{i:02d}.html"
    src.write_text(SCENES[i][0], encoding="utf-8")
    run(EDGE, "--headless", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=2",
        "--window-size=1920,1080", f"--screenshot={BUILD / f'slide{i:02d}.png'}", uri(src))


def render_clip(i: int, speech: float) -> None:
    total = LEAD + speech + TAIL
    frames = round(total * FPS)
    # Alternate a slow push-in and pull-out so consecutive scenes do not move the same way.
    zoom = f"1+0.05*on/{frames}" if i % 2 == 0 else f"1.05-0.05*on/{frames}"
    video = (f"[0:v]scale=3840:2160:force_original_aspect_ratio=increase,crop=3840:2160,"
             f"zoompan=z='{zoom}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={frames}:s=3840x2160:fps={FPS},"
             f"fade=t=in:st=0:d={FADE}:color=white,fade=t=out:st={total - FADE:.3f}:d={FADE}:color=white,format=yuv420p[v]")
    audio = f"[1:a]adelay={int(LEAD * 1000)}:all=1,apad,aresample=48000[a]"
    quality = ["-preset", "p5", "-cq", "20"] if "nvenc" in ENCODER else ["-preset", "veryfast", "-crf", "18"]
    run("ffmpeg", "-y", "-loglevel", "error", "-i", str(BUILD / f"slide{i:02d}.png"), "-i", str(BUILD / f"n{i:02d}.mp3"),
        "-filter_complex", f"{video};{audio}", "-map", "[v]", "-map", "[a]", "-t", f"{total:.3f}",
        "-c:v", ENCODER, *quality, "-r", str(FPS), "-c:a", "aac", "-b:a", "192k", "-ac", "2", str(BUILD / f"clip{i:02d}.mp4"))


def timestamp(seconds: float) -> str:
    ms = round(seconds * 1000)
    return f"{ms // 3600000:02d}:{ms // 60000 % 60:02d}:{ms // 1000 % 60:02d},{ms % 1000:03d}"


def main() -> None:
    BUILD.mkdir(parents=True, exist_ok=True)
    indices = range(len(SCENES))
    with ThreadPoolExecutor(4) as pool:
        speech = list(pool.map(narrate, indices))
    total = sum(LEAD + s + TAIL for s in speech)
    print(f"narration {sum(speech):.1f}s, video {total:.1f}s ({int(total // 60)}:{total % 60:04.1f})")
    if sys.argv[1:] == ["audio"]:
        return

    with ThreadPoolExecutor(4) as pool:
        list(pool.map(render_slide, indices))
    with ThreadPoolExecutor(int(os.environ.get("VIDEO_JOBS", "3"))) as pool:
        list(pool.map(render_clip, indices, speech))

    start, captions = 0.0, []
    for i, s in enumerate(speech):
        captions.append(f"{i + 1}\n{timestamp(start + LEAD)} --> {timestamp(start + LEAD + s)}\n{html.unescape(SCENES[i][1])}\n")
        start += LEAD + s + TAIL
    (OUT / "PetPulse-demo-4k.srt").write_text("\n".join(captions), encoding="utf-8")
    (OUT / "script.md").write_text("# PetPulse video script\n\n" + "\n\n".join(
        f"**Scene {i + 1}.** {text}" for i, (_, text) in enumerate(SCENES)) + "\n", encoding="utf-8")

    listing = BUILD / "clips.txt"
    listing.write_text("".join(f"file 'clip{i:02d}.mp4'\n" for i in indices), encoding="utf-8")
    final = OUT / "PetPulse-demo-4k.mp4"
    run("ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(listing), "-c", "copy",
        "-movflags", "+faststart", str(final))
    print(f"wrote {final} ({duration(final):.1f}s, {final.stat().st_size / 1e6:.0f} MB)")


if __name__ == "__main__":
    main()
