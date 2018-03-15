module ast;
import sdpc;
import type;
import symbol;
import common;
import std.format : format;

final class Fun: VarDecl, Scoped {
	bool async;
	Block body;
	VarDecl[] params;
	Scope _s;
	Span span;
	override @property void s(Scope s) { _s = s; }
	override @property inout(Scope) s() inout { return _s; }
	override @property string tag() const { return ""; }
	pure this(bool a, string n, VarDecl[] p, Type t, Block b, Span x) {
		super(t, n);
		body = b;
		params = p;
		async = a;
		span = x;
	}
	override string toString() const {
		import std.array;
		import std.algorithm : map;
		string ret = "%s, %s to %s, %s\n".format(span.begin_row, span.begin_col, span.end_row, span.end_col);
		ret ~= async ? "afn": "fn";
		ret ~= " %s (%s) -> %s ".format(id, params.map!"a.toString()".join(","), type);
		ret ~= body.toString;
		return ret;
	}
}

class Lvalue: Expr {  }

final class VarRef: Lvalue {
	string id;
	VarDecl v;
	pure this(string x) { id = x; }
	override string toString() const {
		if (v is null)
			return id;
		return "%s<%s>".format(id, v.type);
	}
}

final class Call: Expr {
	Lvalue func;
	Expr[] args;
	bool await;
	pure this(bool a, Lvalue v, Expr[] exprs) {
		await = a;
		func = v;
		args = exprs;
	}
	override string toString() const {
		import std.algorithm : map;
		import std.string : join;
		import std.array : array;
		import std.conv : to;
		return (await ? "$" : "")~func.toString~"("~args.map!"a.toString".join(", ").array.to!string~")";
	}
}

class Constant: Expr {}

final class Number: Constant {
	double n;
	pure this(int i) { n = i; }
	pure this(double d) { n = d; }
	override string toString() const {
		import std.conv : to;
		return n.to!string;
	}
}

final class Boolean: Constant {
	bool t;
	pure this(bool b) { t = b; }
	override string toString() const {
		return t ? "true" : "false";
	}
}

final class String: Constant {
	string str;
	pure this(string s) { str = s; }
	override string toString() const {
		return "\""~str~"\"";
	}
}

final class Uop: Expr {
	string op;
	Expr e;
	pure this(string o, Expr _e) { op = o; e = _e; }
	override string toString() const {
		return "("~op~e.toString~")"~(type is null ? "" : type.toString);
	}
}

final class Bop: Expr {
	string op;
	Expr lhs, rhs;
	pure this(Expr lhs_, string o, Expr rhs_) {
		lhs = lhs_;
		op = o;
		rhs = rhs_;
	}
	override string toString() const {
		return "("~lhs.toString~op~rhs.toString~")"~(type is null ? "" : type.toString);
	}
}

final class VarDeclStmt: Stmt {
	VarDecl v;
	Expr i;
	pure this(Type tr, string id, Expr i_) {
		v = new VarDecl(tr, id);
		i = i_;
	}
	override string toString() const {
		return v.toString()~(i is null ? "" : i.toString())~";";
	}
}

final class ExprStmt: Stmt {
	Expr e;
	pure this(Expr e_) { e = e_; }
	override string toString() const {
		return e.toString~";";
	}
}

class ScopedStmt: Stmt, Scoped {
	private Scope _s;
	private string _tag;

	pure this(string tag) {
		_tag = tag;
	}

	override @property void s(Scope s) { _s = s; }
	override @property inout(Scope) s() inout { return _s; }
	override @property string tag() const { return _tag; }
}

final class Block: ScopedStmt {
	Stmt[] statements;
	pure this(Stmt[] s) {
		statements = s;
		super("");
	}
	override string toString() const {
		import std.algorithm : map;
		import std.array : join;
		return "["~tag~"] {\n"~statements.map!"a.toString()".join("\n")~"\n}";
	}
}

final class If: Stmt {
	Block t, f;
	Expr cond;
	pure this(Expr c, Block t_, Block f_=null) {
		cond = c;
		t = t_;
		f = f_;
	}
	override string toString() const {
		string ret = "if "~cond.toString~" "~t.toString;
		if (f !is null)
			ret ~= " else "~f.toString;
		return ret;
	}
}

final class While: ScopedStmt {
	Block body;
	Expr cond;
	pure this(Expr c, Block b, string tag) {
		super(tag);
		cond = c;
		body = b;
	}
	override string toString() const {
		return "while "~cond.toString~" "~body.toString;
	}
}

final class Loop: ScopedStmt {
	Block body;
	Expr cond;
	pure this(Block b, Expr e, string tag) {
		super(tag);
		cond = e;
		body = b;
	}
	override string toString() const {
		import std.format;
		return "loop [%s] %s".format(tag, body)~
		    (cond is null ? "" : "until %s ;".format(cond));
	}
}

final class Assign: Stmt {
	Lvalue lhs;
	Expr rhs;
	pure this(Lvalue lv, Expr e) {
		lhs = lv;
		rhs = e;
	}
	override string toString() const {
		return lhs.toString~" = "~rhs.toString~";";
	}
}

final class Continue: Stmt {
	string tag;
	Expr r; //XXX
	Scope target;
	pure this(string t, Expr e) {
		tag = t;
		r = e;
	}
	override string toString() const {
		return "continue"~"["~tag~"] "~(r is null ? "" : r.toString)~";";
	}
}

final class Break: Stmt {
	string tag;
	Expr r;
	Scope target;
	pure this(string t, Expr e) {
		tag = t;
		r = e;
	}
	override string toString() const {
		return "break"~"["~tag~"] "~(r is null ? "" : r.toString)~";";
	}
}

final class Return: Stmt {
	Expr r;
	Scope target;
	pure this(Expr e) {
		r = e;
	}
	override string toString() const {
		return "return "~r.toString~";";
	}
}

class VarDecl: Symbol {
	Type type;
	pure this(Type tr, string i) {
		super(i);
		type = tr;
	}
	override string toString() const {
		return type.toString()~" "~id;
	}
}
