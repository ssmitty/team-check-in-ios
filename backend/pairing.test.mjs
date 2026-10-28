/**
 * pairing.test.mjs
 * Purpose: Verify complete assignment, trio sizing, repeat avoidance, and invalid inputs.
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import { makeAssignments } from './pairing.mjs';

function seededRandom(seed = 42) {
  let state = seed;
  return () => {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    return state / 2 ** 32;
  };
}

test('every roster from two to forty has complete, unique membership and proper group sizes', () => {
  for (let count = 2; count <= 40; count += 1) {
    const members = Array.from({ length: count }, (_, index) => 'member-' + index);
    const result = makeAssignments(members, [], seededRandom(count));
    assert.deepEqual(result.groups.flat().sort(), [...members].sort());
    assert.equal(result.groups.filter(group => group.length === 3).length, count % 2);
    assert.ok(result.groups.every(group => group.length === 2 || group.length === 3));
  }
});

test('zero and one eligible player receive no assignment', () => {
  assert.deepEqual(makeAssignments([]).groups, []);
  assert.deepEqual(makeAssignments(['a']).groups, []);
});

test('two players may repeat without an error', () => {
  const result = makeAssignments(['a', 'b'], [['a', 'b']], seededRandom());
  assert.equal(result.repeats, 1);
  assert.equal(result.optimal, true);
});

test('a previous trio counts all three pairs as previous partners', () => {
  const result = makeAssignments(['a', 'b', 'c'], [['a', 'b', 'c']], seededRandom());
  assert.equal(result.repeats, 3);
});

test('four players avoid repeating partners when another matching exists', () => {
  const result = makeAssignments(['a', 'b', 'c', 'd'], [['a', 'b'], ['c', 'd']], seededRandom());
  assert.equal(result.repeats, 0);
});

test('five players minimize unavoidable repeats from a previous pair and trio', () => {
  const result = makeAssignments(['a', 'b', 'c', 'd', 'e'], [['a', 'b'], ['c', 'd', 'e']], seededRandom());
  assert.equal(result.repeats, 1);
  assert.equal(result.optimal, true);
});

test('invalid identifiers and randomness are rejected', () => {
  assert.throws(() => makeAssignments(['a', 'a']));
  assert.throws(() => makeAssignments(['a', '']));
  assert.throws(() => makeAssignments(['a', 'b'], [], () => 1));
});

test('input data stays unchanged and seeded randomness is reproducible', () => {
  const members = ['a', 'b', 'c', 'd'];
  const previous = [['a', 'b']];
  const first = makeAssignments(members, previous, seededRandom());
  assert.deepEqual(first, makeAssignments(members, previous, seededRandom()));
  assert.deepEqual(members, ['a', 'b', 'c', 'd']);
  assert.deepEqual(previous, [['a', 'b']]);
});
