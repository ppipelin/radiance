# Radiance Engine
[![Build Status](https://github.com/ppipelin/radiance/actions/workflows/tests.yml/badge.svg)](https://github.com/ppipelin/radiance/actions/workflows/tests.yml)
[![Latest Release](https://img.shields.io/github/v/release/ppipelin/radiance?display_name=release)](https://github.com/ppipelin/radiance/releases)
![License](https://img.shields.io/github/license/ppipelin/radiance)

[![Lichess classical rating](https://lichess-shield.vercel.app/api?username=radianceengine&format=classical)](https://lichess.org/@/radianceengine/perf/classical)
[![Lichess rapid rating](https://lichess-shield.vercel.app/api?username=radianceengine&format=rapid)](https://lichess.org/@/radianceengine/perf/rapid)
[![Lichess blitz rating](https://lichess-shield.vercel.app/api?username=radianceengine&format=blitz)](https://lichess.org/@/radianceengine/perf/blitz)
[![Lichess bullet rating](https://lichess-shield.vercel.app/api?username=radianceengine&format=bullet)](https://lichess.org/@/radianceengine/perf/bullet)

:zap: Zig chess engine :zap:

![Radiance Logo, courtesy of Jim Ablett](dcu2Wsn.png "Image Credit: Jim Ablett")

## Move Generation and Ordering

- Fancy Magic Bitboards
- [Staged](https://www.chessprogramming.org/Move_Generation#Staged_Move_Generation) Move Generation
- Transposition Table Move Ordering
- Principal Variation Move Ordering
- [Static Exchange Evaluation](https://www.chessprogramming.org/Static_Exchange_Evaluation)
- [Chess960](https://www.chessprogramming.org/Chess960) support

## Search

- [Principal Variation Search](https://www.chessprogramming.org/Principal_Variation_Search)
- [Alpha-Beta](https://www.chessprogramming.org/Alpha-Beta) Pruning
- [Aspiration Window](https://www.chessprogramming.org/Aspiration_Windows)
- [Late Move Reductions](https://www.chessprogramming.org/Late_Move_Reductions)
- Late Move Pruning
- [Null Move Pruning](https://www.chessprogramming.org/Null_Move_Pruning)
- [Reverse Futility Pruning](https://www.chessprogramming.org/Reverse_Futility_Pruning)
- Futility pruning
- Mate pruning
- Razoring
- Internal iterative reductions
- [Quiescence Search](https://www.chessprogramming.org/Quiescence_Search)
- Threefold Repetition
- Time Management

## Evaluation

- [Tuned](https://www.chessprogramming.org/PeSTO%27s_Evaluation_Function) Piece-square Tables
- [_AlphaZero_ Average Piece Values](https://arxiv.org/pdf/2009.04374)
- Tapered Evaluation
- Transposition Table Evaluation
- Endgame Heuristics
- Pawn Structures Heuristics
- Bishop pair bonus
- Mobility Bonus

## Versions tournament

Time control: 120+1

CCRL [blitz benchmark](https://computerchess.org.uk/ccrl/404/cgi/compare_engines.cgi?family=Radiance&print=Rating+list&print=Score+with+common+opponents).

| Rank | Name             | CCRL  |  Elo |  + |  - | games | score | oppo. | draws |
| ---- | ---------------- | ----- | ---- | -- | -- | ----- | ----- | ----- | ----- |
|    1 | [radiance_4.4]   |       | 2243 | 14 | 14 |  3456 |   88% |  1834 |   11% |
|    2 | [radiance_4.3]   |  2071 | 2071 |  9 |  9 |  7008 |   77% |  1816 |   14% |
|    3 | [radiance_4.2]   |  1803 | 1917 |  8 |  8 |  7008 |   57% |  1861 |   20% |
|    4 | [radiance_4.1]   |  1674 | 1754 |  8 |  8 |  8283 |   46% |  1762 |   15% |
|    5 | [radiance_4.0.1] |       | 1596 |  8 |  8 | 15176 |   61% |  1413 |    8% |
|    6 | [radiance_3.5]   |  1321 | 1338 |  8 |  8 | 10216 |   66% |  1141 |   11% |
|    7 | [radiance_3.4]   |  1299 | 1314 |  8 |  8 | 10218 |   64% |  1144 |   11% |
|    8 | [radiance_3.3]   |       | 1262 |  8 |  8 | 10216 |   59% |  1150 |   11% |
|    9 | [radiance_3.2]   |       | 1251 |  8 |  8 | 10215 |   58% |  1152 |   11% |
|   10 | [radiance_3.1.1] |  1117 | 1081 |  8 |  8 |  9552 |   45% |  1131 |    9% |
|   11 | [radiance_3.0.1] |       |  804 |  9 |  9 |  9552 |   20% |  1166 |    9% |
|   12 | [radiance_2.4]   |       |  763 |  9 |  9 |  9552 |   16% |  1171 |   10% |
|   13 | [radiance_2.3]   |   872 |  718 |  9 | 10 |  9552 |   13% |  1177 |    9% |


## Getting started

### Compile and run

```
zig build run -release=fast
```

### Deploy

```
zig build deploy
```

### Test

```
zig build test --release=safe
```

### UCI options

| Name           | Type  | Default value       |  Valid values                     | Description                                          |
| -------------- | ----- | ------------------- | --------------------------------- | ---------------------------------------------------- |
| `Hash`         | spin  |         256         |             [1, 65535]            | Memory allocated to the transposition table (in MB). |
| `Threads`      | spin  |          1          |               [1, 1]              | Number of threads used to search.                    |
| `Evaluation`   | combo |        "PSQ"        | ["PSQ", "Shannon", "Materialist"] | Type of evaluation function.                         |
| `Search`       | combo |  "NegamaxAlphaBeta" |   ["NegamaxAlphaBeta", "Random"]  | Type of search function.                             |
| `UCI_Chess960` | check |        false        |          ["true", "false"]        |                                                      |

### Commands

- `uci`
- `isready`
- `setoption name <string> [value <string>]`
- `position [(fen <string> | startpos | kiwi | lasker) [moves <string>...]]`
- `eval`
- `go [movetime <int> | wtime <int> | btime <int> | winc <int> | binc <int> | nodes <int> | depth <int> | searchmoves <string>... | infinite | perft <int>]`
- `bench`
- `benchv`
- `stop`
- `quit`
- `ucinewgame`
- `d`

### Archive

This project was originaly written in C++ before 4.0 version and archived under the name [radiance_archived](https://github.com/ppipelin/radiance_archived).

### Aknowledgments

- [Avalanche](https://github.com/SnowballSH/Avalanche) engine is a great example of how a zig project should be coded. Radiance engine still uses its pseudo random number generator (MIT License - Copyright (c) 2023 Yinuo Huang).
- [Stockfish](https://github.com/official-stockfish/Stockfish) with its aggressive pruning methods.
- [Chess Programming Wiki](https://www.chessprogramming.org/Main_Page).

_I'm radiant!_

[radiance_4.4]: https://github.com/ppipelin/radiance/releases/tag/4.4
[radiance_4.3]: https://github.com/ppipelin/radiance/releases/tag/4.3
[radiance_4.2]: https://github.com/ppipelin/radiance/releases/tag/4.2
[radiance_4.1]: https://github.com/ppipelin/radiance/releases/tag/4.1
[radiance_4.0.1]: https://github.com/ppipelin/radiance/releases/tag/4.0.1
[radiance_3.5]: https://github.com/ppipelin/radiance_archived/releases/tag/3.5
[radiance_3.4]: https://github.com/ppipelin/radiance_archived/releases/tag/3.4
[radiance_3.3]: https://github.com/ppipelin/radiance_archived/releases/tag/3.3
[radiance_3.2]: https://github.com/ppipelin/radiance_archived/releases/tag/3.2
[radiance_3.1.1]: https://github.com/ppipelin/radiance_archived/releases/tag/3.1.1
[radiance_3.0.1]: https://github.com/ppipelin/radiance_archived/releases/tag/3.0.1
[radiance_2.4]: https://github.com/ppipelin/radiance_archived/releases/tag/2.4
[radiance_2.3]: https://github.com/ppipelin/radiance_archived/releases/tag/2.3
