module ir;
import common;
import symbol;
import ast;
import md;

class Inst { }

final class IBop: Inst {
	Var* lhs, rhs, res;
	enum Op {
		Add,
		Sub,
		Mul,
		Div,
		Le,
		Ge,
		L,
		G,
		Eq,
		Ne
	}
	Op op;
}

final class IUop: Inst {
	Var* v, res;
	enum Op {
		Neg,
		Comp
	}
	Op op;
}

final class Deref: Inst {
	Var* v, res;
}

final class Ret: Inst {
	Var* v;
}

struct Var {
	string name;
	Type type;
}
struct BB {
	string name;
	Inst[] inst;

	// 1 or 2 successors
	BB*[] succ;
	Var cond;
}

struct CFG {
	BB[] bb;
}

private struct Context {
	import std.meta: AliasSeq;
	alias StackElem = AliasSeq!(Scope, BB*);
	StackElem[] cstack;

	CFG cfg;
	BB* curr;
}

// ref BB irBuilder(AstNode a, ref BB current)

void buildIRImpl(ExprStmt es, ref Context ctx) {
	es.e.buildIR(ctx);
}

void buildIRImpl(Bop b, ref Context ctx) {
	b.lhs.buildIR(ctx);
	b.rhs.buildIR(ctx);
}

CFG buildIR(Fun f) {
	Context ctx;

	foreach(s; f.body.statements)
		s.buildIR(ctx);
	return ctx.cfg;
}

alias buildIR = multiDispatch!buildIRImpl;
