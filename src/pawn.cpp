#include "pawn.h"

// Should be precomputed
Bitboard filterCaptures(UInt tile, Color col)
{
	Bitboard filterAdjacent = Bitboards::filterAdjacent(tile);
	Bitboard filterTopBot = Bitboards::row << (BOARD_SIZE * (Board::row(tile) + ((col == Color::WHITE) ? 1 : -1)));
	return filterAdjacent & filterTopBot;
}

Bitboard filterForward(UInt tile, Color col)
{
	Bitboard b = 0ULL;
	if (col == Color::WHITE)
	{
		if (Board::row(tile) == 1)
			b = Bitboards::tileToBB(tile) << BOARD_SIZE * 2;
		b |= Bitboards::tileToBB(tile) << BOARD_SIZE;
	}
	else
	{
		if (Board::row(tile) == BOARD_SIZE - 2)
			b = Bitboards::tileToBB(tile) >> BOARD_SIZE * 2;
		b |= Bitboards::tileToBB(tile) >> BOARD_SIZE;
	}
	return b;
}

void Pawn::canMove(const Board &b, std::vector<cMove> &v) const
{
	const UInt c = Board::column(m_tile);
	// Default behavior, we push_back() to v
	std::vector<cMove> tmp = std::vector<cMove>();
	std::vector<cMove> *vRef = &tmp;
	// Promotion cases uses temporary vector to duplicate moveset during promotion
	const bool promotion = m_isWhite && Board::row(m_tile + BOARD_SIZE) == BOARD_SIZE - 1 || !m_isWhite && Board::row(m_tile - BOARD_SIZE) == 0;
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

	Color col = Color(m_isWhite);
	// Update filterC in case of enPassant
	Int enPassantCol = b.enPassant();
	if (enPassantCol != -1)
	{
		Bitboard	enPassantTile = m_isWhite ? Bitboards::row << BOARD_SIZE * 5 : Bitboards::row << BOARD_SIZE * 2; // Row filter
		enPassantTile &= Bitboards::column << enPassantCol; // Column filter
		// Once we have the enPassantTile, we assert it can be taken from tile
		// Create a front 'corner' pattern and check if intersects with tile
		// Front direction is determined from the current turn
		Bitboard enPassantFilter = m_isWhite ? (enPassantTile >> (BOARD_SIZE + 1)) | (enPassantTile >> (BOARD_SIZE - 1)) : (enPassantTile << (BOARD_SIZE + 1)) | (enPassantTile << (BOARD_SIZE - 1));
		// Pattern has to not overlap the board
		enPassantFilter &= Bitboards::filterAdjacent(Bitboards::getBitIndices(enPassantTile).front());
		if (enPassantFilter & Bitboards::tileToBB(m_tile))
			Bitboards::generateMoves(*vRef, enPassantTile, m_tile, 5);
	}
	Bitboard filterC = filterCaptures(m_tile, col) & Bitboards::bbColors[Color(!m_isWhite)];

	// A filter way to prevent going through a piece when moving by two tiles is to double the third row up and sixth row down
	Bitboard thirdOrSixthDoubled = 0ULL;
	// Remove m_tile in case pawn is on this row
	const Bitboard tileBB = Bitboards::tileToBB(m_tile);
	if (m_isWhite)
		thirdOrSixthDoubled = ((Bitboards::row << BOARD_SIZE * 2) & Bitboards::bbPieces[PieceType::ALL] & ~tileBB) << BOARD_SIZE;
	else
		thirdOrSixthDoubled = ((Bitboards::row << BOARD_SIZE * 5) & Bitboards::bbPieces[PieceType::ALL] & ~tileBB) >> BOARD_SIZE;
	Bitboard filterF = filterForward(m_tile, col) & ~Bitboards::bbPieces[PieceType::ALL] & ~thirdOrSixthDoubled;

	Bitboards::generateMoves(*vRef, filterC, m_tile, 4);
	Bitboards::generateMoves(*vRef, filterF, m_tile, 0);

	// if (m_isWhite)
	// {
	// 	// Can move forward
	// 	if (Board::row(m_tile) < BOARD_SIZE - 1)
	// 	{
	// 		UInt forward = m_tile + BOARD_SIZE;
	// 		// Forward and double forward
	// 		if (b[forward] == nullptr)
	// 		{
	// 			vRef->push_back(cMove(m_tile, forward));
	// 			if (Board::row(m_tile) == 1 && b[forward + BOARD_SIZE] == nullptr)
	// 				vRef->push_back(cMove(m_tile, forward + BOARD_SIZE));
	// 		}
	// 		// Forward left (checks white + not on first column)
	// 		if (!Board::leftCol(m_tile) && b[forward - 1] != nullptr && !b[forward - 1]->isWhite())
	// 			vRef->push_back(cMove(m_tile, forward - 1, 4));
	// 		// Forward right (checks white + not on last column)
	// 		if (!Board::rightCol(m_tile) && b[forward + 1] != nullptr && !b[forward + 1]->isWhite())
	// 			vRef->push_back(cMove(m_tile, forward + 1, 4));
	// 		// Adding en passant
	// 		Int enPassantCol = b.enPassant();
	// 		if (Board::row(m_tile) == 4 && enPassantCol != -1)
	// 		{
	// 			if (enPassantCol == Int(c + 1))
	// 			{
	// 				vRef->push_back(cMove(m_tile, m_tile + BOARD_SIZE + 1, 5));
	// 			}
	// 			else if (enPassantCol == Int(c - 1))
	// 			{
	// 				vRef->push_back(cMove(m_tile, m_tile + BOARD_SIZE - 1, 5));
	// 			}
	// 		}
	// 	}
	// }
	// else
	// {
	// 	// Can move forward
	// 	if (Board::row(m_tile) > 0)
	// 	{
	// 		UInt forward = m_tile - BOARD_SIZE;
	// 		// Forward and double forward
	// 		if (b[forward] == nullptr)
	// 		{
	// 			vRef->push_back(cMove(m_tile, forward));
	// 			if (Board::row(m_tile) == BOARD_SIZE - 2 && b[forward - BOARD_SIZE] == nullptr)
	// 				vRef->push_back(cMove(m_tile, forward - BOARD_SIZE));
	// 		}
	// 		// Forward left (checks black + not on first column)
	// 		if (!Board::leftCol(m_tile) && b[forward - 1] != nullptr && b[forward - 1]->isWhite())
	// 			vRef->push_back(cMove(m_tile, forward - 1, 4));
	// 		// One black forward right (checks black + not on last column)
	// 		if (!Board::rightCol(m_tile) && b[forward + 1] != nullptr && b[forward + 1]->isWhite())
	// 			vRef->push_back(cMove(m_tile, forward + 1, 4));
	// 		// Adding en passant
	// 		Int enPassantCol = b.enPassant();
	// 		if (Board::row(m_tile) == 3 && enPassantCol != -1)
	// 		{
	// 			if (enPassantCol == Int(c + 1))
	// 			{
	// 				vRef->push_back(cMove(m_tile, m_tile - BOARD_SIZE + 1, 5));
	// 			}
	// 			else if (enPassantCol == Int(c - 1))
	// 			{
	// 				vRef->push_back(cMove(m_tile, m_tile - BOARD_SIZE - 1, 5));
	// 			}
	// 		}
	// 	}
	// }
	// If we are going to the last rank, previous computed moves are promotions
	if (m_isWhite && Board::row(m_tile + BOARD_SIZE) == BOARD_SIZE - 1 || !m_isWhite && Board::row(m_tile - BOARD_SIZE) == 0)
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
