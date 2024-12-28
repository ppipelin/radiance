#pragma once

#include <algorithm>

#include "search.h"

class SearchMaterialist : virtual public Search
{
public:
	SearchMaterialist(const Search::LimitsType &limits, bool *g_stop) : Search(limits, g_stop) {}
	SearchMaterialist(const SearchMaterialist &s) = default;
	~SearchMaterialist() = default;

	template <NodeType nodeType>
	Value search(Stack *ss, BoardParser &b, const Evaluate &e, UInt depth)
	{
		constexpr bool rootNode = nodeType == Root;

		if (depth <= 0)
			return e.evaluate(b);

		// 0. Initialize data
		BoardParser::State s;
		cMove pv[MAX_PLY + 1];
		Value score = -VALUE_NONE, bestScore = -VALUE_NONE;
		++nodesSearched[pvIdx];

		std::vector<cMove> moveList;
		if (rootNode)
		{
			for (UInt i = 0; i < rootMoves.size(); ++i)
				moveList.push_back(rootMoves[i].pv[0]);
		}
		else
		{
			Search::generateMoveList(b, moveList, /*legalOnly=*/ true, /*onlyCapture=*/ false);
		}

		for (const cMove &move : moveList)
		{
			score = -VALUE_NONE;

			(ss + 1)->pv = nullptr;

			ss->currentMove = move;

			// 16. Make the move
			b.movePiece(move, s);

			(ss + 1)->pv = pv;
			(ss + 1)->pv[0] = cMove();

			score = -search<PV>(ss + 1, b, e, depth - 1);

			// 19. Undo move
			b.unMovePiece(move);

			if (depth > 1 && outOfTime())
				return -VALUE_NONE;

			// 20. Check for a new best move
			if (rootNode)
			{
				RootMove &rm = *std::find(rootMoves.begin(), rootMoves.end(), move);
				rm.averageScore = rm.averageScore != -VALUE_INFINITE ? (score + rm.averageScore) / 2 : score;

				rm.score = rm.uciScore = score;

				rm.pv.resize(1);
				for (cMove *m = (ss + 1)->pv; *m != cMove(); ++m)
					rm.pv.push_back(*m);
			}
			// 21. Update ss->pv
			if (score > bestScore)
			{
				bestScore = score;
				if (!rootNode)  // Update pv even in fail-high case
					update_pv(ss->pv, move, (ss + 1)->pv);
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

		for (UInt i = 0; i <= MAX_DEPTH + 2; ++i)
			(ss + i)->ply = i;
		ss->pv = pv;

		// Compute rootMoves (start_thingking in SF)
		rootMoves.clear();
		std::vector<cMove> moveList;
		Search::generateMoveList(b, moveList, /*legalOnly=*/ true, /*onlyCapture=*/ false);

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
		// This is only useful to manage time
		// It would be risky to estimate depth based on time since positions are sometimes easier to compute
		// A heuristic based on remaining pieces should work fine
		for (UInt currentDepth = 1; currentDepth < MAX_PLY && !(Limits.depth && currentDepth > Limits.depth); ++currentDepth)
		{
			search<Root>(ss, b, e, currentDepth);

			// Even if outofTime we keep a better move if there is one
			std::stable_sort(rootMoves.begin(), rootMoves.end());

			if (currentDepth > 1 && outOfTime())
			{
				break;
			}
			std::cout << UCI::pv(*this, currentDepth) << std::endl;
		}
		return rootMoves[0].pv[0];
	}
};
