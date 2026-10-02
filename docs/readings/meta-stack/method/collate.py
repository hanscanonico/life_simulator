import json, re, csv, sys, os
O = sys.argv[1]
ep = json.load(open(f"{O}/data/epochs.json"))
tapes = {}
for line in open(f"{O}/distance/tapes.txt"):
    p = line.split()
    tapes[p[0]] = dict(pre=int(p[1]), post=int(p[2]), dom=p[3], deep=p[4])
def plant(run, rung):
    f = f"{O}/plant/{run}-{rung}.txt"
    if not os.path.exists(f): return None
    t = open(f).read()
    seeds = re.findall(r"seed (\d+):\n((?:  e\+.*\n)+)", t)
    per = []
    for s, body in seeds:
        last = body.strip().splitlines()[-1]
        m = re.search(r"planted\s+(\d+)\s+control\s+(\d+)", last)
        e500 = re.search(r"e\+500\s+planted\s+(\d+)\s+control\s+(\d+)", body)
        per.append((int(s), int(m.group(1)), int(m.group(2)), int(e500.group(2))))
    v = re.search(r"verdict: (\w+)", t).group(1)
    wiped = re.search(r"; (\d+) other cells", t).group(1)
    return v, per, int(wiped)
rows = []
for run in sorted(tapes):
    e = ep[run]; t = tapes[run]
    dist = open(f"{O}/distance/{run}.txt").read()
    d = int(re.search(r"substitutions (\d+)", dist).group(1))
    ed = int(re.search(r"edit distance (\d+)", dist).group(1))
    orders = open(f"{O}/orders/{run}.txt").read()
    dom_credit = re.search(r"^dominant .*credit (\S+)\s+units (\d+)", orders, re.M).groups()
    deep_credit = re.search(r"^deep .*credit (\S+)\s+units (\d+)", orders, re.M).groups()
    neutral = re.search(r"neutral-or-better order: (\S+)", orders).group(1)
    fewest = re.search(r"make it deep: (.*?)(?: \(|$)", orders, re.M).group(1)
    nearest = re.search(r"nearest tape to the deep solver at (\d+)", orders).group(1)
    pth = open(f"{O}/paths/{run}-k3.txt").read()
    shortest = re.search(r"^shortest: (.*?);", pth, re.M).group(1)
    for rung in ("xor", "equ"):
        p = plant(run, rung)
        if p is None: continue
        v, per, wiped = p
        rows.append(dict(run=run, rung=rung, deep_epoch=e["deep_epoch"], deep_rung=e["deep_rung"],
            last_lower=e["last_lower"], e_last=e["e_last"], pre_world=t["pre"], post_world=t["post"],
            dominant=t["dom"], dominant_credit=dom_credit[0], first_deep_solver=t["deep"], deep_credit=deep_credit[0],
            substitutions=d, edit_distance=ed, multi_step="yes" if d >= 2 else "no",
            credited_order="no", neutral_or_better_order={"Some(true)":"yes","Some(false)":"no"}.get(neutral, neutral),
            fewest_of_these_to_deep=("0 (dominant already deep)" if "equ" in dom_credit[0] or "xor" in dom_credit[0] else fewest),
            paths_k3_shortest=("0 (dominant already deep)" if "equ" in dom_credit[0] or "xor" in dom_credit[0] else shortest),
            nearest_pre_world_tape=int(nearest),
            planted_tape=re.search(r"hex:[0-9a-f]+", open(f"{O}/plant/{run}-{rung}.txt").readline()).group(0),
            note=("extension: xor's own first solver (e29000); the first deep solver carries equ only" if (run, rung) == ("4890", "xor") else ""),
            heritability=v, wiped=wiped,
            seeds=" ".join(f"{s}:{pl}/{c}(e+500 control {c5})" for s, pl, c, c5 in per)))
w = csv.DictWriter(open(f"{O}/summary.csv", "w"), fieldnames=list(rows[0].keys()))
w.writeheader(); w.writerows(rows)
for r in rows: print(r["run"], r["rung"], r["substitutions"], r["neutral_or_better_order"], r["fewest_of_these_to_deep"], r["paths_k3_shortest"], r["heritability"], r["seeds"])
