module type;
import common;
import symbol : Symbol;

final class Member {
	string id, type_name;
	Type type;
}

final class RefType: Type {
	bool ro;
	pure this(bool ro_, Type type) {
		super(type);
		ro = ro_;
	}
	@property override bool has_storage() { return false; }
	override string toString() const {
		return (ro ? "ro" : "")~"&"~base.toString;
	}
}

final class ArrayType: Type {
	Expr[] dimensions;
	pure this(Type type, Expr[] exprs) {
		super(type);
		dimensions = exprs;
	}
	override string toString() const {
		import std.algorithm : map;
		import std.string : join;
		return base.toString~dimensions.map!q{"["~a.toString~"]"}.join("");
	}
}

final class DynamicArrayType: Type {
	pure this(Type type) { super(type); }
}

final class FuncType: Type {
	bool async;
	Type[] params;
	pure this(Type type, Type[] types) {
		super(type);
		params = types;
	}
	override string toString() const {
		import std.algorithm : map;
		import std.string : join;
		return (async ? "afn" : "fn")~"("~params.map!"a.toString".join(", ")~") -> "~base.toString;
	}
}

final class StructTypeDecl: TypeDecl {
	Member[] m;
	this(string t, Member[] _m) {
		m = _m;
		super(t);
	}
}
final class UnionTypeDecl: TypeDecl {
	Type[] m;
	this(string t, Type[] _m) {
		m = _m;
		super(t);
	}
}
TypeDecl[] builtin_types() {
	return [
		new TypeDecl("num"),
		new TypeDecl("bool"),
		new TypeDecl("string"),
	];
}

class TypeDecl: Symbol {
	this(string t) {
		super(t);
	}
	override string toString() const {
		return id;
	}
}

class Type {
	Type base;
	@property bool is_auto() { return base.is_auto; }
	@property bool has_storage() { return base.has_storage; }
	pure this(Type type) {
		base = type;
	}
	override string toString() const {
		return base.toString;
	}
}

final class BaseType : Type {
	TypeDecl decl;
	string decl_name;
	@property override bool is_auto() {
		return decl_name == "auto";
	}
	@property override bool has_storage() {
		return true;
	}
	pure this(string name) {
		super(null);
		decl_name = name;
	}
	override string toString() const {
		if (decl !is null)
			return "<"~decl.toString~">";
		return decl_name;
	}

}
