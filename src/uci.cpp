#include "uci.h"

#include "cMove.h"
#include "boardParser.h"
#include "search.h"
#include "searchRandom.h"
#include "searchMaterialist.h"
#include "searchMaterialistNegamax.h"
#include "evaluate.h"
#include "evaluateShannon.h"
#include "evaluateShannonHeuristics.h"
#include "evaluateTable.h"
#include "evaluateTableTuned.h"

#include <queue>
#include <chrono>
#include <numeric>
#include <thread>
#include <future>
#include <sstream>

bool g_stop = false;

namespace {
	const std::string startFen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
	const std::string kiwiFen("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -");
	// A list to keep track of the position states along the setup moves (from the
	// start position to the position just before the search starts).
	// Needed by 'draw by repetition' detection. Use a std::deque because pointers to
	// elements are not invalidated upon list resizing.
	using StateListPtr = std::unique_ptr<std::deque<BoardParser::State> >;

	void position(BoardParser &pos, std::istringstream &is, StateListPtr &states)
	{
		cMove c;
		std::string token, fen;

		is >> token;
		if (token == "startpos")
		{
			fen = startFen;
			is >> token; // Consume the "moves" token, if any
		}
		else if (token == "kiwi")
		{
			fen = kiwiFen;
			is >> token; // Consume the "moves" token, if any
		}
		else if (token == "fen")
		{
			while (is >> token && token != "moves")
				fen += token + " ";
		}
		else
			return;

		// Drop the old state and create a new one
		// fillBoard() adds constructed State to pos
		states = StateListPtr(new std::deque<BoardParser::State>(1));
		pos.fillBoard(fen, &states->back());

		transpositionTable.clear();
		// Parse the moves list, if any
		while (is >> token && (c = pos.toMove(token)) != cMove())
		{
			states->emplace_back();
			pos.movePiece(c, states->back());
		}
	}

	// setoption() is called when the engine receives the "setoption" UCI command.
	// The function updates the UCI option ("name") to the given value ("value").
	void setoption(std::istringstream &is)
	{
		std::string token, name, value;

		is >> token; // Consume the "name" token

		// Read the option name (can contain spaces)
		while (is >> token && token != "value")
			name += (name.empty() ? "" : " ") + token;

		// Read the option value (can contain spaces)
		while (is >> token)
			value += (value.empty() ? "" : " ") + token;

		if (Options.count(name))
			Options[name] = value;
		else
			std::cout << "No such option: " << name << std::endl;
	}

	// go() is called when the engine receives the "go" UCI command. The function
	// sets the thinking time and other parameters from the input string, then starts
	// with a search.
	void go(BoardParser &pos, std::istringstream &is)
	{
		Search::LimitsType limits;
		std::string token;
		g_stop = false;

		limits.startTime = now(); // The search starts as early as possible

		while (!is.str().empty() && is >> token)
		{
			if (token == "searchmoves") // Needs to be the last command on the line
				while (is >> token)
					// limits.searchmoves.push_back(pos.toMove(token));
					;
			else if (token == "wtime")     is >> limits.time[WHITE];
			else if (token == "btime")     is >> limits.time[BLACK];
			// else if (token == "winc")      is >> limits.inc[WHITE];
			// else if (token == "binc")      is >> limits.inc[BLACK];
			// else if (token == "movestogo") is >> limits.movestogo;
			else if (token == "depth")     is >> limits.depth;
			// else if (token == "nodes")     is >> limits.nodes;
			else if (token == "movetime")  is >> limits.movetime;
			// else if (token == "mate")      is >> limits.mate;
			else if (token == "perft")     is >> limits.perft;
			else if (token == "infinite")  limits.infinite = 1;
			// else if (token == "ponder")    ponderMode = true;
		}

		if (limits.perft > 0)
		{
			auto t1 = std::chrono::high_resolution_clock::now();
			UInt nodes = Search::perft(pos, limits.perft, true);
			std::cout << "info nodes " << nodes;
			auto t2 = std::chrono::high_resolution_clock::now();
			auto ms_int = std::chrono::duration_cast<std::chrono::milliseconds>(t2 - t1);
			std::cout << " time " << ms_int.count() << std::endl;
		}
		else
		{
			// SearchRandom search = SearchRandom(limits, &g_stop);
			// SearchMaterialist search = SearchMaterialist(limits, &g_stop);
			SearchMaterialistNegamax search = SearchMaterialistNegamax(limits, &g_stop);
			// EvaluateShannon evaluate = EvaluateShannon();
			// EvaluateShannonHeuristics evaluate = EvaluateShannonHeuristics();
			// EvaluateTable evaluate = EvaluateTable();
			EvaluateTableTuned evaluate = EvaluateTableTuned();

			// std::future<cMove> moveAsync = std::async(&(SearchMaterialistNegamax::nextMove), std::ref(search), std::ref(pos), std::ref(evaluate));
			// cMove move = moveAsync.get();

			cMove move = search.nextMove(pos, evaluate);

			std::cout << "bestmove " << UCI::move(move) << std::endl;
		}
	}
}

