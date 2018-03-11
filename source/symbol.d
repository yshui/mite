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

class Type: Symbol {
	this(string t) {
		super(t);
	}
	override string toString() const {
		return id;
	}
}

class Member {
	string id, type_name;
	Type type;
}
class StructType: Type {
	Member[] m;
	this(string t, Member[] _m) {
		m = _m;
		super(t);
	}
}
class UnionType: Type {
	Type[] m;
	this(string t, Type[] _m) {
		m = _m;
		super(t);
	}
}

Type[] builtin_types() {
	return [
		new Type("num"),
		new Type("bool"),
		new Type("string"),
	];
}
