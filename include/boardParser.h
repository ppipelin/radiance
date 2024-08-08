#pragma once

#include "include.h"

#include "piece.h"
#include "pawn.h"
#include "king.h"
#include "queen.h"
#include "rook.h"
#include "bishop.h"
#include "knight.h"

#include "board.h"
#include "cMove.h"

#include <sstream>
#include <algorithm>

namespace {
	namespace Zobrist {
		// KQRBNPkqrbnp
		Key psq[12][BOARD_SIZE2];
		// KQkq
		Key enPassant[BOARD_SIZE];
		Key castling[4];
		Key side;
	}
}

/**
	* @brief This class is used to parse the board and is aware of the Piece's type.
	* @details To be able to know the if castle is available, it contains the movePiece() function.
	*/
class BoardParser
{
private:
	Board *m_board;
	bool m_isWhiteTurn;
	UInt m_whiteKing = 4;
	UInt m_blackKing = 60;
	const std::string m_starting = std::string("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");

public:

	struct State
	{
		State(const BoardParser &b, State *previousState = nullptr)
		{
			castleInfo = b.m_s->castleInfo;
			rule50 = b.m_s->rule50;
			repetition = b.m_s->repetition;
			enPassant = b.m_s->enPassant;
			materialKey = b.m_s->materialKey;
			lastCapturedPiece = nullptr;
			previous = previousState;
		}
		State() = default;
		State &operator=(const State &b) = default;

		bool operator==(const State &rs) const
		{
			if (this == &rs)
				return true;
			std::cout << "";
			return true;
			return castleInfo == rs.castleInfo && rule50 == rs.rule50 && repetition == rs.repetition && enPassant == rs.enPassant && materialKey == rs.materialKey;
		}

		UInt castleInfo = 0b1111;
		UInt rule50 = 0;
		Int repetition = 0; // Zero if no repetition, x positive if happened once x half moves ago, negative indicates repetition
		Int enPassant = -1;
		Key materialKey = 0;
		Piece *lastCapturedPiece = nullptr;
		State *previous = nullptr;
	};

	// m_s is not initialized, just replaced during movePiece
	BoardParser::State *m_s = nullptr;

	BoardParser()
	{
		m_board = new Board(&m_s->castleInfo);
		m_isWhiteTurn = true;

		PRNG rng(1070372);

		for (UInt pc = 0; pc < 12; ++pc)
			for (UInt tile = 0; tile < BOARD_SIZE2; ++tile)
				Zobrist::psq[pc][tile] = rng.rand<Key>();

		for (UInt col = 0; col <= BOARD_SIZE; ++col)
			Zobrist::enPassant[col] = rng.rand<Key>();

		for (UInt cr = 0; cr < 4; ++cr)
			Zobrist::castling[cr] = rng.rand<Key>();

		Zobrist::side = rng.rand<Key>();
	}

	~BoardParser()
	{
		for (auto &i : m_board->board())
		{
			if (i != nullptr)
			{
				delete i;
				i = nullptr;
			}
		}
		delete m_board;
	}

	BoardParser(const BoardParser &b, BoardParser::State *s = nullptr)
	{
		// Guard self assignment
		if (this == &b)
			return;

		// Since states are local variable we pass its new address
		m_s = s;
		m_board = new Board(&m_s->castleInfo);
		m_isWhiteTurn = b.isWhiteTurn();
		for (UInt i = 0; i < BOARD_SIZE2; ++i)
		{
			const Piece *p = b.boardParsed()->board()[i];
			if (p == nullptr)
				continue;
			if (p->value() == PieceType::KING)
				m_board->board()[i] = new King(*(*b.boardParsed())[i]);
			else if (p->value() == PieceType::QUEEN)
				m_board->board()[i] = new Queen(*(*b.boardParsed())[i]);
			else if (p->value() == PieceType::ROOK)
				m_board->board()[i] = new Rook(*(*b.boardParsed())[i]);
			else if (p->value() == PieceType::BISHOP)
				m_board->board()[i] = new Bishop(*(*b.boardParsed())[i]);
			else if (p->value() == PieceType::KNIGHT)
				m_board->board()[i] = new Knight(*(*b.boardParsed())[i]);
			else if (p->value() == PieceType::PAWN)
				m_board->board()[i] = new Pawn(*(*b.boardParsed())[i]);
		}
		m_board->whitePos() = b.boardParsed()->whitePos();
		m_board->blackPos() = b.boardParsed()->blackPos();
		whiteKing(b.whiteKing());
		blackKing(b.blackKing());

		m_s->castleInfo = b.m_s->castleInfo;
		m_board->enPassant(b.boardParsed()->enPassant());
	}

