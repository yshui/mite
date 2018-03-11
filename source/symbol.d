module symbol;
import common;

class Symbol {
	string id;
	pure this(string t) { id = t; }
}

class Scope {
	Span span;
	Scope parent;
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

	/// add a new symbol
	void add(Symbol sym) {
		symbols[sym.id] = sym;
	}

	this(Span s, Scope p) {
		span = s;
		parent = p;
	}
}
