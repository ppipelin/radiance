#pragma once

#include <array>
#include <fstream>
#include <memory>
#include <mutex>
#include <numeric>
#include <unordered_map>

#include "boardParser.h"
#include "cMove.h"
#include "evaluate.h"
#include "include.h"

using TimePoint = std::chrono::milliseconds::rep; // A value in milliseconds
static_assert(sizeof(TimePoint) == sizeof(int64_t), "TimePoint should be 64 bits");
inline TimePoint now()
{
	return std::chrono::duration_cast<std::chrono::milliseconds>
		(std::chrono::steady_clock::now().time_since_epoch()).count();
}

namespace {
	std::unordered_map<Key, std::tuple<Value, UInt, cMove>> transpositionTable;
	TimePoint remaining = 0;
	TimePoint increment = 0;
}

class Search
{
public:
	struct LimitsType
	{
		LimitsType()
		{
			// Init explicitly due to broken value-initialization of non POD in MSVC
			movestogo = depth = mate = perft = infinite = nodes = 0;
			time[WHITE] = time[BLACK] = inc[WHITE] = inc[BLACK] = startTime = TimePoint(0);
		}

		std::vector<cMove> searchmoves;
		UInt movestogo, depth, mate, perft, infinite, nodes;
		TimePoint time[COLOR_NB], inc[COLOR_NB], startTime, movetime = 0;
	};

	// RootMove struct is used for moves at the root of the tree. For each root move
	// we store a score and a PV (really a refutation in the case of moves which
	// fail low). Score is normally set at -VALUE_INFINITE for all non-pv moves.
	struct RootMove
	{
		explicit RootMove() : pv{} {}
		explicit RootMove(const cMove m) : pv{ m } {}
		bool operator==(const cMove &m) const { return pv[0] == m; }
		bool operator<(const RootMove &m) const
		{
			// Sort in descending order
			return m.score != score ? m.score < score
				: m.previousScore < previousScore;
		}

		Value score = -VALUE_INFINITE;
		Value previousScore = -VALUE_INFINITE;
		Value averageScore = -VALUE_INFINITE;
		Value uciScore = -VALUE_INFINITE;
		bool scoreLowerbound = false;
		bool scoreUpperbound = false;
		std::vector<cMove> pv;
		UInt pvDepth = 0;
	};

	struct Stack
	{
		cMove *pv;
		UInt ply;
		cMove currentMove;
		cMove excludedMove;
		cMove killers[2];
		Value staticEval;
		UInt moveCount;
		bool inCheck;
		bool ttPv;
		bool ttHit;
		int doubleExtensions;
		int cutoffCnt;
	};

	void update_pv(cMove *pv, cMove move, const cMove *childPv)
	{
		for (*pv++ = move; childPv && *childPv != cMove();)
			*pv++ = *childPv++;
		*pv = cMove();
	}

	LimitsType Limits;
	UInt pvIdx = 0;
	std::vector<RootMove> rootMoves;
	std::array<Int, MAX_PLY> nodesSearched = { 0 };
	UInt transpositionUsed = 0;

	Search(const Search::LimitsType &limits, bool *g_stop) : Limits(limits), g_stop(g_stop), mtx(std::make_unique<std::mutex>()) {}
	Search(const Search &) = delete;
	virtual ~Search() = default;

	virtual cMove nextMove(const BoardParser &, const Evaluate &)
	{
		return cMove();
	}

	virtual cMove nextMove(BoardParser &, const Evaluate &)
	{
		return cMove();
	}

