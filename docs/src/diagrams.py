"""Generates the SVG diagrams used by the report and poster."""
FONT = "Liberation Sans, Arial, sans-serif"

def box(x, y, w, h, title, sub="", fill="#e8f0fb", stroke="#3b6fb6", tcolor="#14284b"):
    s = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="{fill}" stroke="{stroke}" stroke-width="1.5"/>'
    if sub:
        s += f'<text x="{x+w/2}" y="{y+h/2-4}" text-anchor="middle" font-size="{13 if len(title)<13 else 11.5}" font-weight="700" fill="{tcolor}">{title}</text>'
        for i, line in enumerate(sub.split("\n")):
            s += f'<text x="{x+w/2}" y="{y+h/2+13+i*13}" text-anchor="middle" font-size="11" fill="#444">{line}</text>'
    else:
        s += f'<text x="{x+w/2}" y="{y+h/2+5}" text-anchor="middle" font-size="14" font-weight="700" fill="{tcolor}">{title}</text>'
    return s

def arrow(x1, y1, x2, y2, label="", dash=False, color="#555"):
    d = ' stroke-dasharray="5 4"' if dash else ""
    s = f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="1.6"{d} marker-end="url(#a)"/>'
    if label:
        s += f'<text x="{(x1+x2)/2+6}" y="{(y1+y2)/2-9}" font-size="11" fill="#333" stroke="#fff" stroke-width="3" paint-order="stroke">{label}</text>'
    return s

def svg(w, h, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}" font-family="{FONT}">'
            '<defs><marker id="a" markerWidth="9" markerHeight="9" refX="8" refY="4.5" orient="auto">'
            '<path d="M0,0 L9,4.5 L0,9 z" fill="#555"/></marker></defs>'
            f'<rect width="{w}" height="{h}" fill="#ffffff"/>{body}</svg>')

# Figure: layered architecture
b = ""
b += '<rect x="10" y="10" width="640" height="92" rx="10" fill="#f3f0fb" stroke="#8a74d6" stroke-dasharray="4 3"/>'
b += '<text x="22" y="30" font-size="12" fill="#5a47a6" font-weight="700">Views (SwiftUI)</text>'
for i, (t, s) in enumerate([("CraftView", "canvas + tray"), ("DiscoveryLogView", "@FetchRequest"), ("ElementDetailView", "recipes"), ("AtlasView", "MapKit"), ("SettingsView", "@AppStorage")]):
    b += box(18 + i*126, 40, 122, 52, t, s, fill="#ede8fb", stroke="#8a74d6", tcolor="#2f2370")
b += box(190, 150, 280, 66, "GameViewModel", "@Observable, @MainActor\ncache, discovered, modes", fill="#e1f3e6", stroke="#3f9a5b", tcolor="#14502a")
b += box(20, 270, 190, 70, "Foundation Models", "LanguageModelSession\non-device, @Generable", fill="#fdeedd", stroke="#d48a2f", tcolor="#6b3d05")
b += box(235, 270, 190, 70, "RecipeBook", "offline fallback\n125 hand-written recipes", fill="#fdeedd", stroke="#d48a2f", tcolor="#6b3d05")
b += box(450, 270, 190, 70, "Core Data", "ElementEntity\nCombinationEntity", fill="#e8f0fb", stroke="#3b6fb6")
b += arrow(330, 102, 330, 150, "reads / calls")
b += arrow(260, 216, 115, 270, "1. ask model")
b += arrow(330, 216, 330, 270, "2. if it fails", dash=True)
b += arrow(400, 216, 545, 270, "load / save")
b += '<text x="330" y="364" text-anchor="middle" font-size="11" fill="#666">Everything runs on the device. No network calls.</text>'
open("fig-architecture.svg", "w").write(svg(660, 376, b))

