#pragma once

#include "search.h"

class SearchRandom : virtual public Search
{
public:
	SearchRandom() {}
	SearchRandom(const SearchRandom &) {}
	~SearchRandom() {}

	cMove nextMove(BoardParser *b) override
	{
		std::vector<cMove> moveList = std::vector<cMove>();
		for (UInt tile = 0; tile < BOARD_SIZE2; ++tile)
		{
			std::vector<cMove> subMoveList = std::vector<cMove>();
			const Piece *piece = b->boardParsed()->board()[tile];
			if (piece == nullptr || (piece->isWhite() != b->isWhiteTurn()))
			{
				continue;
			}
			if (piece->isWhite() != b->isWhiteTurn())
			{
				warn("is wrong turn");
			}
			piece->canMove(*b->boardParsed(), subMoveList);
			moveList.insert(moveList.end(), subMoveList.begin(), subMoveList.end());
		}
		if (moveList.empty())
		{
			err("Cannot move after checkmate.");
			return cMove(0, 0);
		}
		// Verify not in check
		BoardParser b2 = BoardParser(*b);
		cMove move;
		do
		{
			b2 = BoardParser(*b);

			UInt idx = UInt(double(std::rand()) / double(RAND_MAX) * double(moveList.size()));
			move = moveList[idx];
			b2.movePiece(move);
			moveList.erase(moveList.begin() + idx);
		} while (b2.inCheck(!b2.isWhiteTurn()) && !moveList.empty());
		if (moveList.empty())
		{
			err("Cannot move after checkmate.");
			return cMove(0, 0);
		}
		return move;
	}
};