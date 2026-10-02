import csv, json, sys
from collections import defaultdict
S = sys.argv[1]
rows = defaultdict(list)
with open(f"{S}/meta-stack/offline/data/samples.csv") as f:
    for r in csv.DictReader(f):
        rows[int(r["run_id"])].append(r)
TASKS = ["echo","not","nand","and","orn","or","andn","nor","xor","equ"]
LOWER = TASKS[:8]
def num(v):
    try: return float(v)
    except: return None
def first(samples, key, k=5):
    run = []
    for r in samples:
        v = num(r[key])
        run = run + [int(r["epoch"])] if (v is not None and v >= 0.1) else []
        if len(run) >= k: return run[0]
    return None
stored = [20010] + list(range(21000, 60001, 1000))
out = {}
for rid, s in sorted(rows.items()):
    fe = {t: first(s, t) for t in TASKS}
    deep = min([e for e in (fe["xor"], fe["equ"]) if e is not None])
    deep_rung = "xor" if fe["xor"] == deep else "equ"
    lower_before = {t: e for t in LOWER if (e := fe[t]) is not None and e <= deep}
    lower_any = {t: e for t in LOWER if (e := fe[t]) is not None}
    last_t = max(lower_before, key=lambda t: lower_before[t])
    e_last = lower_before[last_t]
    e_last_any_t = max(lower_any, key=lambda t: lower_any[t])
    before = max(e for e in stored if e <= e_last)
    after = min(e for e in stored if e > deep)
    first_deep_cap = next((int(r["epoch"]) for r in s if num(r["deep"]) and num(r["deep"]) > 0), None)
    first_deep_k1 = next((int(r["epoch"]) for r in s if (num(r["xor"]) or 0) >= 0.1 or (num(r["equ"]) or 0) >= 0.1), None)
    out[rid] = dict(first_epochs=fe, deep_epoch=deep, deep_rung=deep_rung, last_lower=last_t, e_last=e_last,
                    last_lower_any=e_last_any_t, e_last_any=lower_any[e_last_any_t],
                    pre_world=before, post_world=after, end_world=60000,
                    first_sample_deep_capability=first_deep_cap, first_sample_deep_share_tenth=first_deep_k1)
    print(rid, json.dumps(out[rid]))
json.dump(out, open(f"{S}/meta-stack/offline/data/epochs.json","w"), indent=1)
