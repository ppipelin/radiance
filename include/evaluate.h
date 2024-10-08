#pragma once

#include "include.h"

class Evaluate
{
public:
	Evaluate() = default;
	Evaluate(const Evaluate &) = default;
	virtual ~Evaluate() = default;

	virtual Value evaluate(const BoardParser &) const
	{
		return -VALUE_INFINITE;
	}
};
