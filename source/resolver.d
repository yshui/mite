// Type resolver
module resolver;
import common;
import type;
import md;
import ast;
import symbol;
import std.meta;

struct BopRule(string op_, Lhs_, Rhs_, Res_) {
	enum string op = op_;
	alias Lhs = Lhs_;
	alias Rhs = Rhs_;
	alias Res = Res_;
}

Type bopResolverImpl(BaseType lhs, string o, BaseType rhs) {
	alias rules = AliasSeq!(
	    BopRule!("+", NumTypeDecl, NumTypeDecl, NumTypeDecl),
	    BopRule!("-", NumTypeDecl, NumTypeDecl, NumTypeDecl),
	    BopRule!("*", NumTypeDecl, NumTypeDecl, NumTypeDecl),
	    BopRule!("/", NumTypeDecl, NumTypeDecl, NumTypeDecl),
	    BopRule!("+", StringTypeDecl, StringTypeDecl, StringTypeDecl),
	    BopRule!("||", BoolTypeDecl, BoolTypeDecl, BoolTypeDecl),
	    BopRule!("&&", BoolTypeDecl, BoolTypeDecl, BoolTypeDecl),
	    BopRule!("==", NumTypeDecl, NumTypeDecl, BoolTypeDecl),
	    BopRule!("==", StringTypeDecl, StringTypeDecl, BoolTypeDecl),
	    BopRule!("==", BoolTypeDecl, BoolTypeDecl, BoolTypeDecl),
	    BopRule!("!=", NumTypeDecl, NumTypeDecl, BoolTypeDecl),
	    BopRule!("!=", StringTypeDecl, StringTypeDecl, BoolTypeDecl),
	    BopRule!("!=", BoolTypeDecl, BoolTypeDecl, BoolTypeDecl),
	    BopRule!("<=", NumTypeDecl, NumTypeDecl, BoolTypeDecl),
	    BopRule!(">=", NumTypeDecl, NumTypeDecl, BoolTypeDecl),
	    BopRule!("<", NumTypeDecl, NumTypeDecl, BoolTypeDecl),
	    BopRule!(">", NumTypeDecl, NumTypeDecl, BoolTypeDecl),
	);

	foreach(T; rules) {
		if (o == T.op &&
		    typeid(lhs.decl) == typeid(T.Lhs) &&
		    typeid(rhs.decl) == typeid(T.Rhs))
			return new BaseType(new T.Res);
	}
	throw new SemanticError("Operator "~o~" can't be used with type "~lhs.toString~" and type "~rhs.toString);
}

Type bopResolverImpl(BaseType lhs, string o, RefType rhs) {
	return bopResolver(lhs, o, rhs.base);
}

Type bopResolverImpl(RefType lhs, string o, BaseType rhs) {
	return bopResolver(lhs.base, o, rhs);
}

Type bopResolverImpl(RefType lhs, string o, RefType rhs) {
	return bopResolver(lhs.base, o, rhs.base);
}

Type bopResolver(Type lhs, string o, Type rhs) {
	try {
		return multiDispatch!bopResolverImpl(lhs, o, rhs);
	} catch(OverloadNotFoundException e) {
		throw new SemanticError("Operator "~o~" can't be used with type "~lhs.toString~" and type "~rhs.toString);
	}
}

struct UopRule(string op_, Expr_, Res_) {
	enum string op = op_;
	alias Expr = Expr_;
	alias Res = Res_;
}

Type uopResolverImpl(string op, BaseType e) {
	alias rules = AliasSeq!(
	    UopRule!("-", NumTypeDecl, NumTypeDecl),
	    UopRule!("~", NumTypeDecl, NumTypeDecl),
	    UopRule!("!", BoolTypeDecl, BoolTypeDecl),
	    UopRule!("+", NumTypeDecl, NumTypeDecl)
	);

	auto et = cast(BaseType)e;

	if (et !is null) {
		foreach(T; rules) {
			if (op == T.op && typeid(et.decl) == typeid(T.Expr))
				return new BaseType(new T.Res);
		}
	}
	throw new SemanticError("Operator "~op~" can't be used with type "~e.toString);
}

Type uopResolverImpl(string op, RefType e) {
	return uopResolver(op, e.base);
}

Type uopResolver(string o, Type ex) {
	try {
		return multiDispatch!uopResolverImpl(o, ex);
	} catch(OverloadNotFoundException e) {
		throw new SemanticError("Operator "~o~" can't be used with type "~ex.toString);
	}
}
