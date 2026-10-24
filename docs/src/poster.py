"""Builds the Element poster (A2 portrait). Run: python3 diagrams.py && python3 poster.py"""
from weasyprint import HTML
import subprocess

css = '''
@page { size: 420mm 594mm; margin: 0; }
* { box-sizing: border-box; }
html { font: 16pt/1.38 "Liberation Sans", Arial, sans-serif; color: #1c1b29; }
body { margin: 0; width: 420mm; height: 594mm; position: relative; background: #f4f2fb; }
.top { height: 38mm; background: #fff; display: flex; align-items: center; justify-content: space-between; padding: 0 16mm; border-bottom: 2.2mm solid #d6202f; }
.top img.l { height: 22mm; } .top img.r { height: 26mm; }
.top .mid { text-align: center; font: 600 15pt "Liberation Serif", serif; color: #444; letter-spacing: .3mm; }
.hero { height: 88mm; background: linear-gradient(120deg, #4b2fb8 0%, #7a54e6 55%, #b27df0 100%); color: #fff; padding: 14mm 18mm 0; position: relative; overflow: hidden; }
.hero h1 { margin: 0; font: 700 74pt/1 "Liberation Sans", sans-serif; letter-spacing: -1mm; }
.hero .tag { width: 270mm; font: 400 23pt/1.25 "Liberation Sans", sans-serif; margin-top: 4mm; opacity: .95; }
.hero .who { position: absolute; right: 18mm; top: 16mm; text-align: right; font-size: 18pt; line-height: 1.5; }
.hero .who b { font-size: 24pt; display: block; }
.hero .emojis { position: absolute; right: 18mm; bottom: 12mm; font-size: 34pt; letter-spacing: 3mm; opacity: .9; font-family: "Noto Color Emoji"; }
.stats { display: flex; margin: -13mm 14mm 0; position: relative; gap: 6mm; }
.stat { flex: 1; background: #fff; border-radius: 4mm; padding: 5mm 4mm; text-align: center; box-shadow: 0 1mm 3mm rgba(60,40,140,.25); border-top: 2mm solid #d6202f; }
.stat b { display: block; font-size: 34pt; color: #4b2fb8; line-height: 1.1; }
.stat span { font-size: 13pt; color: #555; }
.cols { display: table; width: 406mm; border-spacing: 8mm 0; margin: 8mm 0 0 -1mm; table-layout: fixed; }
.col { display: table-cell; vertical-align: top; }
.card { margin-bottom: 6mm; background: #fff; border-radius: 4mm; padding: 6mm 8mm; box-shadow: 0 .6mm 2mm rgba(60,40,140,.18); }
.card h2 { margin: 0 0 4mm; font: 700 25pt/1.1 "Liberation Sans", sans-serif; color: #4b2fb8; display: flex; align-items: center; }
.card h2::before { content: ""; width: 3mm; height: 9mm; background: #d6202f; border-radius: 1mm; margin-right: 4mm; }
.card p { margin: 0 0 3mm; } .card ul { margin: 0; padding-left: 7mm; } .card li { margin-bottom: 2mm; }
.card img.fig { width: 100%; display: block; margin-top: 2mm; }
.cap { font-size: 12pt; color: #666; text-align: center; margin-top: 1mm; }
code { font: 14.5pt "Liberation Mono", monospace; background: #efeafc; padding: 0 1.2mm; border-radius: 1mm; color: #3a2490; }
.phones { display: flex; gap: 5mm; justify-content: center; }
.phones img { width: 31%; border-radius: 5mm; border: .6mm solid #cfc8ea; box-shadow: 0 1mm 3mm rgba(0,0,0,.2); }
.phones.two img { width: 46%; }
.card table { display: table; width: 100%; border-collapse: collapse; font-size: 14pt; }
th { background: #4b2fb8; color: #fff; text-align: left; padding: 2mm 3mm; }
td { padding: 2mm 3mm; border-bottom: .3mm solid #ddd; vertical-align: top; }
.dark { background: #2a1d6e; color: #fff; } .dark h2 { color: #fff; } .dark code { background: rgba(255,255,255,.15); color: #fff; }
.foot { position: absolute; bottom: 0; left: 0; right: 0; height: 30mm; background: #d6202f; color: #fff; display: flex; align-items: center; justify-content: space-between; padding: 0 16mm; }
.foot .t { font-size: 17pt; line-height: 1.5; } .foot b { font-size: 21pt; }
.foot img { height: 22mm; background: #fff; padding: 1.5mm; border-radius: 2mm; }
'''

