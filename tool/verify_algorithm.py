#!/usr/bin/env python3
"""
Algorithm verification for Decant.

Flutter/Dart can't be compiled in every environment, so this script is a
faithful Python port of the *logic* layer (pour engine + best-first solver +
reverse-shuffle level generator). It checks the invariants the Dart code relies
on: pour rules, solvability of every generated level, color conservation, and
that a solver solution actually solves the board.

Run:  python3 tool/verify_algorithm.py
"""
import heapq
import random

CAP = 4


# ---- Pour engine ---------------------------------------------------------- #
def top_run(t):
    if not t:
        return 0, None
    c = t[-1]
    r = 0
    for x in reversed(t):
        if x == c:
            r += 1
        else:
            break
    return r, c


def pourable_count(tubes, i, j):
    if i == j:
        return 0
    src, dst = tubes[i], tubes[j]
    if not src or len(dst) >= CAP:
        return 0
    run, c = top_run(src)
    if dst and dst[-1] != c:
        return 0
    return min(run, CAP - len(dst))


def apply_pour(tubes, i, j):
    n = pourable_count(tubes, i, j)
    if n == 0:
        return None
    c = tubes[i][-1]
    nt = [list(t) for t in tubes]
    del nt[i][len(nt[i]) - n:]
    nt[j].extend([c] * n)
    return nt


def is_complete(t):
    return len(t) == 0 or (len(t) == CAP and len(set(t)) == 1)


def is_solved(tubes):
    return all(is_complete(t) for t in tubes)


def canonical(tubes):
    return tuple(sorted(tuple(t) for t in tubes))


# ---- Best-first solver (mirrors solver.dart) ------------------------------ #
def heuristic(tubes):
    h = 0
    for t in tubes:
        if not t:
            continue
        for k in range(1, len(t)):
            if t[k] != t[k - 1]:
                h += 1
        if not is_complete(t):
            h += 1
    return h


def solve(start, max_expansions=200000):
    if is_solved(start):
        return []
    nodes = [(start, -1, None)]
    visited = {canonical(start)}
    heap = [(heuristic(start), 0)]
    counter = 1
    expansions = 0
    n = len(start)
    while heap and expansions < max_expansions:
        expansions += 1
        _, idx = heapq.heappop(heap)
        tubes = nodes[idx][0]
        for i in range(n):
            src = tubes[i]
            if not src or is_complete(src):
                continue
            run, _ = top_run(src)
            src_uniform = run == len(src)
            for j in range(n):
                if i == j or pourable_count(tubes, i, j) == 0:
                    continue
                if src_uniform and not tubes[j]:
                    continue
                nt = apply_pour(tubes, i, j)
                key = canonical(nt)
                if key in visited:
                    continue
                visited.add(key)
                child = len(nodes)
                nodes.append((nt, idx, (i, j)))
                if is_solved(nt):
                    return reconstruct(nodes, child)
                heapq.heappush(heap, (heuristic(nt), child))
                counter += 1
    return None


def reconstruct(nodes, leaf):
    moves = []
    i = leaf
    while i > 0:
        _, parent, mv = nodes[i]
        moves.append(mv)
        i = parent
    return list(reversed(moves))


# ---- Level generator (mirrors level_generator.dart) ----------------------- #
def config_for(level_id):
    color_count = max(3, min(3 + (level_id - 1) // 3, 11))
    empty_tubes = 1 if color_count >= 8 else 2
    if color_count <= 3:
        diff = 1
    elif color_count == 4:
        diff = 2
    elif color_count <= 6:
        diff = 3
    elif color_count <= 8:
        diff = 4
    else:
        diff = 5
    scramble = color_count * CAP * 3 + 6
    return color_count, empty_tubes, scramble, diff


def reverse_pour(segs, rng):
    n = len(segs)
    sources = [i for i in range(n) if segs[i]]
    if not sources:
        return
    rng.shuffle(sources)
    for p in sources:
        tube = segs[p]
        run, c = top_run(tube)
        whole = run == len(tube)
        max_take = len(tube) if whole else run - 1
        if max_take < 1:
            continue
        dests = [j for j in range(n) if j != p and len(segs[j]) < CAP]
        if not dests:
            continue
        q = rng.choice(dests)
        room = CAP - len(segs[q])
        take = rng.randint(1, min(max_take, room))
        for _ in range(take):
            segs[q].append(tube.pop())
        return


def reverse_shuffle(color_count, empty_tubes, scramble, rng):
    segs = [[c] * CAP for c in range(color_count)] + [[] for _ in range(empty_tubes)]
    for _ in range(scramble):
        reverse_pour(segs, rng)
    return segs


def generate(level_id):
    color_count, empty_tubes, scramble, diff = config_for(level_id)
    rng = random.Random(0x9E3779B9 ^ level_id)
    for _ in range(12):
        segs = reverse_shuffle(color_count, empty_tubes, scramble, rng)
        if is_solved(segs):
            continue
        fragmented = sum(1 for t in segs if t and len(set(t)) > 1)
        if fragmented < 2:
            continue
        if solve(segs) is None:
            continue
        return segs, color_count, empty_tubes, diff
    return reverse_shuffle(color_count, empty_tubes, scramble, rng), color_count, empty_tubes, diff


# ---- Checks --------------------------------------------------------------- #
def unit_checks():
    assert top_run([0, 1, 1, 1]) == (3, 1)
    assert pourable_count([[0, 0, 1, 1], [1, 1]], 0, 1) == 2
    assert pourable_count([[1, 1, 1], [1, 1, 1]], 0, 1) == 1
    assert pourable_count([[0, 0, 1], [2, 2]], 0, 1) == 0
    assert pourable_count([[3, 3, 3, 3], []], 0, 1) == 4
    assert is_solved([[0, 0, 0, 0], [1, 1, 1, 1], []])
    assert not is_solved([[0, 1, 0, 1], [1, 0, 1, 0]])
    out = apply_pour([[0, 1, 1], [1]], 0, 1)
    assert out == [[0], [1, 1, 1]]
    print("  unit checks........... OK")


def generator_checks(n=40):
    seen = {}
    for lid in range(1, n + 1):
        segs, colors, empties, diff = generate(lid)
        assert not is_solved(segs), f"level {lid} starts solved"
        sol = solve(segs)
        assert sol is not None, f"level {lid} unsolvable"
        # color conservation
        counts = {}
        for t in segs:
            for c in t:
                counts[c] = counts.get(c, 0) + 1
        assert len(counts) == colors, f"level {lid} color count mismatch"
        assert all(v == CAP for v in counts.values()), f"level {lid} not conserved"
        # determinism
        again, *_ = generate(lid)
        assert again == segs, f"level {lid} not deterministic"
        # replay the solution → solved
        cur = [list(t) for t in segs]
        for (i, j) in sol:
            cur = apply_pour(cur, i, j)
            assert cur is not None, f"level {lid} illegal solver move"
        assert is_solved(cur), f"level {lid} solution does not solve"
        seen[lid] = (colors, empties, diff, len(sol))
    # difficulty monotonic-ish
    assert seen[1][2] <= seen[40][2]
    print(f"  generated+solved {n} levels... OK")
    sample = [1, 5, 12, 25, 40]
    print("  sample (level: colors, empties, difficulty, solution_len):")
    for s in sample:
        c, e, d, ln = seen[s]
        print(f"    level {s:>2}: {c} colors, {e} empty, diff {d}, {ln} moves")


if __name__ == "__main__":
    print("Verifying Decant logic (Python port):")
    unit_checks()
    generator_checks(40)
    print("ALL CHECKS PASSED")
