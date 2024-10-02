#pragma once

#include <algorithm>
#include <array>
#include <cmath>
#include <iostream>
#include <string>
#include <unordered_map>
#include <vector>

#include "cMove.h"
#include "include.h"

#ifdef _MSC_VER
#include <intrin.h>
#endif // _MSC_VER

class Piece;

/**
	* @brief Board	class
	* @details	This class is used to represent the board.
	*  It contains the pieces in `m_board`. Which is a 64 vector of all the cases.
	*  Index 0 is bottom left corner (A1), index 63 is top right corner (H8).
	*  It also contains the methods to check if a king is in check.
	*
	*/
class Board
{
private:
	std::array<Piece *, BOARD_SIZE2> m_board = {};
	std::vector<UInt> m_whitePos;
	std::vector<UInt> m_blackPos;
	// Column if the en passant can be done next turn, happens when a pawn double forward at row 1/6, -1 otherwise.
	Int m_enPassant = -1;

public:
	UInt *m_castleInfo = nullptr;

	Board(UInt *castleInfo)
	{
		// std::array are auto set to nullptr but des not seem to be the case
		// m_board = std::array<Piece *, BOARD_SIZE2>();
		for (auto &p : m_board)
		{
			p = nullptr;
		}
		m_whitePos.reserve(BOARD_SIZE * 2);
		m_blackPos.reserve(BOARD_SIZE * 2);
		m_enPassant = -1;
		m_castleInfo = castleInfo;
	}

	~Board()
	{}

	// Mutators
	std::array<Piece *, BOARD_SIZE2> &board() { return m_board; }

	const std::array<Piece *, BOARD_SIZE2> &board() const { return m_board; }

	void enPassant(Int i) { m_enPassant = i; }

	const Int enPassant() const { return m_enPassant; }

	Piece *operator[](std::size_t idx) { return board()[idx]; }

	const Piece *operator[](std::size_t idx) const { return board()[idx]; }

	bool operator==(const Board &b) const
	{
		auto wp = whitePos();
		auto wp2 = b.whitePos();
		auto bp = blackPos();
		auto bp2 = b.blackPos();
		std::sort(wp.begin(), wp.end());
		std::sort(wp2.begin(), wp2.end());
		std::sort(bp.begin(), bp.end());
		std::sort(bp2.begin(), bp2.end());
		if (wp != wp2 || bp != bp2)
			return false;

		if (*m_castleInfo != *b.m_castleInfo)
			return false;

		if (enPassant() != b.enPassant())
			return false;
		return true;
	}

	std::vector<UInt> &whitePos() { return m_whitePos; }

	const std::vector<UInt> &whitePos() const { return m_whitePos; }

	std::vector<UInt> &blackPos() { return m_blackPos; }

	const std::vector<UInt> &blackPos() const { return m_blackPos; }

	// constexpr will be supported in C++23
	static bool sameLine(UInt a, UInt b)
	{
		return std::floor(float(a) / float(BOARD_SIZE)) == std::floor(float(b) / float(BOARD_SIZE));
	}

	static constexpr bool sameColumn(UInt a, UInt b)
	{
		return a % BOARD_SIZE == b % BOARD_SIZE;
	}

	static constexpr bool leftCol(UInt tile)
	{
		return tile % BOARD_SIZE == 0; // is 0 % smth always true ?
	}

	static constexpr bool rightCol(UInt tile)
	{
		if (tile > BOARD_SIZE2 - 1)
			err("Going beyond board.");
		return (tile + 1) % (BOARD_SIZE) == 0;
	}

	static constexpr bool botRow(UInt tile)
	{
		return tile < BOARD_SIZE;
	}

	static constexpr bool topRow(UInt tile)
	{
		if (tile > BOARD_SIZE2 - 1)
			err("Going beyond board.");
		return tile >= BOARD_SIZE * (BOARD_SIZE - 1);
	}

	static constexpr UInt row(UInt tile)
	{
		return tile / BOARD_SIZE;
	}

	static constexpr UInt column(UInt tile)
	{
		return tile % BOARD_SIZE;
	}

