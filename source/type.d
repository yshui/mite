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
		assert(type !is null);
		super(type);
		ro = ro_;
	}
	@property override bool has_storage() { return false; }
	override string toString() const {
		return (ro ? "ro" : "")~"&"~base.toString;
	}
	invariant { assert(base !is null); }
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
		new NumTypeDecl(),
		new BoolTypeDecl(),
		new StringTypeDecl(),
		new VoidTypeDecl(),
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

class NumTypeDecl: TypeDecl { this() { super("num"); } }

class BoolTypeDecl: TypeDecl { this() { super("bool"); } }

class StringTypeDecl: TypeDecl { this() { super("string"); } }

class VoidTypeDecl: TypeDecl { this() { super("void"); } }

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
	pure this(TypeDecl td) {
		super(null);
		decl = td;
		decl_name = [];
	}
	override string toString() const {
		if (decl !is null)
			return "<"~decl.toString~">";
		return decl_name;
	}

}