# Figure: combine pipeline
b = ""
b += box(20, 20, 150, 46, "Drop tile A on B", fill="#ede8fb", stroke="#8a74d6", tcolor="#2f2370")
b += box(210, 20, 170, 46, "Cache hit?", "key = sorted names", fill="#fff7d6", stroke="#c9a227", tcolor="#5b4600")
b += box(420, 20, 190, 46, "Use cached element", fill="#e1f3e6", stroke="#3f9a5b", tcolor="#14502a")
b += box(20, 120, 150, 56, "RecipeBook", "table, else improvise", fill="#fdeedd", stroke="#d48a2f", tcolor="#6b3d05")
b += box(210, 120, 170, 46, "Model available?", fill="#fff7d6", stroke="#c9a227", tcolor="#5b4600")
b += box(210, 216, 170, 76, "Ask on-device model", "prompt: \"A\" + \"B\" = ?\n10 s timeout; on an echo,\nretry once, hotter", fill="#fdeedd", stroke="#d48a2f", tcolor="#6b3d05")
b += box(420, 220, 190, 56, "Clean, cache, save", "name, emoji, colour fixed;\nsaved to Core Data", fill="#e8f0fb", stroke="#3b6fb6")
b += box(210, 340, 170, 46, "Record result", "toast if new discovery", fill="#e1f3e6", stroke="#3f9a5b", tcolor="#14502a")
b += arrow(170, 43, 210, 43)
b += arrow(380, 43, 420, 43, "yes")
b += arrow(295, 66, 295, 120, "no")
b += arrow(210, 143, 170, 148, "no")
b += arrow(295, 166, 295, 220, "yes")
b += arrow(380, 253, 420, 248, "answer")
b += arrow(210, 253, 110, 176, "error, timeout, echo", dash=True)
b += arrow(95, 176, 215, 355)
b += arrow(515, 276, 380, 360)
b += arrow(515, 66, 515, 66)
open("fig-pipeline.svg", "w").write(svg(630, 410, b))

# Figure: data model
b = ""
def entity(x, y, name, fields):
    h = 46 + 22*len(fields)
    s = f'<rect x="{x}" y="{y}" width="250" height="{h}" rx="8" fill="#ffffff" stroke="#3b6fb6" stroke-width="1.6"/>'
    s += f'<path d="M{x},{y+34} L{x},{y+8} Q{x},{y} {x+8},{y} L{x+242},{y} Q{x+250},{y} {x+250},{y+8} L{x+250},{y+34} Z" fill="#3b6fb6"/>'
    s += f'<text x="{x+125}" y="{y+22}" text-anchor="middle" font-size="14" font-weight="700" fill="#fff">{name}</text>'
    for i, (f, t) in enumerate(fields):
        s += f'<text x="{x+14}" y="{y+54+i*22}" font-size="12" fill="#222">{f}</text><text x="{x+236}" y="{y+54+i*22}" text-anchor="end" font-size="12" fill="#777">{t}</text>'
    return s
b += entity(20, 20, "ElementEntity", [("id", "UUID"), ("name", "String"), ("emoji", "String"), ("colorHex", "String"), ("elementDescription", "String"), ("isFavorite", "Boolean"), ("discoveredAt", "Date"), ("mode", "String, default classic")])
b += entity(320, 20, "CombinationEntity", [("key", "String  (\"fire+water\")"), ("resultName", "String"), ("resultEmoji", "String"), ("resultColorHex", "String"), ("resultDescription", "String"), ("mode", "String, default classic")])
b += '<text x="295" y="270" text-anchor="middle" font-size="11" fill="#666">No relationship between the entities: a combination stores the result by value,</text>'
b += '<text x="295" y="285" text-anchor="middle" font-size="11" fill="#666">and both are filtered by the mode attribute.</text>'
open("fig-datamodel.svg", "w").write(svg(590, 300, b))

# Figure: screens map
b = ""
b += box(215, 20, 180, 50, "ContentView", "TabView, @SceneStorage", fill="#e1f3e6", stroke="#3f9a5b", tcolor="#14502a")
for i, (t, s) in enumerate([("Craft", "canvas, tray, toast"), ("Discoveries", "list, search, export"), ("Atlas", "map of pins")]):
    b += box(20 + i*200, 130, 170, 50, t, s, fill="#ede8fb", stroke="#8a74d6", tcolor="#2f2370")
    b += arrow(305, 70, 105 + i*200, 130)
b += box(20, 240, 170, 46, "SettingsView", "sheet from Craft", fill="#fff7d6", stroke="#c9a227", tcolor="#5b4600")
b += box(220, 240, 170, 46, "ElementDetailView", "pushed or sheet", fill="#fdeedd", stroke="#d48a2f", tcolor="#6b3d05")
b += arrow(105, 180, 105, 240, "sheet")
b += arrow(305, 180, 305, 240, "push")
b += arrow(505, 180, 340, 240, "sheet", dash=True)
open("fig-screens.svg", "w").write(svg(600, 306, b))