	static constexpr UInt toTiles(const std::string &s)
	{
		if (s.length() != 2) return 0;
		UInt letter = s[0] - 'a';
		try
		{
			UInt number = s[1] - '0';
			if (letter > 8 || number > 8)
			{
				err("Invalid tile.");
				return 0;
			}
			return letter + (number - 1) * BOARD_SIZE;
		}
		catch (const std::exception &) { return 0; }
	}

	static constexpr std::string toString(const UInt tile)
	{
		return std::string(1, char('a' + tile % BOARD_SIZE)) + std::string(1, char('1' + (tile / BOARD_SIZE)));
	}
};

enum PieceType : UInt
{
	NONE,
	PAWN,
	KNIGHT,
	BISHOP,
	ROOK,
	QUEEN,
	KING,
	ALL,
	NB
};

enum Color
{
	BLACK,
	WHITE,
	COLOR_NB // rename en NB
};

class Bitboards
{
public:
	static Bitboard bbPieces[PieceType::NB];
	static Bitboard bbColors[Color::COLOR_NB];

	static constexpr Bitboard column = 0x0101010101010101ULL; // A file
	static constexpr Bitboard row = 0xFFULL; // First rank
	static constexpr Bitboard diagonalClockwise = 0b1000000001000000001000000001000000001000000001000000001000000001;
	static constexpr Bitboard diagonalCounterClockwise = 0b0000000100000010000001000000100000010000001000000100000010000000;

	static Bitboard movesRook[BOARD_SIZE2];
	static Bitboard movesRookMask[BOARD_SIZE2];
	static std::unordered_map<Bitboard, Bitboard> movesRookLegal[BOARD_SIZE2]; // Key: Blocker bb; Value: Moveable tiles bb.

	static Bitboard movesBishop[BOARD_SIZE2];
	static Bitboard movesBishopMask[BOARD_SIZE2];
	static std::unordered_map<Bitboard, Bitboard> movesBishopLegal[BOARD_SIZE2]; // Key: Blocker bb; Value: Moveable tiles bb.

	static Bitboard movesKnight[BOARD_SIZE2];

	static void clear()
	{
		for (UInt p = PieceType::NONE; p < PieceType::NB; ++p)
		{
			Bitboards::bbPieces[p] = 0;
		}
		Bitboards::bbColors[0] = 0;
		Bitboards::bbColors[1] = 0;
	}

	static void remove(PieceType p, Color c, UInt tile)
	{
		const Bitboard removeFilter = ~Bitboards::tileToBB(tile);
		Bitboards::bbPieces[p] &= removeFilter;
		Bitboards::bbPieces[PieceType::ALL] &= removeFilter;
		Bitboards::bbColors[c] &= removeFilter;
	}

	static void add(PieceType p, Color c, UInt tile)
	{
		const Bitboard addFilter = Bitboards::tileToBB(tile);
		Bitboards::bbPieces[p] |= addFilter;
		Bitboards::bbPieces[PieceType::ALL] |= addFilter;
		Bitboards::bbColors[c] |= addFilter;
	}

	static void removeAdd(PieceType p, Color c, UInt removeTile, UInt addTile)
	{
		const Bitboard removeFilter = Bitboards::tileToBB(removeTile) | Bitboards::tileToBB(addTile);
		Bitboards::bbPieces[p] ^= removeFilter;
		Bitboards::bbPieces[PieceType::ALL] ^= removeFilter;
		Bitboards::bbColors[c] ^= removeFilter;
	}

	static void computeAll()
	{
		for (UInt p = PieceType::NONE + 1; p < PieceType::ALL; ++p)
		{
			Bitboards::bbPieces[PieceType::ALL] |= Bitboards::bbPieces[p];
		}
	}

	static void displayBBCLI(const Bitboard bb)
	{
		std::string out;
		for (UInt counter = BOARD_SIZE2 - BOARD_SIZE; counter != BOARD_SIZE - 1; ++counter)
		{
			Bitboard value = bb & Bitboards::tileToBB(counter);
			out.append("|");
			if (value == 0)
			{
				out.append(" ");
			}
			else
			{
				out.append("X");
			}
			if (Board::column(counter + 1) == 0)
			{
				out.append("|\n");
				counter -= BOARD_SIZE * 2;
			}
		}
		out.append("|");
		Bitboard value = bb & Bitboards::tileToBB(BOARD_SIZE - 1);
		if (value == 0)
		{
			out.append(" ");
		}
		else
		{
			out.append("X");
		}

		std::cout << out << std::string("|") << std::endl << std::endl;
	}

