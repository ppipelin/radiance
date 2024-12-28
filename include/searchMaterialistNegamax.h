#pragma once

#include <algorithm>
#include <vector>

#include "include.h"
#include "search.h"

class SearchMaterialistNegamax : virtual public Search
{
public:
	SearchMaterialistNegamax(const Search::LimitsType &limits, bool *g_stop) : Search(limits, g_stop) {}
	SearchMaterialistNegamax(const SearchMaterialistNegamax &s) = delete;
	~SearchMaterialistNegamax() = default;

	template <NodeType nodeType>
	Value quiesce(Stack *ss, BoardParser &b, const Evaluate &e, Value alpha, Value beta)
	{
		++nodesSearched[pvIdx];

		constexpr bool pvNode = nodeType == PV;

		// In order to get the quiescence search to terminate, plies are usually restricted to moves that deal directly with the threat,
		// such as moves that capture and recapture (often called a 'capture search') in chess
		Value stand_pat = e.evaluate(b);
		if (stand_pat >= beta)
			return beta;
		if (alpha < stand_pat)
			alpha = stand_pat;
		if (outOfTime())
			return alpha;

		cMove pv[MAX_DEPTH + 1];
		BoardParser::State s;
		Value score = VALUE_NONE;

		// 1. Initialize node
		if (pvNode)
		{
			(ss + 1)->pv = pv;
			ss->pv[0] = cMove();
		}

		std::vector<cMove> moveListCaptures;
		Search::generateMoveList(b, moveListCaptures, /*legalOnly=*/ true, /*onlyCapture=*/ true, /*onlyCheck=*/ true);

		Search::orderMoves(b, moveListCaptures);

		for (const cMove &move : moveListCaptures)
		{
			ss->currentMove = move;
			b.movePiece(move, s);
			if (b.m_s->repetition < 0)
				score = VALUE_DRAW;
			else
				score = -quiesce<nodeType>(ss + 1, b, e, -beta, -alpha);
			b.unMovePiece(move);

			if (score >= beta)
			{
				// beta cutoff
				return beta;
			}
			if (score > alpha)
			{
				// alpha acts like max in MiniMax
				if (pvNode)  // Update pv even in fail-high case
					update_pv(ss->pv, move, (ss + 1)->pv);
				alpha = score;
			}

			if (outOfTime())
				break;
		}

		// Quiet position
		if (moveListCaptures.empty())
		{
			return alpha;
		}
		return alpha;
	}

