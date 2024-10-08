#include <string>
#include <vector>

#include "board.h"
#include "cMove.h"
#include "include.h"
#include "pawn.h"

void Pawn::canMove(const Board &b, std::vector<cMove> &v) const
{
	const UInt c = Board::column(m_tile);
	// Default behavior, we push_back() to v
	std::vector<cMove> tmp = std::vector<cMove>();
	std::vector<cMove> *vRef = &tmp;
	// Promotion cases uses temporary vector to duplicate moveset during promotion
	const bool promotion = (m_isWhite && Board::row(m_tile + BOARD_SIZE) == BOARD_SIZE - 1) || (!m_isWhite && Board::row(m_tile - BOARD_SIZE) == 0);
	if (promotion)
	{
		vRef->reserve(4);
		v.reserve(v.size() + 4 * 4);
	}
	else
	{
		vRef = &v;
		vRef->reserve(vRef->size() + 4);
	}

	if (m_isWhite)
	{
		// Can move forward
		if (Board::row(m_tile) < BOARD_SIZE - 1)
		{
			UInt forward = m_tile + BOARD_SIZE;
			// Forward and double forward
			if (b[forward] == nullptr)
			{
				vRef->push_back(cMove(m_tile, forward));
				if (Board::row(m_tile) == 1 && b[forward + BOARD_SIZE] == nullptr)
					vRef->push_back(cMove(m_tile, forward + BOARD_SIZE));
			}
			// Forward left (checks white + not on first column)
			if (!Board::leftCol(m_tile) && b[forward - 1] != nullptr && !b[forward - 1]->isWhite())
				vRef->push_back(cMove(m_tile, forward - 1, 4));
			// Forward right (checks white + not on last column)
			if (!Board::rightCol(m_tile) && b[forward + 1] != nullptr && !b[forward + 1]->isWhite())
				vRef->push_back(cMove(m_tile, forward + 1, 4));
			// Adding en passant
			Int enPassantCol = b.enPassant();
			if (Board::row(m_tile) == 4 && enPassantCol != -1)
			{
				if (enPassantCol == Int(c + 1))
				{
					vRef->push_back(cMove(m_tile, m_tile + BOARD_SIZE + 1, 5));
				}
				else if (enPassantCol == Int(c - 1))
				{
					vRef->push_back(cMove(m_tile, m_tile + BOARD_SIZE - 1, 5));
				}
			}
		}
	}
	else
	{
		// Can move forward
		if (Board::row(m_tile) > 0)
		{
			UInt forward = m_tile - BOARD_SIZE;
			// Forward and double forward
			if (b[forward] == nullptr)
			{
				vRef->push_back(cMove(m_tile, forward));
				if (Board::row(m_tile) == BOARD_SIZE - 2 && b[forward - BOARD_SIZE] == nullptr)
					vRef->push_back(cMove(m_tile, forward - BOARD_SIZE));
			}
			// Forward left (checks black + not on first column)
			if (!Board::leftCol(m_tile) && b[forward - 1] != nullptr && b[forward - 1]->isWhite())
				vRef->push_back(cMove(m_tile, forward - 1, 4));
			// One black forward right (checks black + not on last column)
			if (!Board::rightCol(m_tile) && b[forward + 1] != nullptr && b[forward + 1]->isWhite())
				vRef->push_back(cMove(m_tile, forward + 1, 4));
			// Adding en passant
			Int enPassantCol = b.enPassant();
			if (Board::row(m_tile) == 3 && enPassantCol != -1)
			{
				if (enPassantCol == Int(c + 1))
				{
					vRef->push_back(cMove(m_tile, m_tile - BOARD_SIZE + 1, 5));
				}
				else if (enPassantCol == Int(c - 1))
				{
					vRef->push_back(cMove(m_tile, m_tile - BOARD_SIZE - 1, 5));
				}
			}
		}
	}
	// If we are going to the last rank, previous computed moves are promotions
	if ((m_isWhite && Board::row(m_tile + BOARD_SIZE) == BOARD_SIZE - 1) || (!m_isWhite && Board::row(m_tile - BOARD_SIZE) == 0))
	{
		for (auto &move : *vRef)
		{
			if (move.isCapture())
			{
				move.setFlags(12);
				v.push_back(move);
				move.setFlags(13);
				v.push_back(move);
				move.setFlags(14);
				v.push_back(move);
				move.setFlags(15);
				v.push_back(move);
			}
			else
			{
				move.setFlags(8);
				v.push_back(move);
				move.setFlags(9);
				v.push_back(move);
				move.setFlags(10);
				v.push_back(move);
				move.setFlags(11);
				v.push_back(move);
			}
		}
	}
}

bool Pawn::exists() const
{
	return true;
}

std::string Pawn::str() const
{
	return m_isWhite ? "P" : "p";
}
