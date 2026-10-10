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
- [Alpha-Beta](https://www.chessprogramming.org/Alpha-Beta) Pruning through [Negamax](https://www.chessprogramming.org/Negamax)
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
- Multi threading using [lazy SMP](https://www.chessprogramming.org/Lazy_SMP)
- Threefold Repetition
- Time Management

## Evaluation

- Since [radiance_5.0], default evaluation is via a self-play-trained NNUE with dual perspective.
  - Current architecture is (768 → 512)*2 → 1 and trained from 6 million games

- [Tuned](https://www.chessprogramming.org/PeSTO%27s_Evaluation_Function) Piece-square Tables with setoption PSQ
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
|    1 | [radiance_5.0]   |       | 2839 | 32 | 29 |  7409 |   99% |  1923 |    1% |
|    2 | [radiance_4.4]   |       | 2243 |  9 |  9 |  9674 |   75% |  1996 |   10% |
|    3 | [radiance_4.3]   |  2071 | 2075 |  8 |  8 |  9674 |   59% |  2031 |   13% |
|    4 | [radiance_4.2]   |  1803 | 1926 |  8 |  8 |  9674 |   44% |  2063 |   16% |
|    5 | [radiance_4.1]   |  1674 | 1764 |  8 |  8 | 10949 |   36% |  1966 |   12% |
|    6 | [radiance_4.0.1] |       | 1607 |  8 |  8 | 17841 |   52% |  1594 |    7% |
|    7 | [radiance_3.5]   |  1321 | 1348 |  8 |  8 | 10216 |   66% |  1151 |   11% |
|    8 | [radiance_3.4]   |  1299 | 1324 |  8 |  8 | 10218 |   64% |  1154 |   11% |
|    9 | [radiance_3.3]   |       | 1272 |  8 |  8 | 10216 |   59% |  1160 |   11% |
|   10 | [radiance_3.2]   |       | 1261 |  7 |  8 | 10215 |   58% |  1162 |   11% |
|   11 | [radiance_3.1.1] |  1117 | 1091 |  8 |  8 |  9552 |   45% |  1141 |    9% |
|   12 | [radiance_3.0.1] |       |  815 |  9 |  9 |  9552 |   20% |  1176 |    9% |
|   13 | [radiance_2.4]   |       |  773 |  9 |  9 |  9552 |   16% |  1181 |   10% |
|   14 | [radiance_2.3]   |   872 |  728 | 10 | 10 |  9552 |   13% |  1187 |    9% |

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

| Name           | Type   | Default value       |  Valid values                     | Description                                          |
| -------------- | ------ | ------------------- | --------------------------------- | ---------------------------------------------------- |
| `Hash`         | spin   |         256         |             [1, 65535]            | Memory allocated to the transposition table (in MB). |
| `Threads`      | spin   |          1          |               [1, 1]              | Number of threads used to search.                    |
| `Evaluation`   | combo  |        "PSQ"        | ["PSQ", "Shannon", "Materialist"] | Type of evaluation function.                         |
| `Search`       | combo  |  "NegamaxAlphaBeta" |   ["NegamaxAlphaBeta", "Random"]  | Type of search function.                             |
| `UCI_Chess960` | check  |        false        |          ["true", "false"]        |                                                      |
| `Ponder`       | check  |        false        |          ["true", "false"]        | Display pondering move                               |
| `EvalFile`     | string |                     |            path_to_file           | Load a binary file of NNUE weights                   |

### Commands

- `license`
- `uci`
- `isready`
- `setoption name <string> [value <string>]`
- `ucinewgame`
- `position [(fen <string> | startpos | kiwi | lasker) [moves <string>...]]`
- `go movetime <int>`
- `go ([wtime <int> [winc <int>]] [btime <int> [binc <int>]] | nodes <int> | depth <int>) [ponder]`
- `go searchmoves <string>...`
- `go perft <int>]`
- `go infinite`
- `wait`
- `stop`
- `ponderhit`
- `d`
- `bench`
- `benchv`
- `genfens <int> [seed <int64>]`
- `eval`
- `evals`
- `quit`

### Archive

This project was originaly written in C++ before 4.0 version and archived under the name [radiance_archived](https://github.com/ppipelin/radiance_archived).

### Aknowledgments

- [Avalanche](https://github.com/SnowballSH/Avalanche) engine is a great example of how a zig project should be coded. Radiance engine still uses its pseudo random number generator (MIT License - Copyright (c) 2023 Yinuo Huang).
- [Stockfish](https://github.com/official-stockfish/Stockfish) with its aggressive pruning methods.
- [Chess Programming Wiki](https://www.chessprogramming.org/Main_Page).

_I'm radiant!_

[radiance_5.0]: https://github.com/ppipelin/radiance/releases/tag/5.0
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