	template <NodeType nodeType>
	Value abSearch(Stack *ss, BoardParser &b, const Evaluate &e, Value alpha, Value beta, UInt depth)
	{
		constexpr bool pvNode = nodeType != NonPV;
		constexpr bool rootNode = nodeType == Root;

		if (depth <= 0)
		{
			// return e.evaluate(b);
			return quiesce<pvNode ? PV : NonPV>(ss, b, e, alpha, beta);
		}

		// 0. Initialize data
		BoardParser::State s;
		cMove pv[MAX_DEPTH + 1];
		Value score = -VALUE_NONE, bestScore = -VALUE_NONE;
		++nodesSearched[pvIdx];

		// 1. Initialize node
		ss->moveCount = 0;
		score = bestScore;
		UInt moveCount = 0;

		// 13. Loop through all pseudo - legal moves until no moves remain or a beta cutoff occurs.
		std::vector<cMove> moveList;
		if (rootNode)
		{
			for (UInt i = 0; i < rootMoves.size(); ++i)
				moveList.push_back(rootMoves[i].pv[0]);
		}
		else
		{
			Search::generateMoveList(b, moveList, /*legalOnly=*/ true, /*onlyCapture=*/ false);
			Search::orderMoves(b, moveList, (rootMoves[0].pv.size() > ss->ply) ? rootMoves[0].pv[ss->ply] : cMove());
		}

		for (const cMove &move : moveList)
		{
			score = -VALUE_NONE;
			ss->moveCount = ++moveCount;
			if (pvNode)
				(ss + 1)->pv = nullptr;

			ss->currentMove = move;

			Key key = b.m_s->materialKey;
			// 16. Make the move
			b.movePiece(move, s);

			(ss + 1)->pv = pv;
			(ss + 1)->pv[0] = cMove();

#define transposition
#define lmr
			if (b.m_s->repetition < 0)
				score = VALUE_DRAW;
			else
			{
#ifdef transposition
				auto it = transpositionTable.find(key);
				const bool found = it != transpositionTable.end();
				if (found && std::get<1>(it->second) > depth - 1)
				{
					score = std::get<0>(it->second);
					if (score > VALUE_MATE_IN_MAX_DEPTH)
						score -= ss->ply;
					else if (score < VALUE_MATED_IN_MAX_DEPTH)
						score += ss->ply;

					// Retrieved score doesn't meet the alpha beta requirements
					if (score < alpha || score >= beta)
						score = -VALUE_NONE;
					else
						++transpositionUsed;
				}
#endif
				if (score == -VALUE_NONE)
				{
#ifdef lmr
					// LMR before full
					if (depth >= 2 && moveCount > 3 && !move.isCapture() && !move.isPromotion() && !b.inCheck(b.isWhiteTurn()))
					{
						// Reduced LMR
						UInt d = std::max<Int>(Int(1), Int(depth) - 4);
						score = -abSearch<NonPV>(ss + 1, b, e, -(alpha + 1), -alpha, d - 1);
						// Failed so roll back to full-depth null window
						if (score > alpha && depth > d)
						{
							score = -abSearch<NonPV>(ss + 1, b, e, -(alpha + 1), -alpha, depth - 1);
						}
					}
					// In case non PV search are called without LMR, null window search at current depth
#pragma warning( disable: 4127 )
					else if (!pvNode || moveCount > 1)
					{
						score = -abSearch<NonPV>(ss + 1, b, e, -(alpha + 1), -alpha, depth - 1);
					}
					// 18. Full - depth search
					if (pvNode && (moveCount == 1 || score > alpha))
#endif
						score = -abSearch<PV>(ss + 1, b, e, -beta, -alpha, depth - 1);
#pragma warning( default: 4127 )
#ifdef transposition
					// Let's assert we don't store draw (repetition)
					if (score != VALUE_DRAW)
					{
						if (!found)
							transpositionTable[key] = std::tuple<Value, UInt, cMove>(score, depth - 1, move);
						else if (std::get<1>(it->second) <= depth - 1)
							it->second = std::tuple<Value, UInt, cMove>(score, depth - 1, move);
					}
#endif
				}
			}

			// 19. Undo move
			b.unMovePiece(move);

			if (depth > 1 && outOfTime())
				return -VALUE_NONE;

			// 20. Check for a new best move
			if (rootNode)
			{
				RootMove &rm = *std::find(rootMoves.begin(), rootMoves.end(), move);
				rm.averageScore = rm.averageScore != -VALUE_INFINITE ? (score + rm.averageScore) / 2 : score;

				if (moveCount == 1 || score > alpha)
				{
					rm.score = rm.uciScore = score;
					if (score >= beta)
					{
						rm.scoreLowerbound = true;
						rm.uciScore = beta;
					}
					else if (score <= alpha)
					{
						rm.scoreUpperbound = true;
						rm.uciScore = alpha;
					}

					rm.pv.resize(1);
					for (cMove *m = (ss + 1)->pv; *m != cMove(); ++m)
						rm.pv.push_back(*m);
				}
				else
					rm.score = -VALUE_INFINITE;
			}

			// 21. Update ss->pv
			if (score > bestScore)
			{
				bestScore = score;
				if (score > alpha)
				{
#pragma warning( disable: 4127 )
					if (pvNode && !rootNode)  // Update pv even in fail-high case
						update_pv(ss->pv, move, (ss + 1)->pv);
#pragma warning( default: 4127 )

					// Fail high
					if (score >= beta)
					{
#ifdef transposition
						auto it = transpositionTable.find(key);
						const bool found = it != transpositionTable.end();
						if (!found)
							transpositionTable[key] = std::tuple<Value, UInt, cMove>(score, depth - 1, move);
						else if (std::get<1>(it->second) <= depth - 1)
							it->second = std::tuple<Value, UInt, cMove>(score, depth - 1, move);
#endif
						break;
					}
					else
						alpha = score;  // Update alpha! Always alpha < beta
				}
			}
		}

		if (moveList.empty())
		{
			if (b.inCheck(b.isWhiteTurn()))
				return -VALUE_MATE + ss->ply;
			return VALUE_DRAW;
		}

		return bestScore;
	}

