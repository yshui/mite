module ir;
import common;
import symbol;
import ast;
import md;
import type;

import std.typecons : tuple;
import std.format : format;
import std.array : popBack;

class Inst {
	override string toString() const {
		return "inst";
	}
}

final class ICall: Inst {
	Var*[] param;
	Var* res;
	Var* func;
	pure this(Var* func, Var*[] p, Var* r) {
		param = p;
		res = r;
	}
}

final class IBop: Inst {
	Var* lhs, rhs, res;
	enum Op {
		Add,
		Sub,
		Mul,
		Div,
		And,
		Or,
		Le,
		Ge,
		L,
		G,
		Eq,
		Ne
	}
	Op op;
	pure this(Var* v1, Var* v2, Var* v3, Op op_) {
		lhs = v1;
		rhs = v2;
		res = v3;
		op = op_;
	}
	override string toString() const {
		return "%s = bop[%s] %s, %s".format(*res, op, *lhs, *rhs);
	}
}

final class IUop: Inst {
	Var* v, res;
	enum Op {
		Neg,
		Pos,
		Not,
		Comp
	}
	Op op;
	pure this(Var* v1, Var* v2, Op op_) {
		v = v1;
		res = v2;
		op = op_;
	}
	override string toString() const {
		return "%s = uop[%s] %s".format(*res, op, *v);
	}
}

final class Store: Inst {
	Var* addr, val;
	pure this(Var* v1, Var* v2) {
		addr = v1;
		val = v2;
	}
	override string toString() const {
		return "store *%s, %s".format(*addr, *val);
	}
}

final class Load: Inst {
	Var* addr, val;
	pure this(Var* v1, Var* v2) {
		addr = v1;
		val = v2;
	}
	override string toString() const {
		return "%s = load %s".format(*val, *addr);
	}
}

final class Imm: Inst {
	Var* tgt;
	Constant c;
	pure this(Var* v, Constant x) {
		c = x;
		tgt = v;
	}
	override string toString() const {
		return "%s = imm %s".format(*tgt, c);
	}
}

final class Ret: Inst {
	Var* v;
}

final class AddrOf: Inst {
	VarRef v;
	Var* res;
	pure this(VarRef v_, Var* res_) {
		v = v_;
		res = res_;
	}
	override string toString() const {
		return "%s = addr %s".format(*res, v);
	}
}

final class RefAddrOf: Inst {
	VarRef v;
	Var* res;
	pure this(VarRef v_, Var* res_) {
		v = v_;
		res = res_;
	}
	override string toString() const {
		return "%s = refaddr %s".format(*res, v);
	}
}

struct Var {
	import std.conv;
	string name;
	Type type;
	string toString() const {
		import std.format : formatValue;
		return name;
	}
	pure this(string n) {
		if (n == "")
			name = (&this).to!string;
		else
			name = n;
	}
}
struct BB {
	string name;
	Inst[] inst;

	// 1 or 2 successors
	BB*[] succ;
	Var* cond;

	pure this(string n) {
		name = n;
	}

	string toString() const {
		import std.algorithm : map;
		import std.string : join;
		return "[%s]{\n%s\n} (%s,%s,%s)".format(name,
				inst.map!((a) => a.toString).join(";\n"), cond,
				succ.length > 0 ? succ[0].name : null,
				succ.length > 1 ? succ[1].name : null);
	}
}

struct CFG {
	BB[] bb;
	string toString() const {
		import std.algorithm : map;
		import std.string : join;
		return bb.map!((ref a) => a.toString).join("\n");
	}
}

private struct Context {
	import std.typecons : Tuple;
	alias StackElem = Tuple!(Scope, BB*);
	StackElem[] cstack; // continuation stack

	CFG cfg;
	BB* curr;

	BB* new_bb_linked() {
		auto bb = new_bb;
		curr.succ = [bb];
		curr = bb;
		return bb;
	}

	BB* new_bb() {
		import std.conv : to;
		cfg.bb ~= BB(cfg.bb.length.to!string);
		return &cfg.bb[$-1];
	}

	BB* new_bb_curr() {
		curr = new_bb;
		return curr;
	}

	BB* get_continuation(Scope s) {
		foreach_reverse(e; cstack)
			if (s == e[0])
				return e[1];
		return null;
	}
}

Var* buildIRForRefImpl(VarRef v, BaseType t, ref Context ctx) {
	// Local
	auto ret = new Var("");
	ret.type = new RefType(false, v.type);
	auto inst = new AddrOf(v, ret);
	ctx.curr.inst ~= inst;
	return ret;
}
Var* buildIRForRefImpl(VarRef v, RefType t, ref Context ctx) {
	// Ref type
	// Cannot generate ir for ref to array
	assert(cast(BaseType)t.base !is null);
	auto ret = new Var("");
	ret.type = new RefType(t.ro, t.base);
	auto inst = new RefAddrOf(v, ret);
	ctx.curr.inst ~= inst;
	return ret;
}
alias buildIRForRef = multiDispatch!buildIRForRefImpl;

// ref BB irBuilder(AstNode a, ref BB current)

void buildIRImpl(ExprStmt es, ref Context ctx) {
	es.e.buildIR(ctx);
}

