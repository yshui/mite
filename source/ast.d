module ast;
import sdpc;
import type;
import symbol;
import common;

class Fun: Variable {
	bool async;
	Block body;
	Variable[] params;
	Scope s;
	Span span;
	pure this(bool a, string n, Variable[] p, Type t, Block b, Span x) {
		super(t, n);
		body = b;
		params = p;
		async = a;
		span = x;
	}
	override string toString() const {
		import std.array;
		import std.algorithm : map;
		import std.format;
		string ret = "%s, %s to %s, %s\n".format(span.begin_row, span.begin_col, span.end_row, span.end_col);
		ret ~= async ? "afn": "fn";
		ret ~= " "~id~"("~params.map!"a.toString()".join(",")~") -> "~type.toString~" ";
		ret ~= body.toString;
		return ret;
	}
}

class Lvalue: Expr {  }

class VarRef: Lvalue {
	string id;
	Variable v;
	pure this(string x) { id = x; }
	override string toString() const {
		if (v is null)
			return id;
		return id~"<"~v.type.toString~">";
	}
}

class Call: Expr {
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

class Number: Expr {
	double n;
	pure this(int i) { n = i; }
	pure this(double d) { n = d; }
	override string toString() const {
		import std.conv : to;
		return n.to!string;
	}
}

class Boolean: Expr {
	bool t;
	pure this(bool b) { t = b; }
	override string toString() const {
		return t ? "true" : "false";
	}
}

class Uop: Expr {
	string op;
	Expr e;
	pure this(string o, Expr _e) { op = o; e = _e; }
	override string toString() const {
		return "("~op~e.toString~")"~(type is null ? "" : type.toString);
	}
}

class Bop: Expr {
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

class Stmt: AstNode { }
class Decl: Stmt {
	Variable v;
	Expr i;
	pure this(Type tr, string id, Expr i_) {
		v = new Variable(tr, id);
		i = i_;
	}
	override string toString() const {
		return v.toString()~(i is null ? "" : i.toString())~";";
	}
}

class ExprStmt: Stmt {
	Expr e;
	pure this(Expr e_) { e = e_; }
	override string toString() const {
		return e.toString~";";
	}
}

class Block: Stmt {
	Stmt[] statements;
	pure this(Stmt[] s) {
		statements = s;
	}
	override string toString() const {
		import std.algorithm : map;
		import std.array : join;
		return "{\n"~statements.map!"a.toString()".join("\n")~"\n}";
	}
}

class If: Stmt {
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

class While: Stmt {
	Block body;
	Expr cond;
	pure this(Expr c, Block b) {
		cond = c;
		body = b;
	}
	override string toString() const {
		return "while "~cond.toString~" "~body.toString;
	}
}

class Loop: Stmt {
	Block body;
	Expr cond;
	pure this(Block b, Expr e) {
		cond = e;
		body = b;
	}
	override string toString() const {
		return "loop "~body.toString~(cond is null ? "" : "until "~cond.toString~" ;");
	}
}

class Assign: Stmt {
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

class Variable: Symbol {
	Type type;
	pure this(Type tr, string i) {
		super(i);
		type = tr;
	}
	override string toString() const {
		return type.toString()~" "~id;
	}
}
