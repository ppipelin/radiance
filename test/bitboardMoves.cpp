#include "../include/search.h"

int main(int argc, char *argv[])
{
	BoardParser b;
	BoardParser::State s;
	const std::string startFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

	b.fillBoard(startFen, &s);

	const std::string moves[] = { "g1h3", "g8h6", "g2g3", "d7d5", "h3f4", "e7e5", "d2d3", "e5f4", "f2f3", "f8d6", "f1g2", "h6f5", "e1g1", "f5e3", "a2a4", "e3d1", "c2c3", "d1e3", "c1e3", "f4e3", "b1d2", "e3d2", "f1f2", "c8d7", "a1a2", "d2d1q", "g2f1", "d1b1", "a4a5", "b1a2", "a5a6", "a2a6", "e2e4", "d5e4", "f3e4", "a6a1", "f2f7", "e8f7", "g1g2", "d7h3", "g2h3" };
	for (std::string move : moves)
	{
		cMove realMove = b.toMove(move);
		b.movePiece(realMove, s);
	}

	b.displayCLI();
	b.displayBBCLI();

	return Bitboards::bbPieces[0] != 0 || Bitboards::bbPieces[1] != 56013520638870016 || Bitboards::bbPieces[2] != 144115188075855872 || Bitboards::bbPieces[3] != 8796093022240 || Bitboards::bbPieces[4] != 9295429630892703744 || Bitboards::bbPieces[5] != 576460752303423489 || Bitboards::bbPieces[6] != 9007199263129600 || Bitboards::bbPieces[7] != 10081035087267004961 || Bitboards::bbColors[0] != 10081035086985166849 || Bitboards::bbColors[1] != 281838112;
}