	cMove probeBook(const BoardParser &b)
	{
		std::string fen = b.fen(/*noEnPassant =*/ false, /*noHalfMove =*/ true);
		std::vector<std::string> movesParsed;
		std::vector<UInt> frequenciesParsed;

		std::ifstream infile("book.txt");
		std::string line, varName, defaultValue;
		std::string delimiter = " ";

		while (std::getline(infile, line) && movesParsed.empty())
		{
			varName = line.substr(0, line.find(delimiter));
			defaultValue = line.substr(line.find(delimiter) + 1);
			if (varName == "pos" && fen == defaultValue)
			{
				while (std::getline(infile, line))
				{
					varName = line.substr(0, line.find(delimiter));
					defaultValue = line.substr(line.find(delimiter) + 1);
					if (line.substr(0, line.find(delimiter)) == "pos")
						break;
					movesParsed.push_back(varName);
					frequenciesParsed.push_back(UInt(std::stoi(defaultValue)));
				}
			}
		}

		if (!movesParsed.empty())
		{
			UInt accMax = std::accumulate(frequenciesParsed.begin(), frequenciesParsed.end(), 0);
			UInt selector = UInt(double(std::rand()) / double(RAND_MAX) * double(accMax));
			UInt acc = 0;
			for (UInt i = 0; i < frequenciesParsed.size(); ++i)
			{
				acc += frequenciesParsed[i];
				if (selector < acc)
				{
					return b.toMove(movesParsed[i]);
				}
			}
		}
		return cMove();
	}