Var* buildIRImpl(Bop b, ref Context ctx) {
	IBop.Op[string] opt;
	with(IBop.Op) opt = [
		"+": Add,
		"-": Sub,
		"*": Mul,
		"/": Div,
		"&&": And,
		"||": Or,
		"<=": Le,
		">=": Ge,
		"<": L,
		">": G,
		"==": Eq,
		"!=": Ne,
	];

	auto ret = new Var("");
	auto op = opt[b.op];
	if (op == IBop.Op.And || op == IBop.Op.Or) {
		// short circuit not implemented
	} else {
		auto v1 = b.lhs.buildIR(ctx);
		auto v2 = b.rhs.buildIR(ctx);
		ctx.curr.inst ~= new IBop(v1, v2, ret, op);
	}
	return ret;
}

Var* buildIRImpl(Uop u, ref Context ctx) {
	IUop.Op[string] opt;
	with(IUop.Op) opt = [
		"-": Neg,
		"~": Comp,
		"+": Pos,
		"!": Not,
	];

	auto ret = new Var("");
	auto v1 = u.e.buildIR(ctx);
	ctx.curr.inst ~= new IUop(v1, ret, opt[u.op]);
	return ret;
}

Var* buildIRImpl(Number n, ref Context ctx) {
	auto ret = new Var("");
	ctx.curr.inst ~= new Imm(ret, n);
	return ret;
}

Var* buildIRImpl(Boolean b, ref Context ctx) {
	auto ret = new Var("");
	ctx.curr.inst ~= new Imm(ret, b);
	return ret;
}

Var* buildIRImpl(String str, ref Context ctx) {
	auto ret = new Var("");
	ctx.curr.inst ~= new Imm(ret, str);
	return ret;
}

Var* buildIRImpl(VarRef v, ref Context ctx) {
	auto v1 = buildIRForRef(v, v.type, ctx);
	auto v2 = new Var("");
	ctx.curr.inst ~= new Load(v1, v2);
	return v2;
}

Var* buildIRImpl(Call c, ref Context ctx) {
	import std.algorithm : map;
	import std.array : array;
	auto p = c.args.map!((a) => a.buildIR(ctx)).array;
	auto ret = new Var("");

	ctx.curr.inst ~= new ICall(c.func.buildIRForRef(c.func.type, ctx), p, ret);
	return ret;
}

void buildIRImpl(VarDeclStmt v, ref Context ctx) {}

void buildIRImpl(Assign a, ref Context ctx) {
	auto v1 = buildIRForRef(a.lhs, a.lhs.type, ctx);
	auto v2 = buildIR(a.rhs, ctx);

	ctx.curr.inst ~= new Store(v1, v2);
}

void buildIRImpl(If i, ref Context ctx) {
	auto end_bb = ctx.new_bb;
	auto condv = i.cond.buildIR(ctx);

	auto cond_bb = ctx.curr;
	cond_bb.cond = condv;

	auto then_bb = ctx.new_bb_curr;
	i.t.buildIR(ctx);
	ctx.curr.succ = [end_bb];

	auto else_bb = ctx.new_bb_curr;
	if (i.f !is null)
		i.f.buildIR(ctx);
	ctx.curr.succ = [end_bb];

	cond_bb.succ = [then_bb, else_bb];
}

void buildIRImpl(While w, ref Context ctx) {
	auto end = ctx.new_bb;
	ctx.cstack ~= tuple(w.s, end);

	auto cond_start = ctx.new_bb_linked;
	auto condv = w.cond.buildIR(ctx);
	auto cond_end = ctx.curr;

	auto body_start = ctx.new_bb_curr;
	w.body.buildIR(ctx);
	ctx.curr.succ = [cond_start];

	cond_end.cond = condv;
	cond_end.succ = [body_start, end];
	ctx.curr = end;
}

void buildIRImpl(Loop w, ref Context ctx) {
	auto end = ctx.new_bb;
	ctx.cstack ~= tuple(w.s, end);

	auto body_start = ctx.new_bb_curr;
	w.body.buildIR(ctx);

	if (w.cond !is null) {
		ctx.curr.cond = w.cond.buildIR(ctx);
		ctx.curr.succ = [body_start, end];
	} else
		ctx.curr.succ = [body_start];
	ctx.curr = end;
}

void buildIRImpl(Break b, ref Context ctx) {
	ctx.curr.succ = [ctx.get_continuation(b.target)];
	ctx.new_bb_curr;
}

void buildIRImpl(Continue b, ref Context ctx) {
	ctx.curr.succ = [ctx.get_continuation(b.target)];
	ctx.new_bb_curr;
}

void buildIRImpl(Block b, ref Context ctx) {
	auto bb = ctx.new_bb;
	ctx.cstack ~= tuple(b.s, bb);
	foreach(s; b.statements)
		s.buildIR(ctx);
	ctx.cstack.popBack;
	ctx.curr = bb;
}


CFG buildIR(Fun f) {
	Context ctx;

	ctx.new_bb_curr;
	f.body.buildIR(ctx);
	return ctx.cfg;
}

alias buildIR = multiDispatch!buildIRImpl;
