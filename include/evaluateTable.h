#pragma once

#include <algorithm>
#include <cmath>
#include <unordered_map>

#include "boardParser.h"
#include "evaluate.h"
#include "evaluateShannonHeuristics.h"
#include "include.h"

class EvaluateTable : virtual public EvaluateShannonHeuristics
{
public:
	EvaluateTable() = default;
	EvaluateTable(const EvaluateTable &) = default;
	~EvaluateTable() = default;

	// Tables are displayed for white which corresponds to black order of tiles
	// https://www.chessprogramming.org/Simplified_Evaluation_Function
	static constexpr std::array<Value, 64> pawnTable = {
		0,  0,  0,  0,  0,  0,  0,  0,
		50, 50, 50, 50, 50, 50, 50, 50,
		10, 10, 20, 30, 30, 20, 10, 10,
		5,  5, 10, 25, 25, 10,  5,  5,
		0,  0,  0, 20, 20,  0,  0,  0,
		5, -5,-10,  0,  0,-10, -5,  5,
		5, 10, 10,-20,-20, 10, 10,  5,
		0,  0,  0,  0,  0,  0,  0,  0 };

	static constexpr std::array<Value, 64> knightTable = {
		-50,-40,-30,-30,-30,-30,-40,-50,
		-40,-20,  0,  0,  0,  0,-20,-40,
		-30,  0, 10, 15, 15, 10,  0,-30,
		-30,  5, 15, 20, 20, 15,  5,-30,
		-30,  0, 15, 20, 20, 15,  0,-30,
		-30,  5, 10, 15, 15, 10,  5,-30,
		-40,-20,  0,  5,  5,  0,-20,-40,
		-50,-40,-30,-30,-30,-30,-40,-50 };

	static constexpr std::array<Value, 64> bishopTable = {
		-20,-10,-10,-10,-10,-10,-10,-20,
		-10,  0,  0,  0,  0,  0,  0,-10,
		-10,  0,  5, 10, 10,  5,  0,-10,
		-10,  5,  5, 10, 10,  5,  5,-10,
		-10,  0, 10, 10, 10, 10,  0,-10,
		-10, 10, 10, 10, 10, 10, 10,-10,
		-10,  5,  0,  0,  0,  0,  5,-10,
		-20,-10,-10,-10,-10,-10,-10,-20 };

	static constexpr std::array<Value, 64> rookTable = {
		0,  0,  0,  0,  0,  0,  0,  0,
		5, 10, 10, 10, 10, 10, 10,  5,
	-5,  0,  0,  0,  0,  0,  0, -5,
	-5,  0,  0,  0,  0,  0,  0, -5,
	-5,  0,  0,  0,  0,  0,  0, -5,
	-5,  0,  0,  0,  0,  0,  0, -5,
	-5,  0,  0,  0,  0,  0,  0, -5,
		0,  0,  0,  5,  5,  0,  0,  0 };

	static constexpr std::array<Value, 64> queenTable = {
		-20,-10,-10, -5, -5,-10,-10,-20,
		-10,  0,  0,  0,  0,  0,  0,-10,
		-10,  0,  5,  5,  5,  5,  0,-10,
		-5,  0,  5,  5,  5,  5,  0, -5,
		0,  0,  5,  5,  5,  5,  0, -5,
		-10,  5,  5,  5,  5,  5,  0,-10,
		-10,  0,  5,  0,  0,  0,  0,-10,
		-20,-10,-10, -5, -5,-10,-10,-20 };

	static constexpr std::array<Value, 64> kingTable = {
		-30,-40,-40,-50,-50,-40,-40,-30,
		-30,-40,-40,-50,-50,-40,-40,-30,
		-30,-40,-40,-50,-50,-40,-40,-30,
		-30,-40,-40,-50,-50,-40,-40,-30,
		-20,-30,-30,-40,-40,-30,-30,-20,
		-10,-20,-20,-20,-20,-20,-20,-10,
		20, 20,  0,  0,  0,  0, 20, 20,
		20, 30, 10,  0,  0, 10, 30, 20 };