	static void legalMoves(BoardParser &b, std::vector<cMove> &moveList)
	{
		// #define optLegalOnly
#ifdef optLegalOnly
		// Look for attacked squares
		std::array<cMove, MAX_PLY> moveListAttack = {};
		size_t moveListAttackSize = 0;
		for (UInt tileIdx = 0; tileIdx < enemyPositions.size(); ++tileIdx)
		{
			UInt tile = enemyPositions[tileIdx];
			const Piece *piece = b.boardParsed()->board()[tile];
			std::vector<cMove> subMoveList;
			piece->canMove(*b.boardParsed(), subMoveList);
			std::copy(subMoveList.begin(), subMoveList.end(), moveListAttack.begin() + moveListAttackSize);
			moveListAttackSize += subMoveList.size();
		}

		BoardParser::State s;
		std::erase_if(moveList, [&b, &s, moveListAttack, moveListAttackSize](const cMove &move) {
			b.movePiece(move, s);
			// Prune moves which keep the king in check
			const bool keepInCheck = b.inCheck(!b.isWhiteTurn());
			b.unMovePiece(move);
			if (keepInCheck) return true;

			// Prune moves which castles in check
			if (move.isCastle())
				return b.inCheck(b.isWhiteTurn(), moveListAttack, moveListAttackSize);

			// Prune moves which castles through check
			if (move.getFlags() == 0x2)
			{
				return (std::find(moveListAttack.begin(), moveListAttack.begin() + moveListAttackSize, move.getFrom() + 1) != moveListAttack.begin() + moveListAttackSize) ||
					(std::find(moveListAttack.begin(), moveListAttack.begin() + moveListAttackSize, move.getFrom() + 2) != moveListAttack.begin() + moveListAttackSize);
			}
			else if (move.getFlags() == 0x3)
			{
				return (std::find(moveListAttack.begin(), moveListAttack.begin() + moveListAttackSize, move.getFrom() - 1) != moveListAttack.begin() + moveListAttackSize) ||
					(std::find(moveListAttack.begin(), moveListAttack.begin() + moveListAttackSize, move.getFrom() - 2) != moveListAttack.begin() + moveListAttackSize) ||
					(std::find(moveListAttack.begin(), moveListAttack.begin() + moveListAttackSize, move.getFrom() - 3) != moveListAttack.begin() + moveListAttackSize);
			}
			return false;
			});
#endif
#ifndef optLegalOnly
		BoardParser::State s;

		std::erase_if(moveList, [&b, &s](const cMove &move) {
#ifdef unMoveTest
			BoardParser::State s2 = *b.m_s;
			BoardParser b2(b, &s2);
#endif
			b.movePiece(move, s);
			// Prune moves which keep the king in check
			bool exit = b.inCheck(!b.isWhiteTurn());
			b.unMovePiece(move);
			s = *b.m_s;
#ifdef unMoveTest
			if (b != b2)
			{
				b.displayCLI();
				std::cout << b.m_s->materialKey << " " << b2.m_s->materialKey << std::endl;
			}
			else
				assert(b.m_s->materialKey == b2.m_s->materialKey);
#endif
			if (exit) return true;

			// Prune moves which castles in check
			if (move.isCastle() && b.inCheck(b.isWhiteTurn()))
				return true;

			// Prune moves which castles through check
			if (move.getFlags() == 0x2)
			{
				cMove lastMove = cMove(move.getFrom(), move.getFrom() + 1);
				b.movePiece(lastMove, s);
				exit = b.inCheck(!b.isWhiteTurn());
				b.unMovePiece(lastMove);
				s = *b.m_s;
#ifdef unMoveTest
				if (b != b2)
				{
					b.displayCLI();
					std::cout << b.m_s->materialKey << " " << b2.m_s->materialKey << std::endl;
				}
#endif
				if (exit)
					return true;

				lastMove = cMove(move.getFrom(), move.getFrom() + 2);
				b.movePiece(lastMove, s);
				exit = b.inCheck(!b.isWhiteTurn());
				b.unMovePiece(lastMove);
				s = *b.m_s;
#ifdef unMoveTest
				if (b != b2)
				{
					b.displayCLI();
					std::cout << b.m_s->materialKey << " " << b2.m_s->materialKey << std::endl;
				}
#endif
				if (exit)
					return true;
			}
			else if (move.getFlags() == 0x3)
			{
				cMove lastMove = cMove(move.getFrom(), move.getFrom() - 1);
				b.movePiece(lastMove, s);
				exit = b.inCheck(!b.isWhiteTurn());
				b.unMovePiece(lastMove);
				s = *b.m_s;
#ifdef unMoveTest
				if (b != b2)
				{
					b.displayCLI();
					std::cout << b.m_s->materialKey << " " << b2.m_s->materialKey << std::endl;
				}
#endif
				if (exit)
					return true;

				lastMove = cMove(move.getFrom(), move.getFrom() - 2);
				b.movePiece(lastMove, s);
				exit = b.inCheck(!b.isWhiteTurn());
				b.unMovePiece(lastMove);
				s = *b.m_s;
#ifdef unMoveTest
				if (b != b2)
				{
					b.displayCLI();
					std::cout << b.m_s->materialKey << " " << b2.m_s->materialKey << std::endl;
				}
#endif
				if (exit)
					return true;
			}
			return false;
			});
#endif
	}
	static void generateMoveList(BoardParser &b, std::vector<cMove> &moveList, bool legalOnly = false, bool onlyCapture = false, bool onlyCheck = false)
	{
		std::vector<UInt> allyPositions = b.isWhiteTurn() ? b.boardParsed()->whitePos() : b.boardParsed()->blackPos();
		std::vector<UInt> enemyPositions = !b.isWhiteTurn() ? b.boardParsed()->whitePos() : b.boardParsed()->blackPos();
		std::sort(allyPositions.begin(), allyPositions.end());
		std::sort(enemyPositions.begin(), enemyPositions.end());
		moveList.reserve(MAX_PLY);
		for (UInt tileIdx = 0; tileIdx < allyPositions.size(); ++tileIdx)
		{
			UInt tile = allyPositions[tileIdx];
			const Piece *piece = b.boardParsed()->board()[tile];
			piece->canMove(*b.boardParsed(), moveList);
		}

		if (onlyCapture && !onlyCheck)
		{
			std::erase_if(moveList, [](const cMove &move) {return !move.isCapture();});
		}

		if (onlyCapture && onlyCheck)
		{
			const UInt oppKingPos = b.isWhiteTurn() ? b.whiteKing() : b.blackKing();
			std::erase_if(moveList, [&b, oppKingPos](const cMove &move) mutable {
				std::vector<cMove> moveListTmp;
				BoardParser::State s(b);
				b.movePiece(move, s);
				const Piece *piece = b.boardParsed()->board()[move.getTo()];
				piece->canMove(*b.boardParsed(), moveListTmp);
				b.unMovePiece(move);
				return !move.isCapture() || (std::find(moveListTmp.begin(), moveListTmp.end(), oppKingPos) != moveListTmp.end());
				});
		}

		if (legalOnly)
		{
			legalMoves(b, moveList);
		}
	}