	// operator= has to be an assignement
	BoardParser &operator=(const BoardParser &b)
	{
		// Guard self assignment
		if (this == &b)
			return *this;

		// Delete previous data before overriding, keep m_board
		for (auto &i : m_board->board())
		{
			if (i != nullptr)
			{
				delete i;
				i = nullptr;
			}
		}
		m_s = b.m_s;
		m_isWhiteTurn = b.isWhiteTurn();
		for (UInt i = 0; i < BOARD_SIZE2; ++i)
		{
			Piece *p = b.boardParsed()->board()[i];
			if (p == nullptr)
				continue;
			if (p->value() == PieceType::KING)
				m_board->board()[i] = new King(*(*b.boardParsed())[i]);
			else if (p->value() == PieceType::QUEEN)
				m_board->board()[i] = new Queen(*(*b.boardParsed())[i]);
			else if (p->value() == PieceType::ROOK)
				m_board->board()[i] = new Rook(*(*b.boardParsed())[i]);
			else if (p->value() == PieceType::BISHOP)
				m_board->board()[i] = new Bishop(*(*b.boardParsed())[i]);
			else if (p->value() == PieceType::KNIGHT)
				m_board->board()[i] = new Knight(*(*b.boardParsed())[i]);
			else if (p->value() == PieceType::PAWN)
				m_board->board()[i] = new Pawn(*(*b.boardParsed())[i]);
		}
		m_board->whitePos() = b.boardParsed()->whitePos();
		m_board->blackPos() = b.boardParsed()->blackPos();
		whiteKing(b.whiteKing());
		blackKing(b.blackKing());

		m_s->castleInfo = b.m_s->castleInfo;
		return *this;
	}

	bool operator==(const BoardParser &b) const
	{
		if (this == &b)
			return true;

		if (m_isWhiteTurn != b.isWhiteTurn())
			return false;
		for (UInt i = 0; i < BOARD_SIZE2; ++i)
		{
			Piece *p = b.boardParsed()->board()[i];
			Piece *p_this = m_board->board()[i];
			if (p == nullptr && p_this == nullptr)
				continue;
			// Shouldn't be any nullptr now
			if (p == nullptr || p_this == nullptr)
				return false;
			if (typeid(*p) != typeid(*p_this))
				return false;
		}

		if (*m_s != *b.m_s)
			return false;

		if (whiteKing() != b.whiteKing() || blackKing() != b.blackKing())
			return false;

		return *boardParsed() == *b.boardParsed();
	}

	// Mutators
	Board *boardParsed() { return m_board; }

	const Board *boardParsed() const { return m_board; }

	void turn(const bool isWhiteTurn) { m_isWhiteTurn = isWhiteTurn; }

	const bool isWhiteTurn() const { return m_isWhiteTurn; }

	void whiteKing(const UInt whiteKing) { m_whiteKing = whiteKing; }

	const UInt whiteKing() const { return m_whiteKing; }

	void blackKing(const UInt blackKing) { m_blackKing = blackKing; }

	const UInt blackKing() const { return m_blackKing; }

