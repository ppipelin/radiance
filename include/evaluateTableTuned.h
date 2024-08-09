#pragma once

#include "include.h"
#include "evaluate.h"
#include "evaluateShannonHeuristics.h"
#include "boardParser.h"

#include <algorithm>
#include <cmath>
#include <unordered_map>

class EvaluateTableTuned : virtual public EvaluateShannonHeuristics
{
public:
	EvaluateTableTuned() {}
	EvaluateTableTuned(const EvaluateTableTuned &) {}
	~EvaluateTableTuned() {}

	// Tables are displayed for white which corresponds to black order of tiles
	// https://www.chessprogramming.org/PeSTO%27s_Evaluation_Function
	static constexpr std::array<Value, 64> pawnTable = {
		0,   0,   0,   0,   0,   0,  0,   0,
		98, 134,  61,  95,  68, 126, 34, -11,
		-6,   7,  26,  31,  65,  56, 25, -20,
		-14,  13,   6,  21,  23,  12, 17, -23,
		-27,  -2,  -5,  12,  17,   6, 10, -25,
		-26,  -4,  -4, -10,   3,   3, 33, -12,
		-35,  -1, -20, -23, -15,  24, 38, -22,
		0,   0,   0,   0,   0,   0,  0,   0 };

	static constexpr std::array<Value, 64> knightTable = {
		-167, -89, -34, -49,  61, -97, -15, -107,
		-73, -41,  72,  36,  23,  62,   7,  -17,
		-47,  60,  37,  65,  84, 129,  73,   44,
		-9,  17,  19,  53,  37,  69,  18,   22,
		-13,   4,  16,  13,  28,  19,  21,   -8,
		-23,  -9,  12,  10,  19,  17,  25,  -16,
		-29, -53, -12,  -3,  -1,  18, -14,  -19,
		-105, -21, -58, -33, -17, -28, -19,  -23 };

	static constexpr std::array<Value, 64> bishopTable = {
		-29,   4, -82, -37, -25, -42,   7,  -8,
		-26,  16, -18, -13,  30,  59,  18, -47,
		-16,  37,  43,  40,  35,  50,  37,  -2,
		-4,   5,  19,  50,  37,  37,   7,  -2,
		-6,  13,  13,  26,  34,  12,  10,   4,
		0,  15,  15,  15,  14,  27,  18,  10,
		4,  15,  16,   0,   7,  21,  33,   1,
		-33,  -3, -14, -21, -13, -12, -39, -21, };

	static constexpr std::array<Value, 64> rookTable = {
		32,  42,  32,  51, 63,  9,  31,  43,
		27,  32,  58,  62, 80, 67,  26,  44,
		-5,  19,  26,  36, 17, 45,  61,  16,
		-24, -11,   7,  26, 24, 35,  -8, -20,
		-36, -26, -12,  -1,  9, -7,   6, -23,
		-45, -25, -16, -17,  3,  0,  -5, -33,
		-44, -16, -20,  -9, -1, 11,  -6, -71,
		-19, -13,   1,  17, 16,  7, -37, -26 };

	static constexpr std::array<Value, 64> queenTable = {
		-28,   0,  29,  12,  59,  44,  43,  45,
		-24, -39,  -5,   1, -16,  57,  28,  54,
		-13, -17,   7,   8,  29,  56,  47,  57,
		-27, -27, -16, -16,  -1,  17,  -2,   1,
		-9, -26,  -9, -10,  -2,  -4,   3,  -3,
		-14,   2, -11,  -2,  -5,   2,  14,   5,
		-35,  -8,  11,   2,   8,  15,  -3,   1,
		-1, -18,  -9,  10, -15, -25, -31, -50 };

	static constexpr std::array<Value, 64> kingTable = {
		-65,  23,  16, -15, -56, -34,   2,  13,
		29,  -1, -20,  -7,  -8,  -4, -38, -29,
		-9,  24,   2, -16, -20,   6,  22, -22,
		-17, -20, -12, -27, -30, -25, -14, -36,
		-49,  -1, -27, -39, -46, -44, -33, -51,
		-14, -14, -22, -46, -44, -30, -15, -27,
		1,   7,  -8, -64, -43, -16,   9,   8,
		-15,  36,  12, -54,   8, -28,  24,  14 };

	static constexpr std::array<Value, 64> kingEndgameTable = {
		-74, -35, -18, -18, -11,  15,   4, -17,
		-12,  17,  14,  17,  17,  38,  23,  11,
		10,  17,  23,  15,  20,  45,  44,  13,
		-8,  22,  24,  27,  26,  33,  26,   3,
		-18,  -4,  21,  24,  27,  23,   9, -11,
		-19,  -3,  11,  21,  23,  16,   7,  -9,
		-27, -11,   4,  13,  14,   4,  -5, -17,
		-53, -34, -21, -11, -28, -14, -24, -43 };