	cMove nextMove(BoardParser &b, const Evaluate &e) override
	{
		const std::lock_guard<std::mutex> lock(*mtx);
		nodesSearched.fill(0);
		// Checking book
		cMove book = probeBook(b);
		if (book != cMove())
			return book;

		if (Limits.movetime)
		{
			remaining = Limits.movetime * TimePoint(30);
		}
		else
		{
			remaining = TimePoint(b.isWhiteTurn() ? Limits.time[WHITE] : Limits.time[BLACK]);
			increment = TimePoint(b.isWhiteTurn() ? Limits.inc[WHITE] : Limits.inc[BLACK]);
		}


		Stack stack[MAX_DEPTH + 10] = {};
		cMove pv[MAX_DEPTH + 1];
		Stack *ss = stack + 7;
		transpositionTable.clear(); // not necessary but provide more consistant pv()

		for (UInt i = 0; i <= MAX_DEPTH + 2; ++i)
			(ss + i)->ply = i;
		ss->pv = pv;

		// Compute rootMoves (start_thingking in SF)
		rootMoves.clear();
		std::vector<cMove> moveList;
		Search::generateMoveList(b, moveList, /*legalOnly=*/ true, /*onlyCapture=*/ false);

		Search::orderMoves(b, moveList);
		if (moveList.empty())
		{
			err("Cannot move.");
			return cMove();
		}
		else if (moveList.size() == 1)
		{
			return moveList[0];
		}

		// limits.searchmoves here

		if (rootMoves.empty())
			for (const auto &move : moveList)
				rootMoves.emplace_back(move);

		// Iterative deepening algorithm
		for (UInt currentDepth = 1; currentDepth < MAX_PLY && !(Limits.depth && currentDepth > Limits.depth); ++currentDepth)
		{
			// Some variables have to be reset
			for (UInt i = 0; i < rootMoves.size(); ++i)
			{
				rootMoves[i].previousScore = std::move(rootMoves[i].score);
				rootMoves[i].score = -VALUE_INFINITE;
			}

			// Reset aspiration window starting size
			Value prev = rootMoves[0].averageScore;
			Value delta = std::abs(prev / 2) + 10;
			Value alpha = std::max<Value>(prev - delta, -VALUE_INFINITE);
			Value beta = std::min<Value>(prev + delta, VALUE_INFINITE);
			Value failedHighCnt = 0;
			// Aspiration window
			// Disable by alpha = -VALUE_INFINITE; beta = VALUE_INFINITE;
			// alpha = -VALUE_INFINITE; beta = VALUE_INFINITE;

			while (true)
			{
				Value score = abSearch<Root>(ss, b, e, alpha, beta, currentDepth);

				if (currentDepth > 1 && outOfTime())
					break;

				// In case of failing low/high increase aspiration window and
				// re-search, otherwise exit the loop.
				if (score <= alpha)
				{
					beta = (alpha + beta) / 2;
					alpha = std::max<Value>(score - delta, -VALUE_INFINITE);
					failedHighCnt = 0;
				}
				else if (score >= beta)
				{
					beta = std::min<Value>(score + delta, VALUE_INFINITE);
					++failedHighCnt;
				}
				else
					break;

				std::stable_sort(rootMoves.begin(), rootMoves.end());

				delta += delta / 3;
			}

			// Even if outofTime we keep a better move if there is one
			std::stable_sort(rootMoves.begin(), rootMoves.end());

			if (currentDepth > 1 && outOfTime())
			{
				// std::cout << "info partial" << std::endl;
				// std::cout << UCI::pv(*this, currentDepth) << std::endl;
				break;
			}

			std::cout << "info failedHighCnt " << failedHighCnt << " alpha " << alpha << " beta " << beta << std::endl;
			std::cout << UCI::pv(*this, currentDepth) << std::endl;
		}
		return rootMoves[0].pv[0];
	}
};