	/**
		* @brief
		*
		* @param move : moving flags as depicted in https://www.chessprogramming.org/Encoding_Moves#From-To_Based
		* @return true : move successful
		* @return false : move illegal
		*/
	bool movePiece(cMove const &move, BoardParser::State &s)
	{
		// Reset data and set as previous
		s.castleInfo = m_s->castleInfo;
		// Increment ply counters. In particular, rule50 will be reset to zero later on in case of a capture or a pawn move.
		s.rule50 = m_s->rule50 + 1;
		s.enPassant = -1;
		s.materialKey = m_s->materialKey;
		s.lastCapturedPiece = nullptr;
		s.previous = m_s;
		m_s = &s;

		m_board->m_castleInfo = &m_s->castleInfo;

		UInt to = move.getTo();
		UInt from = move.getFrom();
		UInt flags = move.getFlags();
		Piece *fromPiece = m_board->board()[from];
		Piece *toPiece = m_board->board()[to];

		if (fromPiece == nullptr)
		{
			err("moving a nullptr");
			return false;
		}

		// Remove last enPassant
		if (s.previous->enPassant != -1)
		{
			m_s->materialKey ^= Zobrist::enPassant[Board::column(m_board->enPassant())];
			m_board->enPassant(-1);
		}

		// Disable castle if king/rook is moved
		if (fromPiece->value() == PieceType::KING)
		{
			if (fromPiece->isWhite())
			{
				whiteKing(to);
				if (s.previous->castleInfo & 0b0100)
					m_s->materialKey ^= Zobrist::castling[0];
				if (s.previous->castleInfo & 0b1000)
					m_s->materialKey ^= Zobrist::castling[1];
				s.castleInfo &= ~0b1100;
			}
			else
			{
				blackKing(to);
				if (s.previous->castleInfo & 0b0001)
					m_s->materialKey ^= Zobrist::castling[2];
				if (s.previous->castleInfo & 0b010)
					m_s->materialKey ^= Zobrist::castling[3];
				s.castleInfo &= ~0b0011;
			}
		}
		else if (fromPiece->value() == PieceType::ROOK)
		{
			const bool white = fromPiece->isWhite();
			if (Board::column(from) == 7)
			{
				if (m_s->castleInfo & (white ? 0b0100 : 0b0001))
				{
					m_s->materialKey ^= Zobrist::castling[(white ? 0 : 2)];
					m_s->castleInfo &= white ? ~0b0100 : ~0b0001;
				}
			}
			else	if (Board::column(from) == 0)
			{
				if (m_s->castleInfo & (white ? 0b1000 : 0b0010))
				{
					m_s->materialKey ^= Zobrist::castling[(white ? 1 : 3)];
					m_s->castleInfo &= white ? ~0b1000 : ~0b0010;
				}
			}
		}
		else if (fromPiece->value() == PieceType::PAWN)
		{
			// Updates enPassant if possible next turn
			if (fabs(Int(from) - Int(to)) == 16)
			{
				s.enPassant = Board::column(to);
				m_board->enPassant(s.enPassant);
				m_s->materialKey ^= Zobrist::enPassant[s.enPassant];
			}
			else
			{
				// En passant
				if (!Board::sameColumn(from, to) && m_board->board()[to] == nullptr)
				{
					// Should never be nullptr
					UInt enPassantTile = to + (fromPiece->isWhite() ? -Int(BOARD_SIZE) : BOARD_SIZE);

					s.lastCapturedPiece = m_board->board()[enPassantTile];

					// Remove
					Bitboards::remove(PieceType::PAWN, Color(s.lastCapturedPiece->isWhite()), enPassantTile);
					m_s->materialKey ^= Zobrist::psq[(s.lastCapturedPiece->isWhite() ? 0 : 6) + 6 - s.lastCapturedPiece->value()][enPassantTile];

					m_board->board()[enPassantTile] = nullptr;
					// Remove in color table
					if (fromPiece->isWhite())
					{
						m_board->blackPos().erase(std::find(m_board->blackPos().begin(), m_board->blackPos().end(), enPassantTile));
					}
					else
					{
						m_board->whitePos().erase(std::find(m_board->whitePos().begin(), m_board->whitePos().end(), enPassantTile));
					}
				}

				// Promotion
				if (move.isPromotion())
				{
					// Before delete we store the data we need
					const bool isWhite = fromPiece->isWhite();
					// Remove
					Bitboards::remove(PieceType::PAWN, Color(isWhite), from);
					m_s->materialKey ^= Zobrist::psq[(isWhite ? 0 : 6) + 6 - fromPiece->value()][from];
					delete m_board->board()[from];
					m_board->board()[from] = nullptr;
					if (((move.m_move >> 12) & 0x3) == 0)
						fromPiece = new Knight(from, isWhite, false);
					else if (((move.m_move >> 12) & 0x3) == 1)
						fromPiece = new Bishop(from, isWhite, false);
					else if (((move.m_move >> 12) & 0x3) == 2)
						fromPiece = new Rook(from, isWhite, false);
					else if (((move.m_move >> 12) & 0x3) == 3)
						fromPiece = new Queen(from, isWhite, false);
					// Add
					Bitboards::add(fromPiece->value(), Color(fromPiece->isWhite()), from);
					m_s->materialKey ^= Zobrist::psq[(fromPiece->isWhite() ? 0 : 6) + 6 - fromPiece->value()][from];
				}
			}
			// Reset rule 50 counter
			m_s->rule50 = 0;
		}

		if (toPiece != nullptr)
		{
			// This should be the quickest to disable castle when rook is taken
			if (to == 0)
			{
				UInt constexpr value = 0b1000;
				if (m_s->castleInfo & value)
				{
					m_s->castleInfo &= ~value;
					m_s->materialKey ^= Zobrist::castling[1];
				}
			}
			else if (to == 7)
			{
				UInt constexpr value = 0b0100;
				if (m_s->castleInfo & value)
				{
					m_s->castleInfo &= ~value;
					m_s->materialKey ^= Zobrist::castling[0];
				}
			}
			else if (to == 56)
			{
				UInt constexpr value = 0b0010;
				if (m_s->castleInfo & value)
				{
					m_s->castleInfo &= ~value;
					m_s->materialKey ^= Zobrist::castling[3];
				}
			}
			else if (to == 63)
			{
				UInt constexpr value = 0b0001;
				if (m_s->castleInfo & value)
				{
					m_s->castleInfo &= ~value;
					m_s->materialKey ^= Zobrist::castling[2];
				}
			}

			s.lastCapturedPiece = toPiece;

			// Remove
			Bitboards::remove(toPiece->value(), Color(toPiece->isWhite()), to);
			m_s->materialKey ^= Zobrist::psq[(toPiece->isWhite() ? 0 : 6) + 6 - toPiece->value()][to];
			m_board->board()[to] = nullptr;
			// Editing color table for captures
			if (fromPiece->isWhite())
			{
				m_board->blackPos().erase(std::find(m_board->blackPos().begin(), m_board->blackPos().end(), to));
			}
			else
			{
				m_board->whitePos().erase(std::find(m_board->whitePos().begin(), m_board->whitePos().end(), to));
			}

			// Reset rule 50 counter
			m_s->rule50 = 0;
		}

		// Remove
		m_s->materialKey ^= Zobrist::psq[(fromPiece->isWhite() ? 0 : 6) + 6 - fromPiece->value()][from];
		m_board->board()[from] = nullptr;

		// Add
		m_s->materialKey ^= Zobrist::psq[(fromPiece->isWhite() ? 0 : 6) + 6 - fromPiece->value()][to];
		m_board->board()[to] = fromPiece;
		fromPiece->tile() = to;

		// Remove/Add
		Bitboards::removeAdd(fromPiece->value(), Color(fromPiece->isWhite()), from, to);

		// Editing color table
		// TODO : use std::replace_if ? or std::replace to avoid loop over all vector
		if (fromPiece->isWhite())
		{
			m_board->whitePos().erase(std::find(m_board->whitePos().begin(), m_board->whitePos().end(), from));
			m_board->whitePos().push_back(to);
		}
		else
		{
			m_board->blackPos().erase(std::find(m_board->blackPos().begin(), m_board->blackPos().end(), from));
			m_board->blackPos().push_back(to);
		}
		m_isWhiteTurn = !m_isWhiteTurn;
		m_s->materialKey ^= Zobrist::side;

		// If castling we move the rook as well
		if (flags == 2)
		{
			BoardParser::State tmp;
			movePiece(cMove(from + 3, from + 3 - 2), tmp);
			// We have moved, we need to set the turn back
			m_s = &s;
			m_board->m_castleInfo = &m_s->castleInfo;
			m_isWhiteTurn = !m_isWhiteTurn;
			m_s->materialKey ^= Zobrist::side;
		}
		else if (flags == 3)
		{
			BoardParser::State tmp;
			movePiece(cMove(from - 4, from - 4 + 3), tmp);
			// We have moved, we need to set the turn back
			m_s = &s;
			m_board->m_castleInfo = &m_s->castleInfo;
			m_isWhiteTurn = !m_isWhiteTurn;
			m_s->materialKey ^= Zobrist::side;
		}

		m_s->repetition = 0;
		if (m_s->rule50 >= 4)
		{
			BoardParser::State *s2 = m_s->previous->previous;
			for (UInt i = 4; i <= m_s->rule50; i += 2)
			{
				s2 = s2->previous->previous;
				if (s2->materialKey == m_s->materialKey)
				{
					m_s->repetition = s2->repetition ? -Int(i) : i;
					break;
				}
			}
		}
		return true;
	}

