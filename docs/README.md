# Mini project submission

| File | What it is |
| --- | --- |
| `Element-Mini-Project-Report.pdf` | Project report in the K. J. Somaiya format (23 pages) |
| `Element-Poster.pdf` | A2 poster (`Element-Poster.png` is a preview image) |
| `Element-App-Project.zip` | Complete app project folder: Xcode project, source, README, screenshots |
| `src/` | Sources for the report and poster (HTML, CSS, Python build scripts, diagrams) |

## Rebuilding the PDFs

```
pip install weasyprint qrcode
cd docs/src
python3 diagrams.py && python3 report.py && python3 poster.py
```

To print a guide's name on the report cover, set `GUIDE` at the top of `src/report.py` before building.
