#!/usr/bin/env python3
"""Exact straight odds and paired seeded simulations; no game state or saves are changed."""
import argparse
from collections import Counter
from fractions import Fraction
from itertools import combinations_with_replacement
import json
from math import factorial, prod, sqrt
from pathlib import Path
import random

DICE = 6
SIDES = 6
OUTCOMES = SIDES ** DICE
STATES = list(combinations_with_replacement(range(1, SIDES + 1), DICE))
INDEX = {state: i for i, state in enumerate(STATES)}
WEIGHTS = [factorial(DICE) // prod(factorial(n) for n in Counter(state).values()) for state in STATES]


def longest(state):
    """Only consecutive unique faces count; there is no six-to-one wraparound."""
    faces = set(state)
    run = best = 0
    for face in range(1, SIDES + 1):
        run = run + 1 if face in faces else 0
        best = max(best, run)
    return best if best >= 3 else 0


LENGTHS = [longest(state) for state in STATES]
# Every physical die is selectable, including the last copy of a face.
TRANSITIONS = [
    [[INDEX[tuple(sorted(state[:die] + (face,) + state[die + 1:]))]
      for face in range(1, SIDES + 1)] for die in range(DICE)]
    for state in STATES
]


def solve(mode, rewards, rerolls):
    """Backward induction chooses stop or a reroll using exact integer scores."""
    base = SIDES if mode == "single" else OUTCOMES
    values = [list(rewards)]
    actions = [[-1] * len(STATES)]
    for left in range(1, rerolls + 1):
        previous = values[-1]
        full_score = sum(w * v for w, v in zip(WEIGHTS, previous))
        next_values, next_actions = [], []
        for i, state in enumerate(STATES):
            best, choice = rewards[i] * base ** left, -1
            candidates = [(0, full_score)] if mode == "all" else [
                (die, sum(previous[j] for j in TRANSITIONS[i][die]))
                for die in range(DICE) if die == 0 or state[die] != state[die - 1]
            ]
            for die, score in candidates:
                if score > best:  # Stop wins ties; pointless rerolls cost treasure progress.
                    best, choice = score, die
            next_values.append(best)
            next_actions.append(choice)
        values.append(next_values)
        actions.append(next_actions)
    expected = Fraction(sum(w * v for w, v in zip(WEIGHTS, values[-1])), OUTCOMES * base ** rerolls)
    return expected, actions


def simulate(mode, actions, initial, replacements, full_rolls, rerolls):
    """Paired starts and pre-drawn randomness avoid differences from RNG consumption."""
    histogram = Counter()
    used = 0
    for trial, start in enumerate(initial):
        state = start
        for step in range(rerolls):
            action = actions[rerolls - step][state]
            if action < 0:
                break
            state = TRANSITIONS[state][action][replacements[step][trial]] if mode == "single" else full_rolls[step][trial]
            used += 1
        histogram[LENGTHS[state]] += 1
    return histogram, used / len(initial)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--trials", type=int, default=1_000_000)
    parser.add_argument("--seed", type=int, default=20261030)
    parser.add_argument("--rerolls", type=int, default=2)
    parser.add_argument("--mode", choices=["single", "all", "both"], default="both")
    parser.add_argument("--output", type=Path, default=Path("test-output/straight-rerolls-20261030.json"))
    args = parser.parse_args()
    modes = ["single", "all"] if args.mode == "both" else [args.mode]
    assert args.trials > 0 and 0 <= args.rerolls <= 4
    assert len(STATES) == 462 and sum(WEIGHTS) == OUTCOMES
    assert sum(w for w, length in zip(WEIGHTS, LENGTHS) if length == 6) == factorial(6)
    rng = random.Random(args.seed)
    initial = rng.choices(range(len(STATES)), weights=WEIGHTS, k=args.trials)
    replacements = [rng.choices(range(SIDES), k=args.trials) for _ in range(args.rerolls)]
    full_rolls = [rng.choices(range(len(STATES)), weights=WEIGHTS, k=args.trials) for _ in range(args.rerolls)] if "all" in modes else []
    result = {
        "assumptions": f"Six fair independent d6; one initial throw plus {args.rerolls} paid rerolls; one skill per turn; no tarot, relic, gem, auto-attack or Perfect changes. Old all-reroll changes all six dice. Players may stop early. Threshold rows each optimize that threshold, not one common play policy.",
        "trials": args.trials, "seed": args.seed, "rerolls": args.rerolls, "modes": modes,
        "thresholds": [], "longest_policy": {}, "rules_crosscheck": [
            {"dice": list(state), "longest": length} for state, length in zip(STATES, LENGTHS)
        ],
    }
    for target in range(3, 7):
        rewards = [int(length >= target) for length in LENGTHS]
        first = Fraction(sum(w * reward for w, reward in zip(WEIGHTS, rewards)), OUTCOMES)
        row = {"at_least": target, "opening": float(first)}
        for mode in modes:
            exact, actions = solve(mode, rewards, args.rerolls)
            histogram, used = simulate(mode, actions, initial, replacements, full_rolls, args.rerolls)
            observed = sum(n for length, n in histogram.items() if length >= target) / args.trials
            error = abs(observed - float(exact))
            assert error <= 6 * sqrt(float(exact) * (1 - float(exact)) / args.trials) + 1 / args.trials
            if mode == "all":
                assert exact == 1 - (1 - first) ** (args.rerolls + 1)
            row[mode] = {"exact": float(exact), "fraction": str(exact), "simulated": observed, "mean_rerolls": used}
        result["thresholds"].append(row)
        summary = ", ".join(f'{mode} {row[mode]["exact"]:.4%}' for mode in modes)
        print(f'{target}+: opening {float(first):.4%}, {summary}')
    # A single policy for an apples-to-apples resulting skill distribution.
    for mode in modes:
        exact, actions = solve(mode, LENGTHS, args.rerolls)
        histogram, used = simulate(mode, actions, initial, replacements, full_rolls, args.rerolls)
        result["longest_policy"][mode] = {"mean_length_exact": float(exact), "fraction": str(exact), "mean_rerolls": used, "distribution": {str(length): histogram[length] / args.trials for length in [0, 3, 4, 5, 6]}}
        print(f"Maximize length / {mode}: {float(exact):.6f}; final lengths {result['longest_policy'][mode]['distribution']}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(f"Saved {args.output}; {args.trials:,} paired simulated turns per policy; exact DP verified.")


if __name__ == "__main__":
    main()