	/**
		* @brief
		*
		* @param move : moving flags as depicted in https://www.chessprogramming.org/Encoding_Moves#From-To_Based
		* @return true : move successful
		* @return false : move illegal
		*/
	bool unMovePiece(const cMove &move, bool silent = false)
	{
		UInt to = move.getTo();
		UInt from = move.getFrom();
		UInt flags = move.getFlags();
		Piece *toPiece = m_board->board()[to];

		// Add
		m_board->board()[from] = toPiece;
		toPiece->tile() = from;
		// Remove
		m_board->board()[to] = nullptr;

		// Remove/Add
		Bitboards::removeAdd(toPiece->value(), Color(toPiece->isWhite()), to, from);

		if (!silent)
		{
			boardParsed()->m_castleInfo = &m_s->previous->castleInfo;
			if (typeid(*toPiece) == typeid(King))
			{
				if (toPiece->isWhite())
					whiteKing(from);
				else
					blackKing(from);
			}

			// Was a promotion
			if (move.isPromotion())
			{
				// temporary have to delete and new but should be fixed for speedup
				// Before delete we store the data we need
				const bool isWhite = toPiece->isWhite();
				// Remove promoted piece back into pawn (already moved back)
				Bitboards::remove(toPiece->value(), Color(isWhite), from);
				delete m_board->board()[from];
				m_board->board()[from] = new Pawn(from, isWhite, false);
				toPiece = m_board->board()[from];
				Bitboards::add(toPiece->value(), Color(isWhite), from);
			}

			// Remove added enPassant and recover previous if there was one
			boardParsed()->enPassant(m_s->previous->enPassant);
		}
		// Editing color table
		// TODO : use std::replace_if ? or std::replace to avoid loop over all vector
		if (toPiece->isWhite())
		{
			m_board->whitePos().erase(std::find(m_board->whitePos().begin(), m_board->whitePos().end(), to));
			m_board->whitePos().push_back(from);
		}
		else
		{
			m_board->blackPos().erase(std::find(m_board->blackPos().begin(), m_board->blackPos().end(), to));
			m_board->blackPos().push_back(from);
		}

		if (!silent && m_s->lastCapturedPiece != nullptr)
		{
			UInt localTo = to;
			// Case where capture was en passant
			if (m_s->lastCapturedPiece->tile() != to)
				localTo = m_s->lastCapturedPiece->isWhite() ? to + 8 : to - 8;

			Bitboards::add(m_s->lastCapturedPiece->value(), Color(m_s->lastCapturedPiece->isWhite()), localTo);
			m_board->board()[localTo] = m_s->lastCapturedPiece;

			// Editing color table for captures
			if (m_s->lastCapturedPiece->isWhite())
			{
				m_board->whitePos().push_back(localTo);
			}
			else
			{
				m_board->blackPos().push_back(localTo);
			}
		}

		// If castling we move the rook as well
		if (flags == 2)
		{
			unMovePiece(cMove(from + 3, from + 3 - 2), /* silent = */ true);
		}
		else if (flags == 3)
		{
			unMovePiece(cMove(from - 4, from - 4 + 3), /* silent = */ true);
		}

		// State pointer back to the previous state
		if (!silent)
		{
			m_isWhiteTurn = !m_isWhiteTurn;
			m_s = m_s->previous;
			m_board->m_castleInfo = &m_s->castleInfo;
		}

		return true;
	}

