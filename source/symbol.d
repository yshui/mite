module symbol;
import common;

class Symbol {
	string id;
	pure this(string t) { id = t; }
}

interface Scoped {
	@property void s(Scope s);
	@property inout(Scope) s() inout;
	@property string tag() const;
}

class Scope {
	Span span;
	Scope parent;
	@property string tag() const { return b.tag; }
	Scoped b;
	Symbol[string] symbols;

	/// recursively symbol look up
	Symbol find(string name) {
		if (name in symbols)
			return symbols[name];
		if (parent !is null)
			return parent.find(name);
		return null;
	}

	Symbol find_local(string name) {
		if (name in symbols)
			return symbols[name];
		return null;
	}

	Scope find_parent(bool delegate(Scope s) match) {
		if (match(this))
			return this;
		if (!parent)
			return null;
		return parent.find_parent(match);
	}

	/// add a new symbol
	void add(Symbol sym) {
		symbols[sym.id] = sym;
	}

	this(Span s, Scope p, Scoped b_) {
		span = s;
		parent = p;
		b = b_;
	}
}
