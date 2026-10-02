//! Descriptive readings beside the locked substitution distance (not locked, not the
//! entry's): the orders over a distance past the landscape lattice's 16 sites, the fewest
//! of the substitutions toward the deep solver that already make the dominant tape deep,
//! and the pre-deep world's nearest tape to the deep solver.
use landscape::census::cells;
use landscape::score::{assayed, par_map, Rungs, Scorer, DEEP};
use landscape::stored::{read_params, Stored};
use landscape::tape::{self, hamming, hex, show};
use std::collections::HashMap;
use std::path::PathBuf;

const CAP: usize = 60_000_000;

fn apply(start: &[u8], sites: &[(usize, u8)], subset: u64) -> Vec<u8> {
    let mut t = start.to_vec();
    for (bit, (at, byte)) in sites.iter().enumerate() {
        if subset & (1 << bit) != 0 {
            t[*at] = *byte;
        }
    }
    t
}

/// Level-synchronous search of the subset lattice: is the full set reached from the empty
/// one by single additions, every step allowed by `step(units before, units after)`?
/// Some(true/false), or None past CAP evaluations.
fn reach(
    start: &[u8],
    sites: &[(usize, u8)],
    scorer: &Scorer,
    step: &(dyn Fn(u32, u32) -> bool + Sync),
) -> (Option<bool>, usize, Vec<usize>) {
    let d = sites.len();
    let full: u64 = (1u64 << d) - 1;
    let mut frontier: HashMap<u64, u32> = HashMap::new();
    frontier.insert(0, scorer.paid_units(start));
    let mut evaluated = 0usize;
    let mut sizes = vec![1usize];
    for _ in 0..d {
        let mut cand: Vec<u64> = frontier
            .keys()
            .flat_map(|s| (0..d).filter(move |b| s & (1 << b) == 0).map(move |b| s | (1 << b)))
            .collect();
        cand.sort_unstable();
        cand.dedup();
        evaluated += cand.len();
        if evaluated > CAP {
            return (None, evaluated, sizes);
        }
        let units = par_map(&cand, |t| scorer.paid_units(&apply(start, sites, *t)));
        let mut next = HashMap::new();
        for (t, u) in cand.iter().zip(units) {
            let ok = (0..d).filter(|b| t & (1 << b) != 0).any(|b| {
                frontier
                    .get(&(t & !(1 << b)))
                    .is_some_and(|from| step(*from, u))
            });
            if ok {
                next.insert(*t, u);
            }
        }
        sizes.push(next.len());
        if next.is_empty() {
            return (Some(false), evaluated, sizes);
        }
        frontier = next;
    }
    (Some(frontier.contains_key(&full)), evaluated, sizes)
}

fn combinations(n: usize, k: usize, f: &mut dyn FnMut(&[usize])) {
    fn go(n: usize, k: usize, from: usize, cur: &mut Vec<usize>, f: &mut dyn FnMut(&[usize])) {
        if cur.len() == k {
            f(cur);
            return;
        }
        for i in from..n {
            cur.push(i);
            go(n, k, i + 1, cur, f);
            cur.pop();
        }
    }
    go(n, k, 0, &mut Vec::new(), f)
}

