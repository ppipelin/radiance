#pragma once

#include <algorithm>
#include <unordered_map>

#include "boardParser.h"
#include "evaluate.h"
#include "include.h"

class EvaluateShannon : virtual public Evaluate
{
public:
	EvaluateShannon() = default;
	EvaluateShannon(const EvaluateShannon &) = default;
	~EvaluateShannon() = default;

	// Should be precomputed for 64-16 tiles and both colors
	Bitboard filterPassedPawn(UInt tile, Color col) const
	{
		UInt colIdx = Board::column(tile);
		Bitboard filterAdjacent = (Bitboards::column << colIdx) | Bitboards::filterAdjacent(tile);
		UInt rowIdx = Board::row(tile);
		Bitboard filterTopBot = col == Color::WHITE ? bbMax << BOARD_SIZE * (rowIdx + 1) : bbMax >> BOARD_SIZE * (BOARD_SIZE - rowIdx);
		return filterAdjacent & filterTopBot;
	}

	Bitboard filterIsolatedPawn(UInt tile) const
	{
		UInt colIdx = Board::column(tile);
		Int minCol = 0;
		UInt maxCol = BOARD_SIZE - 1;
		if (colIdx == 0) minCol = 1;
		if (colIdx == BOARD_SIZE - 1) maxCol = BOARD_SIZE - 2;
		return (Bitboards::column << std::max<Int>(minCol, Int(colIdx - 1))) | (Bitboards::column << std::min<UInt>(maxCol, colIdx + 1));
	}

	Bitboard filterDoubledPawn(UInt tile) const
	{
		UInt colIdx = Board::column(tile);
		return (Bitboards::column << colIdx);
	}

	Value pawnMalus(const BoardParser &b, const std::vector<UInt> &pawnPositions, const std::vector<UInt> &pawnColumns) const
	{
		Value score = 0;
		if (pawnPositions.empty())
		{
			return score;
		}
		// Doubled pawn
		std::vector<UInt> pawnColumsUnique(pawnColumns);
		std::sort(pawnColumsUnique.begin(), pawnColumsUnique.end());
		const auto last = std::unique(pawnColumsUnique.begin(), pawnColumsUnique.end());
		pawnColumsUnique.erase(last, pawnColumsUnique.end());
		score -= 40 * Value(pawnColumns.size() - pawnColumsUnique.size());

		for (const auto &i : pawnPositions)
		{
			const Piece *piece = (*b.boardParsed())[i];
			// Blocked pawn
			// Should never be out of range because a pawn cannot be on a last rank
			if (piece->isWhite() ? (*b.boardParsed())[i + BOARD_SIZE] != nullptr : (*b.boardParsed())[i - BOARD_SIZE] != nullptr)
			{
				// Increased when blocked by opponent
				if (piece->isWhite() ? !(*b.boardParsed())[i + BOARD_SIZE]->isWhite() : (*b.boardParsed())[i - BOARD_SIZE]->isWhite())
					score -= 40;
				else
					score -= 25;
			}

			// Isolated pawn
			UInt pieceColumn = Board::column(i);
			if (std::find(pawnColumns.begin(), pawnColumns.end(), pieceColumn + 1) == pawnColumns.end() || std::find(pawnColumns.begin(), pawnColumns.end(), pieceColumn - 1) == pawnColumns.end())
			{
				score -= 50;
			}
		}
		return score;
	}

	Value evaluate(const BoardParser &b) const override
	{
		// 200(K-K')
		//      + 9(Q-Q')
		//      + 5(R-R')
		//      + 3(B-B' + N-N')
		//      + 1(P-P')
		//      - 0.5(D-D' + S-S' + I-I')
		//      + 0.1(M-M') + ...
		// KQRBNP = number of kings, queens, rooks, bishops, knights and pawns
		// D,S,I = doubled, blocked and isolated pawns
		// M = Mobility (the number of legal moves)
		Value finalScore = 0;
		for (Int i = -1; i < 2; i += 2)
		{
			std::vector<UInt> table = (i == -1) ? b.boardParsed()->blackPos() : b.boardParsed()->whitePos();
			Value score = 0;
			std::vector<UInt> pawnPositions;
			std::vector<UInt> pawnColumns;

			for (const auto &pieceIdx : table)
			{
				const Piece *p = b.boardParsed()->board()[pieceIdx];
				if (p == nullptr)
					continue;
				if (p->value() == PieceType::KING)
					score += 20000;
				else if (p->value() == PieceType::QUEEN)
					score += 900;
				else if (p->value() == PieceType::ROOK)
					score += 500;
				else if (p->value() == PieceType::BISHOP)
					score += 300;
				else if (p->value() == PieceType::KNIGHT)
					score += 300;
				else if (p->value() == PieceType::PAWN)
				{
					score += 100;
					pawnPositions.push_back(pieceIdx);
					pawnColumns.push_back(Board::column(pieceIdx));
				}

				std::vector<cMove> moveset;
				p->canMove(*b.boardParsed(), moveset);
				score += 10 * Value(moveset.size());
			}

			score += 50 * pawnMalus(b, pawnPositions, pawnColumns);

			finalScore += i * score;
		}
		return (b.isWhiteTurn() ? 1 : -1) * finalScore;
	}
};