	/**
		* @brief Fills the	board with the position fen and set state acordingly
		*
		* @param fen representation to fill the board
		* @param s pointer for representative BoardParser::State
		* @return true if board was successfully filled.
		* @return false else
		*/
	bool fillBoard(const std::string &fen, BoardParser::State *s)
	{
		std::stringstream sstream(fen);
		std::string word;
		std::vector<std::string> words{};
		while (std::getline(sstream, word, ' '))
		{
			words.push_back(word);
		}

		s->materialKey = 0;
		Bitboards::clear();
		m_board->whitePos().clear();
		m_board->blackPos().clear();
		m_board->whitePos().reserve(BOARD_SIZE * 2);
		m_board->blackPos().reserve(BOARD_SIZE * 2);
		for (UInt counter = BOARD_SIZE2 - BOARD_SIZE; const auto & c : words[0])
		{
			if (isdigit(c))
			{
				for (Int i = 0; i < atoi(&c); ++i)
				{
					if (m_board->board()[counter] != nullptr)
					{
						delete m_board->board()[counter];
						m_board->board()[counter] = nullptr;
					}
					++counter;
				}
				continue;
			}
			if (c == '/' && Board::column(counter) != 0)
			{
				err("Going further than board numbers.");
				return false;
			}

			if (c != '/' && m_board->board()[counter] != nullptr)
			{
				delete m_board->board()[counter];
				m_board->board()[counter] = nullptr;
			}

			switch (c)
			{
			case 'p':
				m_board->board()[counter] = new Pawn(counter, false, true);
				m_board->blackPos().push_back(counter);
				s->materialKey ^= Zobrist::psq[5 + 6][counter];
				Bitboards::bbPieces[PieceType::PAWN] |= Bitboards::tileToBB(counter);
				Bitboards::bbColors[Color::BLACK] |= Bitboards::tileToBB(counter);
				break;
			case 'P':
				m_board->board()[counter] = new Pawn(counter, true, true);
				m_board->whitePos().push_back(counter);
				s->materialKey ^= Zobrist::psq[5][counter];
				Bitboards::bbPieces[PieceType::PAWN] |= Bitboards::tileToBB(counter);
				Bitboards::bbColors[Color::WHITE] |= Bitboards::tileToBB(counter);
				break;
			case 'k':
				m_board->board()[counter] = new King(counter, false, true);
				m_board->blackPos().push_back(counter);
				s->materialKey ^= Zobrist::psq[0 + 6][counter];
				Bitboards::bbPieces[PieceType::KING] |= Bitboards::tileToBB(counter);
				Bitboards::bbColors[Color::BLACK] |= Bitboards::tileToBB(counter);
				blackKing(counter);
				break;
			case 'K':
				m_board->board()[counter] = new King(counter, true, true);
				m_board->whitePos().push_back(counter);
				s->materialKey ^= Zobrist::psq[0][counter];
				Bitboards::bbPieces[PieceType::KING] |= Bitboards::tileToBB(counter);
				Bitboards::bbColors[Color::WHITE] |= Bitboards::tileToBB(counter);
				whiteKing(counter);
				break;
			case 'q':
				m_board->board()[counter] = new Queen(counter, false, true);
				m_board->blackPos().push_back(counter);
				s->materialKey ^= Zobrist::psq[1 + 6][counter];
				Bitboards::bbPieces[PieceType::QUEEN] |= Bitboards::tileToBB(counter);
				Bitboards::bbColors[Color::BLACK] |= Bitboards::tileToBB(counter);
				break;
			case 'Q':
				m_board->board()[counter] = new Queen(counter, true, true);
				m_board->whitePos().push_back(counter);
				s->materialKey ^= Zobrist::psq[1][counter];
				Bitboards::bbPieces[PieceType::QUEEN] |= Bitboards::tileToBB(counter);
				Bitboards::bbColors[Color::WHITE] |= Bitboards::tileToBB(counter);
				break;
			case 'r':
				m_board->board()[counter] = new Rook(counter, false, true);
				m_board->blackPos().push_back(counter);
				s->materialKey ^= Zobrist::psq[2 + 6][counter];
				Bitboards::bbPieces[PieceType::ROOK] |= Bitboard(Bitboards::tileToBB(counter));
				Bitboards::bbColors[Color::BLACK] |= Bitboards::tileToBB(counter);
				break;
			case 'R':
				m_board->board()[counter] = new Rook(counter, true, true);
				m_board->whitePos().push_back(counter);
				s->materialKey ^= Zobrist::psq[2][counter];
				Bitboards::bbPieces[PieceType::ROOK] |= Bitboards::tileToBB(counter);
				Bitboards::bbColors[Color::WHITE] |= Bitboards::tileToBB(counter);
				break;
			case 'b':
				m_board->board()[counter] = new Bishop(counter, false, true);
				m_board->blackPos().push_back(counter);
				s->materialKey ^= Zobrist::psq[3 + 6][counter];
				Bitboards::bbPieces[PieceType::BISHOP] |= Bitboards::tileToBB(counter);
				Bitboards::bbColors[Color::BLACK] |= Bitboards::tileToBB(counter);
				break;
			case 'B':
				m_board->board()[counter] = new Bishop(counter, true, true);
				m_board->whitePos().push_back(counter);
				s->materialKey ^= Zobrist::psq[3][counter];
				Bitboards::bbPieces[PieceType::BISHOP] |= Bitboards::tileToBB(counter);
				Bitboards::bbColors[Color::WHITE] |= Bitboards::tileToBB(counter);
				break;
			case 'n':
				m_board->board()[counter] = new Knight(counter, false, true);
				m_board->blackPos().push_back(counter);
				s->materialKey ^= Zobrist::psq[4 + 6][counter];
				Bitboards::bbPieces[PieceType::KNIGHT] |= Bitboards::tileToBB(counter);
				Bitboards::bbColors[Color::BLACK] |= Bitboards::tileToBB(counter);
				break;
			case 'N':
				m_board->board()[counter] = new Knight(counter, true, true);
				m_board->whitePos().push_back(counter);
				s->materialKey ^= Zobrist::psq[4 + 6][counter];
				Bitboards::bbPieces[PieceType::KNIGHT] |= Bitboards::tileToBB(counter);
				Bitboards::bbColors[Color::WHITE] |= Bitboards::tileToBB(counter);
				break;
			case '/':
				counter -= BOARD_SIZE * 2 + 1;
				break;
			}
			++counter;
		}

		Bitboards::computeAll();

		if (words.size() > 1 && words[1] == "w")
		{
			m_isWhiteTurn = true;
			s->materialKey ^= Zobrist::side;
		}
		else
		{
			m_isWhiteTurn = false;
		}

		if (words.size() > 3)
		{
			s->castleInfo = 0;
			if (words[2] != "-")
			{
				if (std::find(words[2].begin(), words[2].end(), 'Q') != words[2].end())
				{
					s->castleInfo |= 0b1000;
					s->materialKey ^= Zobrist::castling[1];
				}
				if (std::find(words[2].begin(), words[2].end(), 'q') != words[2].end())
				{
					s->castleInfo |= 0b0010;
					s->materialKey ^= Zobrist::castling[3];
				}
				if (std::find(words[2].begin(), words[2].end(), 'K') != words[2].end())
				{
					s->castleInfo |= 0b0100;
					s->materialKey ^= Zobrist::castling[0];
				}
				if (std::find(words[2].begin(), words[2].end(), 'k') != words[2].end())
				{
					s->castleInfo |= 0b0001;
					s->materialKey ^= Zobrist::castling[2];
				}
			}
		}
		if (words.size() > 4 && words[3] != "-")
		{
			UInt tile = Board::toTiles(words[3]);
			s->enPassant = Board::column(tile);
			s->materialKey ^= Zobrist::enPassant[s->enPassant];
		}
		else
		{
			s->enPassant = -1;
		}
		m_board->enPassant(s->enPassant);

		if (words.size() > 5 && words[4] != "-")
		{
			s->rule50 = std::stoi(words[4]);
		}
		m_s = s;
		m_board->m_castleInfo = &m_s->castleInfo;

		return true;
	}

