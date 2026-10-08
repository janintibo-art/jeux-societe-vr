// Intelligence artificielle du Puissance 4 (exécutée dans un Web Worker pour ne pas figer l'image en VR).
// Plateau : tableau de 42 cases, index = colonne * 6 + rangée (rangée 0 en bas). 0 = vide, 1 = rouge, 2 = jaune.
const COLS = 7, ROWS = 6;
const ORDER = [3, 2, 4, 1, 5, 0, 6];
const WIN = 1000000;

function lowest(b, c) {
  for (let r = 0; r < ROWS; r++) if (!b[c * ROWS + r]) return r;
  return -1;
}

function at(b, c, r) {
  return c >= 0 && c < COLS && r >= 0 && r < ROWS ? b[c * ROWS + r] : -1;
}

function winsAt(b, c, r, p) {
  const dirs = [[1, 0], [0, 1], [1, 1], [1, -1]];
  for (const [dc, dr] of dirs) {
    let n = 1;
    for (let k = 1; k < 4 && at(b, c + dc * k, r + dr * k) === p; k++) n++;
    for (let k = 1; k < 4 && at(b, c - dc * k, r - dr * k) === p; k++) n++;
    if (n >= 4) return true;
  }
  return false;
}

// Toutes les fenêtres de 4 cases alignées, calculées une fois.
const WINDOWS = [];
for (let c = 0; c < COLS; c++) for (let r = 0; r < ROWS; r++) {
  for (const [dc, dr] of [[1, 0], [0, 1], [1, 1], [1, -1]]) {
    const cells = [];
    for (let k = 0; k < 4; k++) {
      const cc = c + dc * k, rr = r + dr * k;
      if (cc < 0 || cc >= COLS || rr < 0 || rr >= ROWS) break;
      cells.push(cc * ROWS + rr);
    }
    if (cells.length === 4) WINDOWS.push(cells);
  }
}

function evaluate(b, p) {
  const o = 3 - p;
  let s = 0;
  for (let r = 0; r < ROWS; r++) {
    const v = b[3 * ROWS + r];
    if (v === p) s += 4; else if (v === o) s -= 4;
  }
  for (const w of WINDOWS) {
    let mine = 0, theirs = 0;
    for (const i of w) {
      if (b[i] === p) mine++; else if (b[i] === o) theirs++;
    }
    if (mine && theirs) continue;
    if (mine === 3) s += 12; else if (mine === 2) s += 3;
    else if (theirs === 3) s -= 14; else if (theirs === 2) s -= 3;
  }
  return s;
}

function negamax(b, depth, alpha, beta, p, left) {
  if (left === 0) return 0;
  if (depth === 0) return evaluate(b, p);
  let best = -Infinity;
  for (const c of ORDER) {
    const r = lowest(b, c);
    if (r < 0) continue;
    b[c * ROWS + r] = p;
    const score = winsAt(b, c, r, p) ? WIN + depth : -negamax(b, depth - 1, -beta, -alpha, 3 - p, left - 1);
    b[c * ROWS + r] = 0;
    if (score > best) best = score;
    if (best > alpha) alpha = best;
    if (alpha >= beta) break;
  }
  return best;
}

function choose(board, p, depth, randomness) {
  const b = Int8Array.from(board);
  const moves = ORDER.filter((c) => lowest(b, c) >= 0);
  const left = b.reduce((n, v) => n + (v ? 0 : 1), 0);
  // Gagner tout de suite, ou bloquer une victoire immédiate : toujours.
  for (const pl of [p, 3 - p]) {
    for (const c of moves) {
      const r = lowest(b, c);
      b[c * ROWS + r] = pl;
      const w = winsAt(b, c, r, pl);
      b[c * ROWS + r] = 0;
      if (w) return c;
    }
  }
  if (Math.random() < randomness) return moves[Math.floor(Math.random() * moves.length)];
  let best = -Infinity, bestMoves = [];
  for (const c of moves) {
    const r = lowest(b, c);
    b[c * ROWS + r] = p;
    const s = -negamax(b, depth - 1, -Infinity, Infinity, 3 - p, left - 1);
    b[c * ROWS + r] = 0;
    if (s > best) { best = s; bestMoves = [c]; } else if (s === best) bestMoves.push(c);
  }
  return bestMoves[Math.floor(Math.random() * bestMoves.length)];
}

self.onmessage = (e) => {
  const { id, board, player, depth, randomness } = e.data;
  const col = choose(board, player, depth, randomness);
  self.postMessage({ id, col });
};
