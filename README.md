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
- [Null Move Pruning](https://www.chessprogramming.org/Null_Move_Pruning)
- [Reverse Futility Pruning](https://www.chessprogramming.org/Reverse_Futility_Pruning)
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
|    1 | [radiance_4.3]   |       | 1961 | 10 | 10 |  6144 |   84% |  1641 |   12% |
|    2 | [radiance_4.2]   |  1803 | 1803 |  8 |  8 |  6144 |   64% |  1693 |   21% |
|    3 | [radiance_4.1]   |  1675 | 1640 |  8 |  9 |  7419 |   51% |  1593 |   16% |
|    4 | [radiance_4.0.1] |       | 1480 |  8 |  8 | 14312 |   65% |  1249 |    8% |
|    5 | [radiance_3.5]   |  1322 | 1222 |  8 |  8 | 10216 |   66% |  1025 |   11% |
|    6 | [radiance_3.4]   |  1300 | 1198 |  8 |  7 | 10218 |   64% |  1028 |   11% |
|    7 | [radiance_3.3]   |       | 1146 |  8 |  8 | 10216 |   59% |  1034 |   11% |
|    8 | [radiance_3.2]   |       | 1135 |  8 |  8 | 10215 |   58% |  1036 |   11% |
|    9 | [radiance_3.1.1] |  1119 | 965  |  8 |  8 |  9552 |   45% |  1015 |    9% |
|   10 | [radiance_3.0.1] |       | 689  |  9 |  9 |  9552 |   20% |  1050 |    9% |
|   11 | [radiance_2.4]   |       | 647  |  9 |  9 |  9552 |   16% |  1055 |   10% |
|   12 | [radiance_2.3]   |   874 | 602  |  9 | 10 |  9552 |   13% |  1061 |    9% |


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
- `go [movetime <int> | wtime <int> | btime <int> | winc <int> | binc <int> | nodes <int> | depth <int> | infinite | perft <int>]`
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