	// Board::toMove() converts a string representing a move in coordinate notation
	// (g1f3, a7a8q) to the corresponding legal Move, if any.
	cMove toMove(std::string &str) const
	{
		UInt flags = 0;
		UInt from = Board::toTiles(str.substr(0, 2));
		UInt to = Board::toTiles(str.substr(2, 2));
		// Capture flag
		if ((*boardParsed())[to] != nullptr)
			flags |= 0x4;
		if (str.length() == 5)
		{
			// The promotion piece character must be lowercased
			str[4] = char(tolower(str[4]));
			flags |= 0x8;
			switch (str[4])
			{
			case 'b':
				flags |= 0x1;
				break;
			case 'r':
				flags |= 0x2;
				break;
			case 'q':
				flags |= 0x3;
				break;
			}
		}

		const Piece *p = (*boardParsed())[from];
		// Detect castle and flag
		if (p != nullptr && p->value() == PieceType::KING)
		{
			if (to - from == 2)
			{
				flags = 0x2;
			}
			else if (from - to == 2)
			{
				flags = 0x3;
			}
		}

		return cMove(from, to, flags);
	}

	std::string fen(const bool noEnPassant = false, const bool noHalfMove = false) const
	{
		std::string s = "";
		UInt accumulate = 0;
		for (UInt i = 56; i != BOARD_SIZE; ++i)
		{
			if ((!s.empty() || i != 56) && i % 8 == 0)
			{
				i -= 16;
				if (accumulate != 0)
				{
					s += std::to_string(accumulate);
					accumulate = 0;
				}
				s += "/";
			}
			const Piece *p = m_board->board()[i];
			if (p == nullptr)
			{
				++accumulate;
			}
			else
			{
				if (accumulate != 0)
				{
					s += std::to_string(accumulate);
					accumulate = 0;
				}
				if (p->value() == PieceType::KING)
					s += p->isWhite() ? "K" : "k";
				else if (p->value() == PieceType::QUEEN)
					s += p->isWhite() ? "Q" : "q";
				else if (p->value() == PieceType::ROOK)
					s += p->isWhite() ? "R" : "r";
				else if (p->value() == PieceType::BISHOP)
					s += p->isWhite() ? "B" : "b";
				else if (p->value() == PieceType::KNIGHT)
					s += p->isWhite() ? "N" : "n";
				else if (p->value() == PieceType::PAWN)
					s += p->isWhite() ? "P" : "p";
			}
		}
		if (accumulate != 0)
		{
			s += std::to_string(accumulate);
			accumulate = 0;
		}

		s += isWhiteTurn() ? " w " : " b ";

		std::string caslteStr = "";
		if (m_s->castleInfo & 0b0100)
			caslteStr += "K";
		if (m_s->castleInfo & 0b1000)
			caslteStr += "Q";
		if (m_s->castleInfo & 0b0001)
			caslteStr += "k";
		if (m_s->castleInfo & 0b0010)
			caslteStr += "q";

		if (caslteStr.empty())
			caslteStr = "-";
		s += caslteStr;

		if (!noEnPassant)
		{
			s += " ";

			Int enPassant = m_board->enPassant(); // change, m_enPassant should be a pointer like m_castleInfo
			// Assert if enPassant is really feasable
			if (enPassant != -1)
			{
				// White takes black
				if (isWhiteTurn())
				{
					if (enPassant == 0 || enPassant == BOARD_SIZE - 1)
					{
						int offset = (enPassant == 0) ? 1 : (BOARD_SIZE - 2);
						const Piece *p = boardParsed()->board()[32 + offset];
						if (p == nullptr || !p->isWhite() || p->value() != PieceType::PAWN)
						{
							enPassant = -1;
						}
					}
					else
					{
						const Piece *p1 = boardParsed()->board()[32 + enPassant - 1];
						const Piece *p2 = boardParsed()->board()[32 + enPassant + 1];
						if ((p1 == nullptr || !p1->isWhite() || p1->value() != PieceType::PAWN) && (p2 == nullptr || !p2->isWhite() || p2->value() != PieceType::PAWN))
						{
							enPassant = -1;
						}
					}
				}
				// Black takes white
				else
				{
					if (enPassant == 0 || enPassant == BOARD_SIZE - 1)
					{
						int offset = (enPassant == 0) ? 1 : (BOARD_SIZE - 2);
						const Piece *p = boardParsed()->board()[24 + offset];
						if (p == nullptr || p->isWhite() || p->value() != PieceType::PAWN)
						{
							enPassant = -1;
						}
					}
					else
					{
						const Piece *p1 = boardParsed()->board()[24 + enPassant - 1];
						const Piece *p2 = boardParsed()->board()[24 + enPassant + 1];
						if ((p1 == nullptr || p1->isWhite() || p1->value() != PieceType::PAWN) && (p2 == nullptr || p2->isWhite() || p2->value() != PieceType::PAWN))
						{
							enPassant = -1;
						}
					}
				}
			}
			s += enPassant == -1 ? "-" : Board::toString((isWhiteTurn() ? 40 : 16) + enPassant);

			if (!noHalfMove)
			{
				s += " ";

				s += std::to_string(m_s->rule50);
			}
		}

		return s;
	}