	static void displayBBCLI()
	{
		for (UInt p = PieceType::NONE; p < PieceType::NB; ++p)
		{
			displayBBCLI(Bitboards::bbPieces[p]);
		}

		for (UInt c = Color::BLACK; c < Color::COLOR_NB; ++c)
		{
			displayBBCLI(Bitboards::bbColors[c]);
		}
	}

	static constexpr Bitboard tileToBB(UInt tile)
	{
		return (0b1ULL << tile);
	}

	// bb has to be non-zero
	static inline UInt leastBit(Bitboard &bb)
	{
		unsigned long lsbIndex;
#ifdef _MSC_VER
		_BitScanForward64(&lsbIndex, bb); // Find index of the least significant set bit
#else
		lsbIndex = __builtin_ffsll(bb) - 1;
#endif
		return static_cast<UInt>(lsbIndex);
	}

	// bb has to be non-zero
	static inline UInt popLeastBit(Bitboard &bb)
	{
		UInt idx = Bitboards::leastBit(bb);
		bb &= bb - 1; // Clear the least significant set bit
		return idx;
	}

	static inline Bitboard allPiecesColor(const Color col)
	{
		return bbPieces[PieceType::ALL] & bbColors[col];
	}

	static inline UInt popCount(const Bitboard &bb)
	{
#ifdef _MSC_VER
		return UInt(__popcnt64(bb));
#else
		return UInt(__builtin_popcountll(bb));
#endif // _MSC_VER
	}

	static inline std::vector<UInt> getBitIndices(Bitboard bb)
	{
		std::vector<UInt> indices;
		indices.reserve(Bitboards::popCount(bb));

		while (bb)
		{
			indices.push_back(Bitboards::popLeastBit(bb));
		}

		return indices;
	}

	static void displayBitIndices(Bitboard bb)
	{
		for (Int i = 63; i >= 0; --i)
		{
			if (bb & Bitboards::tileToBB(i))
			{
				std::cout << "X";
			}
			else
			{
				std::cout << "O";
			}
			if (i % BOARD_SIZE == 0)
				std::cout << std::endl;
		}
		std::cout << std::endl;
	}

#ifdef _MSC_VER
	static constexpr void generateMoves(std::vector<cMove> &moveList, Bitboard bb, UInt from, UInt flags = 0)
	{
		while (bb)
		{
			moveList.push_back(cMove(from, Bitboards::popLeastBit(bb), flags));
		}
	}
#else
	static constexpr void generateMoves(std::vector<cMove> &moveList, Bitboard bb, UInt from, UInt flags = 0)
	{
		for (UInt i = std::max<Int>(Int(0), Int(from) - Int(BOARD_SIZE * 3)); bb != 0ULL && i < std::min<UInt>(BOARD_SIZE2, from + BOARD_SIZE * 3); ++i)
			for (UInt j = 0; bb != 0ULL && j < 64; ++j)
			{
				if (bb & Bitboards::tileToBB(j))
				{
					moveList.push_back(cMove(from, j, flags));
				}
			}
	}
#endif // _MSC_VER

	static constexpr Bitboard filterAdjacent(UInt tile)
	{
		const UInt colIdx = Board::column(tile);
		return ((Bitboards::column << std::max<Int>(Int(0), Int(colIdx) - 1)) | (Bitboards::column << std::min(BOARD_SIZE - 1, colIdx + 1))) & ~(Bitboards::column << colIdx);
	}

	static void computeBlockers(const Bitboard mask, std::vector<Bitboard> &v)
	{
		std::vector<UInt> bitIndices = Bitboards::getBitIndices(mask);
		for (Bitboard blockerConfiguration = 1; blockerConfiguration < (Bitboard(1) << bitIndices.size()); ++blockerConfiguration)
		{
			Bitboard currentBlockerBB = 0;
			for (UInt bitIdx = 0; bitIdx < bitIndices.size(); ++bitIdx)
			{
				Bitboard currentBit = (blockerConfiguration >> bitIdx) & 1; // Is the shifted bit in blockerMask activated
				currentBlockerBB |= currentBit << bitIndices[bitIdx]; // Shift it back to its position
			}
			v.push_back(currentBlockerBB);
		}
	}
};