body = '''
<div class="top"><img class="l" src="assets/somaiya.png"/>
<div class="mid">K. J. Somaiya School of Engineering, Mumbai<br/>Department of Computer Engineering &middot; Mini Project, Semester VII, 2026-2027</div>
<img class="r" src="assets/trust.png"/></div>
<div class="hero"><h1>Element</h1>
<div class="tag">Combine anything. Discover what the world hasn't named yet.<br/>An iOS crafting game that runs its AI entirely on the phone.</div>
<div class="who"><b>Pradyum Mistry</b>Roll No. 16010123236<br/>B.Tech Computer Engineering</div>
<div class="emojis">🔥 💧 🌍 💨 ⚗️</div></div>
<div class="stats">
<div class="stat"><b>~2,700</b><span>lines of Swift</span></div>
<div class="stat"><b>16</b><span>source files</span></div>
<div class="stat"><b>125</b><span>offline recipes</span></div>
<div class="stat"><b>2</b><span>game worlds</span></div>
<div class="stat"><b>0</b><span>network calls or packages</span></div></div>
<div class="cols">
<div class="col">
<div class="card"><h2>The idea</h2>
<p>Little Alchemy uses a fixed list of recipes. Infinite Craft lets a language model decide what two things make. Element asks whether that can work with no server at all.</p>
<p>The player drags two elements together. If the pair is new, Apple's on-device <b>Foundation Models</b> framework invents the result. It needs no API key and no connection, and the player's combinations stay on the phone.</p></div>
<div class="card"><h2>Objectives</h2><ul>
<li>A drag and drop crafting canvas in SwiftUI</li>
<li>Structured output from the on-device model</li>
<li>A combination that never ends in an error</li>
<li>Saved discoveries and a combination cache</li>
<li>Two worlds with separate progress</li>
<li>A searchable log with JSON export, and a map</li></ul></div>
<div class="card"><h2>Features</h2><ul>
<li>Tap a tile, or press and hold to drag it out of the tray</li>
<li>Drop one tile on another to combine; double-tap to duplicate</li>
<li>Drag a tile back to the tray to remove it</li>
<li>Searchable, sortable tray and a favourites filter</li>
<li>Recipes for each element, JSON export of the log</li>
<li>Atlas map with a stable pin for every element</li>
<li>Light, dark and reduce motion settings</li></ul></div>
</div>
<div class="col">
<div class="card"><h2>How a pair is resolved</h2>
<img class="fig" src="fig-pipeline.svg" style="width:90%;margin:2mm auto 0"/>
<div class="cap">Cache first, then the model, then the recipe book</div></div>
<div class="card"><h2>Guided generation</h2>
<p>A <code>@Generable</code> struct makes the model return a name, an emoji, a colour and a description in a fixed shape.</p>
<p>The app still treats the output as untrusted. It strips stray punctuation from names, keeps one real emoji, forces a valid six digit hex colour, and reuses an existing element when the name matches.</p></div>
<div class="card dark"><h2>When things go wrong</h2><ul>
<li>Model unavailable: a banner explains why, and the recipe book answers</li>
<li>No answer in 10 seconds: request cancelled, recipe book answers</li>
<li>Model repeats an input: one retry, hotter, then fallback</li>
<li>Fallback results are not cached, so the model can try again later</li></ul></div>
<div class="card"><h2>Two worlds</h2>
<table><tr><th></th><th>Classic</th><th>Periodic</th></tr>
<tr><td>Start</td><td>Fire, Water, Earth, Air</td><td>8 real elements</td></tr>
<tr><td>Example</td><td>Water + Earth = Plant</td><td>Sodium + Chlorine = Salt</td></tr>
<tr><td>Prompt</td><td>Most obvious result</td><td>Real compound or material</td></tr>
<tr><td>Offline</td><td>93 recipes</td><td>32 recipes</td></tr></table>
</div>
</div>
<div class="col">
<div class="card"><h2>Screens</h2>
<div class="phones"><img src="assets/craft.png"/><img src="assets/discoveries.png"/><img src="assets/atlas.png"/></div>
<div class="cap">Craft, Discoveries and Atlas (Classic mode)</div>
<div class="phones" style="margin-top:5mm"><img src="assets/modes.png"/><img src="assets/periodic-craft.png"/><img src="assets/periodic-discoveries.png"/></div>
<div class="cap">Mode switcher and the Periodic world</div></div>
<div class="card"><h2>Architecture</h2>
<img class="fig" src="fig-architecture.svg"/>
<div class="cap">One <code>@Observable</code> view model between the views and three data sources</div></div>
<div class="card"><h2>Limits and next steps</h2><ul>
<li>Needs iOS 26.5 and Apple Intelligence for generated results</li>
<li>Answer quality was not measured</li>
<li>No automated tests yet. The cache key and fallback rules come first</li></ul></div>
</div></div>
<div class="foot"><div class="t"><b>Built with</b> SwiftUI &middot; Foundation Models &middot; Core Data &middot; MapKit &middot; Observation<br/>Source code and report: github.com/altf4-games/Element</div>
<img src="assets/qr.png"/></div>
'''
open("poster.html", "w").write(f'<!doctype html><html><head><meta charset="utf-8"><title>Element: Poster</title><style>{css}</style></head><body>{body}</body></html>')
HTML("poster.html", base_url=".").write_pdf("../Element-Poster.pdf")
subprocess.run(["pdftoppm", "-r", "90", "-png", "-singlefile", "../Element-Poster.pdf", "../Element-Poster"], check=True)
print("ok")