	static constexpr std::array<Value, 8> passedPawnTable = { 0, 15, 15, 25, 40, 60, 70 };

	Value evaluate(const BoardParser &b) const override
	{
		Value finalScore = 0, scorePieceWhite = 0, scorePieceBlack = 0, mgScore = 0, egScore = 0, scoreKingWhite = 0, scoreKingBlack = 0;
		std::vector<cMove> moveset;

		for (Int i = -1; i < 2; i += 2)
		{
			std::vector<UInt> table = (i == -1) ? b.boardParsed()->blackPos() : b.boardParsed()->whitePos();
			Value *scoreCurrent = &(i == 1 ? scorePieceWhite : scorePieceBlack);
			std::vector<UInt> pawnPositions;
			std::vector<UInt> pawnColumns;

			for (const auto &pieceIdx : table)
			{
				moveset.clear();
				const Piece *p = b.boardParsed()->board()[pieceIdx];
				// Find idx in piece-square table
				Int idxTable = i == 1 ? ((BOARD_SIZE - 1) - Board::row(pieceIdx)) * BOARD_SIZE + Board::column(pieceIdx) : pieceIdx;

				if (p == nullptr)
					continue;
				if (p->value() == PieceType::KING)
				{
					*scoreCurrent += 20000;

					p->canMove(*b.boardParsed(), moveset);
					egScore += i * Value(moveset.size());
					(i == 1 ? scoreKingWhite : scoreKingBlack) = kingEndgameTable[idxTable];
					egScore += i * (i == 1 ? scoreKingWhite : scoreKingBlack);
					mgScore += i * (kingTable[idxTable] - Value(moveset.size()));
				}
				else if (p->value() == PieceType::QUEEN)
				{
					*scoreCurrent += 950;
					const Value v = queenTable[idxTable];
					mgScore += i * v;
					egScore += i * v;
				}
				else if (p->value() == PieceType::ROOK)
				{
					*scoreCurrent += 563;

					p->canMove(*b.boardParsed(), moveset);
					egScore += i * (5 * Value(moveset.size()));
					const Value v = rookTable[idxTable];
					mgScore += i * v;
					egScore += i * v;
				}
				else if (p->value() == PieceType::BISHOP)
				{
					*scoreCurrent += 333;

					p->canMove(*b.boardParsed(), moveset);
					const Value v = bishopTable[idxTable] + 5 * Value(moveset.size());
					mgScore += i * v;
					egScore += i * v;
				}
				else if (p->value() == PieceType::KNIGHT)
				{
					*scoreCurrent += 305;

					const Value v = knightTable[idxTable];
					mgScore += i * v;
					egScore += i * v;
				}
				else if (p->value() == PieceType::PAWN)
				{
					*scoreCurrent += 100;

					Bitboard f = filterPassedPawn(p->tile(), Color(p->isWhite()));
					*scoreCurrent += passedPawnTable[p->isWhite() ? Board::row(p->tile()) : BOARD_SIZE - 1 - Board::row(p->tile())] * Value((f & Bitboards::bbPieces[PieceType::PAWN] & Bitboards::bbColors[Color(!p->isWhite())]) == 0);

					pawnPositions.push_back(pieceIdx);
					pawnColumns.push_back(Board::column(pieceIdx));

					const Value v = pawnTable[idxTable];
					mgScore += i * v;
					egScore += i * v;
				}
			}

			finalScore += i * (*scoreCurrent + pawnMalus(b, pawnPositions, pawnColumns));
		}

		// Once ennemy has less pieces our king attacks the other one
		// King, seven pawns a rook and a bishop
		const bool endgame = (b.isWhiteTurn() ? scorePieceBlack : scorePieceWhite) <= 20000 + 7 * 100 + 563 + 333;
		// King, six pawns a bishop and a knight
		// const bool endgameHard = (b.isWhiteTurn() ? scorePieceBlack : scorePieceWhite) <= 20000 + 4 * 100 + 333 + 305;

		if (endgame)
		{
			// Improve current side score based on king proximity
			finalScore += (b.isWhiteTurn() ? 1 : -1) * distanceKings(b);
			// Malus if king is weak when losing (doubles)
			if (scorePieceWhite > scorePieceBlack)
				finalScore += -scoreKingBlack;
			else if (scorePieceWhite < scorePieceBlack)
				finalScore += scoreKingWhite;
			// finalScore -= (scorePieceWhite > scorePieceBlack ? -scoreKingBlack : scoreKingWhite) * 100;
			finalScore += egScore;
		}
		else
		{
			finalScore += mgScore;
		}

		return (b.isWhiteTurn() ? 1 : -1) * finalScore;
	}
};