	bool inCheck(bool isWhite) const
	{
		UInt kingPos = isWhite ? whiteKing() : blackKing();
		// Compute all oponents moves
		std::vector<cMove> v;
		for (const auto tile : (!isWhite ? m_board->whitePos() : m_board->blackPos()))
		{
			const Piece *piece = m_board->board()[tile];
			if (piece == nullptr)
			{
				continue;
			}
			piece->canMove(*m_board, v);
		}
		return std::find_if(v.begin(), v.end(), [kingPos](const auto &ele) {return ele.getTo() == kingPos;}) != v.end();
	}

	bool inCheck(bool isWhite, std::array<cMove, MAX_PLY> vTotal, size_t arraySize) const
	{
		UInt kingPos = isWhite ? whiteKing() : blackKing();
		return std::find_if(vTotal.begin(), vTotal.begin() + arraySize, [kingPos](const auto &ele) {return ele.getTo() == kingPos;}) != vTotal.begin() + arraySize;
	}

	bool inCheck(bool isWhite, std::vector<cMove> vTotal) const
	{
		UInt kingPos = isWhite ? whiteKing() : blackKing();
		return std::find_if(vTotal.begin(), vTotal.end(), [kingPos](const auto &ele) {return ele.getTo() == kingPos;}) != vTotal.end();
	}