	static constexpr std::array<Value, 64> kingEndgameTable = {
	-50,-40,-30,-20,-20,-30,-40,-50,
	-30,-20,-10,  0,  0,-10,-20,-30,
	-30,-10, 20, 30, 30, 20,-10,-30,
	-30,-10, 30, 40, 40, 30,-10,-30,
	-30,-10, 30, 40, 40, 30,-10,-30,
	-30,-10, 20, 30, 30, 20,-10,-30,
	-30,-30,  0,  0,  0,  0,-30,-30,
	-50,-30,-30,-30,-30,-30,-30,-50 };

	Value evaluate(const BoardParser &b) const override
	{
		Value finalScore = 0, scorePieceWhite = 0, scorePieceBlack = 0;

		for (Int i = -1; i < 2; i += 2)
		{
			std::vector<UInt> table = (i == -1) ? b.boardParsed()->blackPos() : b.boardParsed()->whitePos();
			Value *scoreCurrent = &(i == 1 ? scorePieceWhite : scorePieceBlack);
			std::vector<UInt> pawnPositions;
			std::vector<UInt> pawnColumns;

			for (const auto &pieceIdx : table)
			{
				const Piece *p = b.boardParsed()->board()[pieceIdx];

				if (p == nullptr)
					continue;
				if (p->value() == PieceType::KING)
				{
					*scoreCurrent += 20000;
				}
				else if (p->value() == PieceType::QUEEN)
				{
					*scoreCurrent += 950;
				}
				else if (p->value() == PieceType::ROOK)
				{
					*scoreCurrent += 563;
				}
				else if (p->value() == PieceType::BISHOP)
				{
					*scoreCurrent += 333;
				}
				else if (p->value() == PieceType::KNIGHT)
				{
					*scoreCurrent += 305;
				}
				else if (p->value() == PieceType::PAWN)
				{
					*scoreCurrent += 100;
					pawnPositions.push_back(pieceIdx);
					pawnColumns.push_back(Board::column(pieceIdx));
				}
			}

			finalScore += i * (*scoreCurrent + pawnMalus(b, pawnPositions, pawnColumns));
		}

		// Once ennemy has less pieces our king attacks the other one
		// King, seven pawns a rook and a bishop
		const bool endgame = (b.isWhiteTurn() ? scorePieceBlack : scorePieceWhite) <= 20000 + 7 * 100 + 563 + 333;
		// King, six pawns a bishop and a knight
		// const bool endgameHard = (b.isWhiteTurn() ? scorePieceBlack : scorePieceWhite) <= 20000 + 4 * 100 + 333 + 305;

		for (Int i = -1; i < 2; i += 2)
		{
			std::vector<UInt> table = (i == -1) ? b.boardParsed()->blackPos() : b.boardParsed()->whitePos();
			Value score = 0;
			std::vector<cMove> moveset;

			for (const auto &pieceIdx : table)
			{
				const Piece *p = b.boardParsed()->board()[pieceIdx];
				moveset.clear();

				// Find idx in piece-square table
				Int idxTable = i == 1 ? ((BOARD_SIZE - 1) - Board::row(pieceIdx)) * BOARD_SIZE + Board::column(pieceIdx) : pieceIdx;
				if (p == nullptr)
					continue;
				if (p->value() == PieceType::KING)
				{
					p->canMove(*b.boardParsed(), moveset);
					if (endgame)
					{
						score += Value(moveset.size());
						score += kingEndgameTable[idxTable];
					}
					else
					{
						score += kingTable[idxTable] - Value(moveset.size());
					}
				}
				else if (p->value() == PieceType::QUEEN)
				{
					score += queenTable[idxTable];
				}
				else if (p->value() == PieceType::ROOK)
				{
					if (endgame)
					{
						p->canMove(*b.boardParsed(), moveset);
						score += 5 * Value(moveset.size());
					}
					score += rookTable[idxTable];
				}
				else if (p->value() == PieceType::BISHOP)
				{
					p->canMove(*b.boardParsed(), moveset);
					score += bishopTable[idxTable] + 5 * Value(moveset.size());
				}
				else if (p->value() == PieceType::KNIGHT)
				{
					score += knightTable[idxTable];
				}
				else if (p->value() == PieceType::PAWN)
				{
					score += pawnTable[idxTable];
				}
			}

			finalScore += i * score;
		}

		if (endgame)
		{
			finalScore += (b.isWhiteTurn() ? 1 : -1) * distanceKings(b);
		}

		return (b.isWhiteTurn() ? 1 : -1) * finalScore;
	}
};