fn main() {
    let a: Vec<String> = std::env::args().skip(1).collect();
    let params_path = PathBuf::from(&a[0]);
    let pre = PathBuf::from(&a[1]);
    let params = read_params(&params_path).unwrap();
    let scorer = Scorer::for_params(&params);
    let dom = tape::parse(&a[2], 32).unwrap();
    let deep = tape::parse(&a[3], 32).unwrap();
    let (ud, ue) = (scorer.paid_units(&dom), scorer.paid_units(&deep));
    let d = hamming(&dom, &deep).unwrap();
    println!("dominant {}  credit {}  units {ud}", show(&dom), scorer.solid(&dom).names());
    println!("deep     {}  credit {}  units {ue}", show(&deep), scorer.solid(&deep).names());
    println!("substitutions {d}");
    let sites: Vec<(usize, u8)> = (0..32).filter(|i| dom[*i] != deep[*i]).map(|i| (i, deep[i])).collect();

    // Orders over all d substitutions.
    if ue < ud + d as u32 {
        println!("credited order: none (proof: a credited order gains >= 1 unit a step, needs {} units, the deep solver has {ue} against {ud})", ud + d as u32);
    } else {
        let (r, n, sizes) = reach(&dom, &sites, &scorer, &|from, to| to > from);
        println!("credited order: {r:?} ({n} subsets assayed; reachable per level {sizes:?})");
    }
    if ue < ud {
        println!("neutral-or-better order: none (the deep solver itself earns {ue} < {ud})");
    } else {
        let (r, n, sizes) = reach(&dom, &sites, &scorer, &|_, to| to >= ud);
        println!("neutral-or-better order: {r:?} ({n} subsets assayed; reachable per level {sizes:?})");
    }

    // The fewest of these substitutions that make the dominant tape deep.
    let mut found = false;
    for k in 1..=d.min(7) {
        let mut subsets: Vec<Vec<usize>> = Vec::new();
        combinations(d, k, &mut |c| subsets.push(c.to_vec()));
        let hits: Vec<Option<Rungs>> = par_map(&subsets, |c| {
            let m: u64 = c.iter().map(|b| 1u64 << b).sum();
            let t = apply(&dom, &sites, m);
            if scorer.on_set(&t, 0).meets(DEEP) {
                let s = scorer.solid(&t);
                s.meets(DEEP).then_some(s)
            } else {
                None
            }
        });
        let hit: Vec<(&Vec<usize>, Rungs)> = subsets.iter().zip(&hits).filter_map(|(c, h)| h.map(|h| (c, h))).collect();
        if !hit.is_empty() {
            let mut credited = 0;
            let mut neutral = 0;
            for (c, _) in &hit {
                let sub: Vec<(usize, u8)> = c.iter().map(|b| sites[*b]).collect();
                let (cr, _, _) = reach(&dom, &sub, &scorer, &|f, t| t > f);
                let (ne, _, _) = reach(&dom, &sub, &scorer, &|_, t| t >= ud);
                credited += (cr == Some(true)) as usize;
                neutral += (ne == Some(true)) as usize;
            }
            let (c, r) = hit[0];
            let ex: Vec<String> = c.iter().map(|b| format!("{}:{}", sites[*b].0, show(&[sites[*b].1]))).collect();
            println!(
                "fewest of the {d} that make it deep: {k} ({} of {} subsets; {credited} with a credited order, {neutral} neutral or better); e.g. {} -> {}",
                hit.len(), subsets.len(), ex.join(" "), r.names()
            );
            found = true;
            break;
        }
    }
    if !found {
        println!("fewest of the {d} that make it deep: more than {}", d.min(7));
    }

    // The pre-deep world's nearest metabolism tape to the deep solver.
    let stored = Stored::load(&pre, &params_path).unwrap();
    let world = stored.world(0).unwrap();
    let mut counts: HashMap<Vec<u8>, u64> = HashMap::new();
    let mut dists = Vec::new();
    for (x, y) in cells(&world) {
        let t = assayed(&world, x, y);
        *counts.entry(t.to_vec()).or_default() += 1;
        dists.push(hamming(t, &dom).unwrap());
    }
    dists.sort_unstable();
    let mut best: Vec<(&Vec<u8>, u64, usize)> = counts.iter().map(|(t, n)| (t, *n, hamming(t, &deep).unwrap())).collect();
    best.sort_by_key(|(t, n, h)| (*h, std::cmp::Reverse(*n), (*t).clone()));
    let min = best[0].2;
    let at_min: u64 = best.iter().filter(|b| b.2 == min).map(|b| b.1).sum();
    let within2: u64 = best.iter().filter(|b| b.2 <= 2).map(|b| b.1).sum();
    println!(
        "pre-deep world: the dominant tape's median distance to a cell {}; nearest tape to the deep solver at {min} ({at_min} cells), {within2} cells within 2",
        dists[dists.len() / 2]
    );
    for (t, n, h) in best.iter().take(3) {
        println!("  d={h} n={n} {} credit {} units {}  {}", show(t), scorer.solid(t).names(), scorer.paid_units(t), hex(t));
    }
}