	struct MoveComparator
	{
		MoveComparator(const BoardParser &b, const cMove &move1, const cMove &move2) : b(b), move1(move1), move2(move2) {};

		bool operator() (const cMove &m1, const cMove &m2) const
		{
			if (move1 != cMove())
			{
				if (move1 == m1)
					return true;
				else if (move1 == m2)
					return false;
			}
			if (move2 != cMove())
			{
				if (move2 == m1)
					return true;
				else if (move2 == m2)
					return false;
			}
			return (m1.isCapture() && m1.getFlags() != 0x5 ? Int((*b.boardParsed())[m1.getTo()]->value()) - Int((*b.boardParsed())[m1.getFrom()]->value()) : 0) >
				(m2.isCapture() && m2.getFlags() != 0x5 ? Int((*b.boardParsed())[m2.getTo()]->value()) - Int((*b.boardParsed())[m2.getFrom()]->value()) : 0);
		}

		const BoardParser &b;
		const cMove &move1;
		const cMove &move2;
	};

	static void orderMoves(const BoardParser &b, std::vector<cMove> &moveList, cMove pvMove = cMove())
	{
		// Search pvMove is in movelist. Speed up comparision if not.
		if (pvMove != cMove() && std::find(moveList.begin(), moveList.end(), pvMove) == moveList.end())
			pvMove = cMove();

		auto it = transpositionTable.find(b.m_s->materialKey);
		const bool found = it != transpositionTable.end();
		cMove ttMove = found ? std::get<2>(it->second) : cMove();
		// Search ttMove is in movelist. Speed up comparision if not.
		if (ttMove != cMove() && std::find(moveList.begin(), moveList.end(), ttMove) == moveList.end())
			ttMove = cMove();

		std::sort(moveList.begin(), moveList.end(), MoveComparator(b, pvMove, ttMove));
	}

	/**
	* @brief perft test from https://www.chessprogramming.org/Perft
	*
	* @param b
	* @param depth
	* @return UInt number of possibles position after all possible moves on b
	*/
	static UIntL perft(BoardParser &b, UInt depth = 1, bool verbose = false)
	{
		std::vector<cMove> moveList;
		UIntL nodes = 0;

		if (depth == 0)
		{
			return 1;
		}

		Search::generateMoveList(b, moveList, /*legalOnly =*/ true);
		for (const cMove &move : moveList)
		{
			BoardParser::State s;

			if (!b.movePiece(move, s))
			{
				b.unMovePiece(move);
				continue;
			}
			UIntL nodesNumber = perft(b, depth - 1);
			b.unMovePiece(move);
			if (verbose)
			{
				std::string promoteChar = "";
				const std::array<std::string, 4> promoteCharArray = { "n","b","r","q" };
				if (move.isPromotion())
					promoteChar = promoteCharArray[move.getFlags() & 0b11];
				std::cout << Board::toString(move.getFrom()) << Board::toString(move.getTo()) << promoteChar << " : " << nodesNumber << std::endl;
			}
			nodes += nodesNumber;
		}
		return nodes;
	}

	template<typename T, typename Predicate>
	void move_to_front(std::vector<T> &vec, Predicate pred)
	{
		auto it = std::find_if(vec.begin(), vec.end(), pred);

		if (it != vec.end())
		{
			std::rotate(vec.begin(), it, it + 1);
		}
	}

	inline TimePoint elapsed() const
	{
		return (now() - Limits.startTime);
	}

	inline bool outOfTime() const
	{
		if (*g_stop)
			return true;
		if (Limits.infinite || remaining == 0) return false;
		return elapsed() > std::min<TimePoint>(TimePoint(double(remaining) * 0.95), remaining / TimePoint(30) + increment);
	}

protected:
	enum NodeType
	{
		NonPV,
		PV,
		Root
	};
	bool *g_stop;
	std::unique_ptr<std::mutex> mtx;
};
