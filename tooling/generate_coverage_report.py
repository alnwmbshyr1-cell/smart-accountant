from html import escape
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LCOV = ROOT / 'coverage' / 'lcov.info'
OUT = ROOT / 'coverage' / 'html' / 'index.html'

records = []
current = None
for raw in LCOV.read_text(encoding='utf-8').splitlines():
    if raw.startswith('SF:'):
        current = {'file': raw[3:], 'lf': 0, 'lh': 0, 'uncovered': [], 'functions': []}
        records.append(current)
    elif current is not None and raw.startswith('LF:'):
        current['lf'] = int(raw[3:])
    elif current is not None and raw.startswith('LH:'):
        current['lh'] = int(raw[3:])
    elif current is not None and raw.startswith('DA:'):
        parts = raw[3:].split(',')
        if len(parts) >= 2 and int(parts[1]) == 0:
            current['uncovered'].append(int(parts[0]))
    elif current is not None and raw.startswith('FN:'):
        parts = raw[3:].split(',', 1)
        if len(parts) == 2:
            current['functions'].append({'line': int(parts[0]), 'name': parts[1]})

for record in records:
    record['pct'] = 100 * record['lh'] / record['lf'] if record['lf'] else 100

records.sort(key=lambda item: item['pct'])
total_lf = sum(item['lf'] for item in records)
total_lh = sum(item['lh'] for item in records)
overall = 100 * total_lh / total_lf if total_lf else 100
critical = [item for item in records if '/services/' in item['file'] or item['file'].endswith('/main.dart')]

rows = []
for item in records:
    status = 'good' if item['pct'] >= 70 else 'warn'
    uncovered = ', '.join(map(str, item['uncovered'][:30]))
    if len(item['uncovered']) > 30:
        uncovered += f' … (+{len(item["uncovered"]) - 30})'
    rows.append(f'''<tr class="{status}"><td><code>{escape(item['file'])}</code></td><td>{item['lf']}</td><td>{item['lh']}</td><td><strong>{item['pct']:.2f}%</strong></td><td>{len(item['uncovered'])}</td><td><code>{escape(uncovered or 'لا توجد')}</code></td></tr>''')

critical_rows = []
for item in critical:
    critical_rows.append(f'''<tr><td><code>{escape(item['file'])}</code></td><td>{item['pct']:.2f}%</td><td>{len(item['uncovered'])}</td><td><code>{escape(', '.join(map(str, item['uncovered'][:40])) or 'لا توجد')}</code></td></tr>''')

html = f'''<!doctype html>
<html lang="ar" dir="rtl"><head><meta charset="utf-8"><title>Smart Accountant Coverage Report</title>
<style>body{{font-family:Arial,sans-serif;background:#f5f7fb;color:#172033;margin:32px;line-height:1.6}}h1,h2{{color:#0d47a1}}.summary{{display:flex;gap:16px;flex-wrap:wrap;margin:20px 0}}.metric{{background:white;border-radius:12px;padding:16px 22px;box-shadow:0 2px 8px #0001;min-width:160px}}.metric b{{font-size:26px;color:#0d47a1;display:block}}table{{border-collapse:collapse;width:100%;background:white;box-shadow:0 2px 8px #0001}}th,td{{padding:10px;border-bottom:1px solid #e5e7eb;text-align:right;vertical-align:top}}th{{background:#0d47a1;color:white}}tr.warn td{{background:#fff8e1}}tr.good td{{background:#f1f8f4}}code{{direction:ltr;unicode-bidi:embed}}.note{{background:#fff3cd;padding:14px;border-right:5px solid #ffc107;margin:18px 0}}</style></head>
<body><h1>تقرير تغطية اختبارات Smart Accountant</h1><p>تم توليد التقرير من <code>coverage/lcov.info</code> بعد تشغيل المجموعة الكاملة.</p>
<div class="summary"><div class="metric"><b>{overall:.2f}%</b>التغطية الكلية</div><div class="metric"><b>{total_lh}/{total_lf}</b>الأسطر المغطاة</div><div class="metric"><b>{len(records)}</b>ملفات المصدر</div><div class="metric"><b>{sum(len(x['uncovered']) for x in records)}</b>أسطر غير مغطاة</div></div>
<div class="note"><strong>قراءة سريعة:</strong> الملفات الخضراء عند 70% أو أكثر، والملفات الصفراء تحتاج اختبارات إضافية. يعرض التقرير أرقام الأسطر غير المغطاة كما وردت في lcov.</div>
<h2>الخدمات الحرجة</h2><table><tr><th>الملف</th><th>التغطية</th><th>غير مغطى</th><th>أرقام الأسطر</th></tr>{''.join(critical_rows)}</table>
<h2>كل ملفات المصدر</h2><table><tr><th>الملف</th><th>LF</th><th>LH</th><th>التغطية</th><th>عدد غير المغطى</th><th>الأسطر</th></tr>{''.join(rows)}</table>
<h2>ملاحظات منهجية</h2><p>اختبارات Vosk والصوت في هذه الجولة تستخدم بدائل حتمية عند حدود الخدمة؛ لذلك لا تتطلب جهاز Android أو شبكة. التقرير يقيس تغطية Dart المسجلة في lcov ولا يثبت وحده صحة الأجهزة الأصلية أو جودة التعرف الصوتي.</p>
</body></html>'''
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(html, encoding='utf-8')
print(f'Wrote {OUT}')
print(f'Overall coverage: {overall:.2f}% ({total_lh}/{total_lf})')
