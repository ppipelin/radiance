# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Null move pruning
- Tests
- Error handling for moves, fen and uci

### Changed

- Zig codebase
- Fen full support
- Evalutation (mg, eg) during move
- Check detection during move

## [3.5] - 2024-12-25

### Added

- Lasker position
- Time management with increment

## Changed

- Compilation options assigned to targets
- UIntL for display of large numbers
- Score of king actually used for endgame

## [3.4] - 2024-12-25

### Added

- Bitboard evaluation function
- Linux GCC errorless compile
- Github actions compilation for Linux

### Changed

- Bit manipulation functions
- Evaluate table code flow
- Use 64 bits `UIntL` for nps display and perft

### Removed

- `opt` preprocessor variable for perft

## [3.3] - 2024-09-05

### Added

- Hardware-dependent bitboard functions
- Hardware-dependent compiler flags
- Github deployement actions
- UCI options to select `search` and `evaluation` functions
- Bitboard generation for queen, rook, bishop and knight.

### Fixed

- Prevent transitive include and sorted include
- Less compiler warnings
- Refresh previous search functions
- Better CMakeLists

## [3.2] - 2024-08-13

### Added

- Bitboards
- Passed, isolated and doubled pawn detection through bitboards for evaluation

### Fixed

- Clean code

## [3.1.1] - 2024-08-04

### Changed

- Address UCI issues (#3)
- Add LICENSE

## [3.1] - 2024-07-30

### Added

- Improve ordering : use ttMove and pvMove
- Keep computed nodes when calling `stop`

## [3.0.1] - 2024-07-30

### Changed

- Clean code

### Fixed

- Fix aspiration window

## [3.0] - 2024-07-21

### Added

- Late-move reduction
- Three-fold repetition
- Transposition tables

### Changed

- Improve endgame evaluation
- King more aggressive in endgame

## [2.4] - 2024-07-20

### Added

- Late-move reduction
- Three-fold repetition
- Transposition tables

### Changed

- Improve endgame evaluation
- King more aggressive in endgame

## [2.3] - 2024-03-08

### Added

- Zobrist key hashing
- `position kiwi` command loads [kiwipete](https://www.chessprogramming.org/Perft_Results#Position_2) position
- [CI](https://github.com/ppipelin/radiance/actions)
- `BoardParser::State` history with previous `field`
- Three-fold repetition _pseudo_ working
- Tune piece-square table

### Changed

- Move generation better pre-allocates
- Improve endgame evaluation
- Sort pieces positions when generating moves to keep consistency which improved quality of play

### Fixed

- _En passant_
- King distance evaluation
- Pawn promotion
- Time management taking only current side time into account

### Beta

- Transposition working, not used
- Late-move reduction

## [2.2] - 2024-01-25

### Changed

- Improve _Quiescence_
- Better endgame handling with tables
- Improve `Search::generateMoveList()` performances
- Improve `Piece::sliding()` and pieces' using it in `canMove()`
- Time management considers 30 moves to play instead of 20

### Fixed

- Fix single move behavior
- Fix beta cutoff

## [2.1] - 2024-01-22

### Added

- Add [Tomasz Michniewski](https://www.chessprogramming.org/Tomasz_Michniewski) Piece-Square [Tables](https://www.chessprogramming.org/Simplified_Evaluation_Function)

### Changed

- King moveset is now a liability in early and middle game

## [2.0] - 2024-01-22

### Added

- Add `BoardParser::unMove()` (#2) for better performances
- Add `Search::orderMove()`
- Add `BoardParser::State`

### Changed

- RootMoves order is taken into account over iterations
- Improve time management

### Beta

- Aspiration window

## [1.5] - 2024-01-22

### Added

- Panic mode for two minutes left

### Changed

- Tweak pawn malus
- Opening book

## [1.4] - 2024-01-08

### Added

- _Quiescence_
- Heuristics to Shannon evaluation
- AlphaZero piece value
- King proximity incentive in endgame

### Changed

- Improve mate evaluation

## [1.3] - 2024-01-07

### Added

- `Negamax` search with alpha beta pruning
- Iterative deepening
- UCI `perft` command

### Changed

- Improve `Search::generateMoveList()` performances

## [1.2] - 2024-01-05

### Added

- `RootMove` info displayed
- Display command `d`

### Changed

- More faithful legal move generation

### Fixed

- Fix memory leaks
- Fix UCI promotion communication

## [1.1] - 2023-12-29

### Added

- `Materialist` search

## [1.0] - 2023-12-28

### Added

- UCI `go` command at depth four
- UCI `position` command
- `Random` search

[Unreleased]: https://github.com/ppipelin/radiance/
[3.5]: https://github.com/ppipelin/radiance_archived/compare/3.4...3.5
[3.4]: https://github.com/ppipelin/radiance_archived/compare/3.3...3.4
[3.3]: https://github.com/ppipelin/radiance_archived/compare/3.2...3.3
[3.2]: https://github.com/ppipelin/radiance_archived/compare/3.1.1...3.2
[3.1.1]: https://github.com/ppipelin/radiance_archived/compare/3.1...3.1.1
[3.1]: https://github.com/ppipelin/radiance_archived/compare/3.0.1...3.1
[3.0.1]: https://github.com/ppipelin/radiance_archived/compare/3.0...3.0.1
[3.0]: https://github.com/ppipelin/radiance_archived/compare/2.4...3.0
[2.4]: https://github.com/ppipelin/radiance_archived/compare/2.3...2.4
[2.3]: https://github.com/ppipelin/radiance_archived/compare/2.2...2.3
[2.2]: https://github.com/ppipelin/radiance_archived/compare/2.1...2.2
[2.1]: https://github.com/ppipelin/radiance_archived/compare/2.0...2.1
[2.0]: https://github.com/ppipelin/radiance_archived/compare/1.5...2.0
[1.5]: https://github.com/ppipelin/radiance_archived/compare/1.4...1.5
[1.4]: https://github.com/ppipelin/radiance_archived/compare/1.3...1.4
[1.3]: https://github.com/ppipelin/radiance_archived/compare/1.2...1.3
[1.2]: https://github.com/ppipelin/radiance_archived/compare/1.1...1.2
[1.1]: https://github.com/ppipelin/radiance_archived/compare/1.0...1.1
[1.0]: https://github.com/ppipelin/radiance_archived/releases/tag/1.0
