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
- Fancy Magic Bitboards For Sliders
- Transposition Table Move Ordering
- Principal Variation Move Ordering
- MVV-LVA
- [Chess960](https://www.chessprogramming.org/Chess960) support

## Search

- [Principal Variation Search](https://www.chessprogramming.org/Principal_Variation_Search)
- [Alpha-Beta](https://www.chessprogramming.org/Alpha-Beta) Pruning
- [Aspiration Window](https://www.chessprogramming.org/Aspiration_Windows)
- [Late Move Reductions](https://www.chessprogramming.org/Late_Move_Reductions)
- [Null Move Pruning](https://www.chessprogramming.org/Null_Move_Pruning)
- [Reverse Futility Pruning](https://www.chessprogramming.org/Reverse_Futility_Pruning)
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
- Mobility Bonus

## Versions tournament

Time control: 120+1

CCRL [blitz benchmark](https://computerchess.org.uk/ccrl/404/cgi/compare_engines.cgi?family=Radiance&print=Rating+list&print=Score+with+common+opponents).

| Rank | Name             | CCRL  |  Elo |  + |  - | games | score | oppo. | draws |
| ---- | ---------------- | ----- | ---- | -- | -- | ----- | ----- | ----- | ----- |
|    1 | [radiance_4.1]   |       | 1733 | 47 | 43 |   322 |   88% |  1343 |   10% |
|    2 | [radiance_4.0.1] |       | 1591 | 10 | 10 |  9618 |   91% |  1059 |    6% |
|    3 | [radiance_3.5]   |  1326 | 1326 |  8 |  8 |  9616 |   70% |  1092 |   11% |
|    4 | [radiance_3.4]   |  1300 | 1302 |  8 |  8 |  9616 |   68% |  1095 |   11% |
|    5 | [radiance_3.3]   |       | 1250 |  8 |  7 |  9615 |   63% |  1101 |   11% |
|    6 | [radiance_3.2]   |       | 1239 |  8 |  7 |  9615 |   62% |  1103 |   12% |
|    7 | [radiance_3.1.1] |  1116 | 1070 |  8 |  8 |  9552 |   45% |  1120 |    9% |
|    8 | [radiance_3.0.1] |       |  793 |  9 |  9 |  9552 |   20% |  1155 |    9% |
|    9 | [radiance_2.4]   |   866 |  751 |  9 |  9 |  9552 |   16% |  1160 |   10% |
|   10 | [radiance_2.3]   |   865 |  707 |  9 |  9 |  9552 |   13% |  1166 |    9% |


## Getting started

### Compile and run

```
zig build run -relase=fast
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
- `setoption name <id> [value <x>]`
- `position [fen <string> | startpos | kiwi | lasker] [moves <string>...]`
- `eval`
- `go [movetime <int> | [wtime <int>] [btime <int>] [winc <int>] [binc <int>] | depth <int> | infinite | perft <int>]`
- `bench`
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