	bool isDraw() const
	{
		if (m_s->rule50 > 99)
			return true;
		if (m_s->rule50 < 10)
			return false;
		BoardParser::State *s = m_s->previous->previous;
		for (UInt d = 4; d <= m_s->rule50; d += 2)
		{
			s = s->previous->previous;

			Key diff = m_s->materialKey ^ s->materialKey;
			if (diff == 0)
				return true;
		}
		return false;
	}

	void displayCout() const
	{
		std::cout << "displayCout" << std::endl;
		for (UInt counter = BOARD_SIZE2 - BOARD_SIZE; counter != BOARD_SIZE - 1; ++counter)
		{
			const Piece *value = m_board->board()[counter];
			if (Board::column(counter + 1) == 0)
			{
				counter -= BOARD_SIZE * 2;
			}
			if (value == nullptr)
			{
				std::cout << " ";
				continue;
			}
			std::cout << value->str();
		}
	}

	void displayCLI() const
	{
		std::string out;
		for (UInt counter = BOARD_SIZE2 - BOARD_SIZE; counter != BOARD_SIZE - 1; ++counter)
		{
			const Piece *value = m_board->board()[counter];
			out.append("|");
			if (value == nullptr)
			{
				out.append(" ");
			}
			else
			{
				out.append(value->str());
			}
			if (Board::column(counter + 1) == 0)
			{
				out.append("|\n");
				counter -= BOARD_SIZE * 2;
			}
		}
		out.append("|");
		const Piece *value = m_board->board()[BOARD_SIZE - 1];
		if (value == nullptr)
		{
			out.append(" ");
		}
		else
		{
			out.append(value->str());
		}

		std::cout << out << std::string("|") << std::endl << std::endl;
	}

	void displayBBCLI(const Bitboard bb) const
	{
		std::string out;
		for (UInt counter = BOARD_SIZE2 - BOARD_SIZE; counter != BOARD_SIZE - 1; ++counter)
		{
			Bitboard value = bb & (0x1ULL << counter);
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
		Bitboard value = bb & (0x1ULL << (BOARD_SIZE - 1));
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

	void displayBBCLI() const
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

	/**
		* @brief Display board in CLI by parsing the optimized vectors.
		*
		*/
	void displayCLIWhiteBlack() const
	{
		std::string out;
		for (UInt counter = BOARD_SIZE2 - BOARD_SIZE; counter != BOARD_SIZE - 1; ++counter)
		{
			out.append("|");
			std::string s;
			auto whiteFind = std::find(m_board->whitePos().begin(), m_board->whitePos().end(), counter);
			auto blackFind = std::find(m_board->blackPos().begin(), m_board->blackPos().end(), counter);
			if (whiteFind != m_board->whitePos().end())
			{
				out.append("O");
			}
			else if (blackFind != m_board->blackPos().end())
			{
				out.append("X");
			}
			else
			{
				out.append(" ");
			}
			if (Board::column(counter + 1) == 0)
			{
				out.append("|\n");
				counter -= BOARD_SIZE * 2;
			}
		}
		out.append("|");
		std::string s;
		auto whiteFind = std::find(m_board->whitePos().begin(), m_board->whitePos().end(), BOARD_SIZE - 1);
		auto blackFind = std::find(m_board->blackPos().begin(), m_board->blackPos().end(), BOARD_SIZE - 1);
		if (whiteFind != m_board->whitePos().end())
		{
			out.append("O");
		}
		else if (blackFind != m_board->blackPos().end())
		{
			out.append("X");
		}
		else
		{
			out.append(" ");
		}
		std::cout << out << std::string("|") << std::endl << std::endl;
	}

	/**
		* @brief Display board in CLI and shows how can a piece move.
		*
		*/
	void displayCLIMove(UInt tile) const
	{
		std::string out;
		const Piece *piece = m_board->board()[tile];
		std::vector<cMove> v;
		if (piece != nullptr)
		{
			piece->canMove(*m_board, v);
		}

		for (UInt counter = BOARD_SIZE2 - BOARD_SIZE; counter != BOARD_SIZE - 1; ++counter)
		{
			const Piece *value = m_board->board()[counter];
			out.append("|");
			if (std::find_if(v.begin(), v.end(), [counter](const auto &ele) {return ele.getTo() == counter;}) != v.end())
			{
				out.append("X");
			}
			else if (value == nullptr)
			{
				out.append(" ");
			}
			else
			{
				out.append(value->str());
			}
			if (Board::column(counter + 1) == 0)
			{
				out.append("|\n");
				counter -= BOARD_SIZE * 2;
			}
		}
		out.append("|");
		if (std::find_if(v.begin(), v.end(), [](const auto &ele) {return ele.getTo() == BOARD_SIZE - 1;}) != v.end())
		{
			out.append("X");
		}
		else
		{
			const Piece *value = m_board->board()[BOARD_SIZE - 1];
			if (value == nullptr)
			{
				out.append(" ");
			}
			else
			{
				out.append(value->str());
			}
		}

		std::cout << out << std::string("|") << std::endl << std::endl;
	}
};
