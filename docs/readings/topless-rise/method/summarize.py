"""Join the locked H-rise-code readings (out/*.txt) with the final report and write summary.csv."""
import csv, re, sys
from collections import Counter, defaultdict

REPORT = '../final-report.csv'
lines = open(REPORT).read().splitlines()
hi = next(i for i, l in enumerate(lines) if l.startswith('run_id,'))
report = {}
for r in csv.DictReader(lines[hi:]):
    if r['treatment'] not in ('rise', 'capped', 'none'):
        break
    report[r['run_id']] = r
assert len(report) == 162, len(report)

worlds = {}
for row in csv.reader(open('worlds.csv')):
    worlds[row[0]] = dict(first=row[5], fifth=row[6], last=row[7])

engine = {(r, e): d for r, e, d in csv.reader(open('sample_depths.csv'))}

WORLD = re.compile(r'^epoch (\d+): (?:deepest solid rung (\d+)(?: or more)?, dominant deepest solver on (\d+) cells|no rung held by a tenth)')
BEAR = re.compile(r'^load-bearing bytes at depth \S+(?: or more)?: (\d+)')
LABELS = {'new code': 'new code', 'co-option': 'co-option', 'neither': 'neither',
          'no rise in depth': 'no rise in depth', 'unread': 'unread'}

def parse(path):
    text = open(path).read().splitlines()
    out, cur = [], None
    for i, l in enumerate(text):
        m = WORLD.match(l)
        if m:
            cur = dict(epoch=m[1], depth=m[2] or '', cells=m[3] or '', count='', positions='', tape='')
            out.append(cur)
            continue
        m = BEAR.match(l)
        if m and cur is not None:
            cur['count'] = m[1]
        if l.startswith('  hex:') and cur is not None:
            cur['tape'] = 'hex:' + l.split('hex:')[1]
        if l.startswith('  positions') and cur is not None:
            cur['positions'] = l[len('  positions'):].strip()
    label = next(l for l in text if l.startswith('H-rise-code')).split(': ', 1)[1]
    short = next(v for k, v in LABELS.items() if label.startswith(k))
    assert len(out) == 3
    return out, short

rows = []
for rid in sorted(report, key=int):
    rep = report[rid]
    ws, label = parse(f'out/{rid}.txt')
    for w, key in zip(ws, ('first', 'fifth', 'last')):
        assert w['epoch'] == worlds[rid][key], (rid, key)
    row = dict(run_id=rid, parent=rep['parent'], arm=rep['treatment'], deep_parent=rep['deep_parent'],
               rises_late=rep['rises'], extinct=rep['extinct'], ceilinged=rep['ceilinged'],
               rise_bar=rep['rise_bar'], fifth_decile_median=rep['fifth_decile_depth'],
               last_decile_median=rep['last_decile_depth'])
    for w, key in zip(ws, ('first', 'fifth', 'last')):
        row[f'{key}_epoch'] = w['epoch']
        row[f'{key}_depth'] = w['depth'] if w['depth'] != '' else 'none'
        row[f'{key}_solver_cells'] = w['cells']
        row[f'{key}_load_bearing'] = w['count']
        row[f'{key}_engine_depth'] = engine.get((rid, w['epoch']), '')
    for w, key in zip(ws, ('first', 'fifth', 'last')):
        row[f'{key}_solver'] = w['tape']
        row[f'{key}_positions'] = w['positions']
    row['locked_subset'] = ''
    row['label'] = label
    rows.append(row)

rising_rise_parents = {r['parent'] for r in rows if r['arm'] == 'rise' and r['rises_late'] == 'true'}
for r in rows:
    r['locked_subset'] = 'true' if r['parent'] in rising_rise_parents else 'false'

with open('summary.csv', 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
    w.writeheader()
    w.writerows(rows)

order = ['new code', 'co-option', 'neither', 'no rise in depth', 'unread']
for arm in ('rise', 'capped', 'none'):
    c = Counter(r['label'] for r in rows if r['arm'] == arm)
    print(arm, {k: c[k] for k in order})
print('rising late:')
for arm in ('rise', 'capped'):
    c = Counter(r['label'] for r in rows if r['arm'] == arm and r['rises_late'] == 'true')
    print(arm, {k: c[k] for k in order})
