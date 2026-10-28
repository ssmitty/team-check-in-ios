/**
 * pairing.mjs
 * Purpose: Produce pairs or one trio for server-side pregame assignment.
 * Exports: makeAssignments
 * Notes: Persistence, authorization, event locking, and scheduling are separate.
 */
import { randomInt } from 'node:crypto';

const EXACT_ROSTER_LIMIT = 18;
const LARGE_ROSTER_ATTEMPTS = 512;

function pairKey(left, right) {
  return JSON.stringify([left, right].sort());
}

function shuffle(values, random) {
  const result = [...values];
  for (let index = result.length - 1; index > 0; index -= 1) {
    const value = random();
    if (!Number.isFinite(value) || value < 0 || value >= 1) {
      throw new Error('Random source must return a number in [0, 1).');
    }
    const other = Math.floor(value * (index + 1));
    [result[index], result[other]] = [result[other], result[index]];
  }
  return result;
}

function repeatCount(group, previousPairs) {
  let count = 0;
  for (let left = 0; left < group.length; left += 1) {
    for (let right = left + 1; right < group.length; right += 1) {
      if (previousPairs.has(pairKey(group[left], group[right]))) count += 1;
    }
  }
  return count;
}

function exactAssignments(players, previousPairs) {
  const memo = new Map();
  function solve(remaining, needsTrio) {
    if (remaining.length === 0) return needsTrio ? null : { groups: [], repeats: 0 };
    if (remaining.length < 2) return null;
    const key = remaining.join(',') + ':' + needsTrio;
    if (memo.has(key)) return memo.get(key);
    const first = remaining[0];
    let best = null;
    function consider(indices, nextNeedsTrio) {
      const selected = new Set(indices);
      const tail = solve(remaining.filter(index => !selected.has(index)), nextNeedsTrio);
      if (!tail) return;
      const group = indices.map(index => players[index]);
      const repeats = tail.repeats + repeatCount(group, previousPairs);
      if (!best || repeats < best.repeats) best = { groups: [group, ...tail.groups], repeats };
    }
    for (let second = 1; second < remaining.length; second += 1) {
      consider([first, remaining[second]], needsTrio);
      if (needsTrio) {
        for (let third = second + 1; third < remaining.length; third += 1) {
          consider([first, remaining[second], remaining[third]], false);
          if (best?.repeats === 0) break;
        }
      }
      if (best?.repeats === 0) break;
    }
    memo.set(key, best);
    return best;
  }
  return solve(players.map((_, index) => index), players.length % 2 === 1);
}

function sampledAssignments(players, previousPairs, random) {
  let best = null;
  for (let attempt = 0; attempt < LARGE_ROSTER_ATTEMPTS; attempt += 1) {
    const order = shuffle(players, random);
    const groups = [];
    while (order.length > 0) groups.push(order.splice(0, order.length === 3 ? 3 : 2));
    const repeats = groups.reduce((count, group) => count + repeatCount(group, previousPairs), 0);
    if (!best || repeats < best.repeats) best = { groups, repeats };
    if (repeats === 0) break;
  }
  return best;
}

/**
 * Assign each distinct eligible ID exactly once, avoiding previous partners.
 * @param {string[]} eligibleIDs Active members after applying event opt-outs.
 * @param {string[][]} previousGroups The preceding event's pairs and trio.
 * @param {() => number} random Injected randomness for repeatable tests.
 * @returns {{groups: string[][], repeats: number, optimal: boolean}} Assignment result.
 * @throws {Error} If member identifiers or injected randomness are invalid.
 */
export function makeAssignments(eligibleIDs, previousGroups = [], random = () => randomInt(0, 2 ** 32) / 2 ** 32) {
  if (!Array.isArray(eligibleIDs) || eligibleIDs.some(id => typeof id !== 'string' || id.length === 0)) {
    throw new Error('Eligible members must have nonempty string identifiers.');
  }
  if (new Set(eligibleIDs).size !== eligibleIDs.length) throw new Error('Duplicate eligible member.');
  if (!Array.isArray(previousGroups) || previousGroups.some(group => !Array.isArray(group)
      || group.some(id => typeof id !== 'string' || id.length === 0))) {
    throw new Error('Previous assignments must contain member identifiers.');
  }
  if (eligibleIDs.length < 2) return { groups: [], repeats: 0, optimal: true };
  const previousPairs = new Set();
  for (const group of previousGroups) {
    for (let left = 0; left < group.length; left += 1) {
      for (let right = left + 1; right < group.length; right += 1) {
        previousPairs.add(pairKey(group[left], group[right]));
      }
    }
  }
  const players = shuffle(eligibleIDs, random);
  const exact = players.length <= EXACT_ROSTER_LIMIT;
  const result = exact ? exactAssignments(players, previousPairs) : sampledAssignments(players, previousPairs, random);
  if (!result) throw new Error('Could not construct a complete assignment.');
  return { ...result, optimal: exact || result.repeats === 0 };
}