/// UCI::loop() waits for a command from the stdin, parses it and then calls the appropriate
/// function. It also intercepts an end-of-file (EOF) indication from the stdin to ensure a
/// graceful exit if the GUI dies unexpectedly. When called with some command-line arguments,
/// like running 'bench', the function returns immediately after the command is executed.
/// In addition to the UCI ones, some additional debug commands are also supported.
void UCI::loop(int argc, char *argv[])
{
	BoardParser pos;
	StateListPtr states(new std::deque<BoardParser::State>(1));
	std::string token, cmd;

	std::thread mainThread;
	std::istringstream stream;

	pos.fillBoard(startFen, &states->back());

	std::queue<std::string> q;
	for (Int i = 1; i < argc; ++i)
		q.push(std::string(argv[i]));
	{
		// q.push("position fen r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -");
		// q.push("go depth 4");
		// q.push("position fen 8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -");
		// q.push("go depth 4");
		// q.push("position fen r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1");
		// q.push("go depth 4");
	}
	do
	{
		do // do-while until queue is empty
		{
			if (!q.empty())
			{
				cmd = q.front();
				std::cout << "queue (" << q.size() << ") command: " << cmd << std::endl;
				q.pop();
			}
			else
			{
				if (argc == 1 && !getline(std::cin, cmd)) // Wait for an input or an end-of-file (EOF) indication
					cmd = "quit";
			}

			std::istringstream is(cmd);

			token.clear(); // Avoid a stale if getline() returns nothing or a blank line
			is >> std::skipws >> token;

			if (token == "quit" || token == "stop")
				g_stop = true;

			// The GUI sends 'ponderhit' to tell that the user has played the expected move.
			// So, 'ponderhit' is sent if pondering was done on the same move that the user
			// has played. The search should continue, but should also switch from pondering
			// to the normal search.
			else if (token == "d")
			{
				pos.displayCLI();
				pos.displayBBCLI();
				std::cout << "fen: " << pos.fen() << std::endl;
				std::cout << "zobrist: " << pos.m_s->materialKey << std::endl;
			}

			else if (token == "ponderhit")
				std::cout << "UCI - ponderhit received" << std::endl;
			else if (token == "uci")
			{
				std::stringstream patch;
				if constexpr (PATCH != 0)
					patch << "." << PATCH;
				else
					patch << "";
				std::cout << "id name Radiance " << MAJOR << "." << MINOR << patch.str() << std::endl;
				std::cout << "id author Paul-Elie Pipelin (ppipelin)" << std::endl;
				std::cout << Options << std::endl;
				std::cout << "uciok" << std::endl;
			}
			else if (token == "setoption")
				setoption(is);
			else if (token == "go")
			{
				// ::go(pos, is);
				if (mainThread.joinable())
					mainThread.join();
				stream = std::istringstream(is.str());
				mainThread = std::thread(::go, std::ref(pos), std::ref(stream));
			}
			else if (token == "position")
				position(pos, is, states);
			else if (token == "ucinewgame")
			{
				states = StateListPtr(new std::deque<BoardParser::State>(1));
				pos.fillBoard(startFen, &states->back());
			}
			else if (token == "isready")
				std::cout << "readyok" << std::endl;
			else if (token == "eval")
				std::cout << "UCI - eval called" << std::endl;
			else if (token == "--help" || token == "help" || token == "--license" || token == "license")
				std::cout << "\nRadiance is chess engine for playing and analyzing."
				"\nIt supports Universal Chess Interface (UCI) protocol to communicate with a GUI, an API, etc."
				"\nor read the corresponding README.md and Copying.txt files distributed along with this program." << std::endl;
			else if (!token.empty() && token[0] != '#')
				std::cout << "UCI - Unknown command: '" << cmd << "'." << std::endl;
		} while (!q.empty());
	} while (token != "quit" && argc == 1); // The command-line arguments are one-shot
	if (mainThread.joinable())
		mainThread.join();
}

/// UCI::square() converts a const UInt to a string in algebraic notation (g1, a7, etc.)
std::string UCI::square(const UInt s)
{
	return Board::toString(s);
}

/// UCI::move() converts a Move to a string in coordinate notation (g1f3, a7a8q).
std::string UCI::move(cMove m)
{
	if (m == cMove())
		return "(none)";

	const UInt from = m.getFrom();
	const UInt to = m.getTo();

	std::string move = Board::toString(from) + Board::toString(to);

	if (m.isPromotion())
		move += "nbrq"[m.getFlags() & 0x3]; // keep last two bits

	return move;
}

// UCI::pv() formats PV information according to the UCI protocol. UCI requires
// that all (if any) unsearched PV lines are sent using a previous search score.
std::string UCI::pv(const Search &s, UInt depth)
{
	std::stringstream ss;

	for (Int i = 0; i < 1; ++i)
	{
		// Not at first line
		if (ss.rdbuf()->in_avail())
			ss << "\n";

		UInt nodes = std::accumulate(s.nodesSearched.begin(), s.nodesSearched.end(), 0);
		ss << "info"
			<< " depth " << depth
			<< " nodes " << nodes
			<< " nps " << nodes * 1000 / std::max(s.elapsed(), TimePoint(1))
			<< " hash " << transpositionTable.size()
			<< " hashfull " << std::round(transpositionTable.size() * 1000 / transpositionTable.max_size())
			<< " hashused " << s.transpositionUsed
			<< " time " << s.elapsed()
			<< " multipv " << i + 1
			<< " score cp " << s.rootMoves[i].score
			<< " pv";

		auto a = std::count_if(s.rootMoves[i].pv.begin(), s.rootMoves[i].pv.end(), [](const cMove c) { return c != 0; });
		for (UInt j = 0; j < a; ++j)
			ss << " " << UCI::move(s.rootMoves[i].pv[j]);
	}
	return ss.str();
}
