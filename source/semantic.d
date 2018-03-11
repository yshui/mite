module semantic;
import symbol;
import common;
import ast;
import md;
import type;
import resolver;

void semanticImpl(BaseType ty, Scope s) {
	if (ty.is_auto) {
		ty.decl = null;
		return;
	}
	auto sym = s.find(ty.decl_name);
	if (sym is null)
		throw new SemanticError("Type `"~ty.decl_name~"' is not defined");
	ty.decl = cast(TypeDecl)sym;
	if (ty.decl is null)
		throw new SemanticError("Symbol `"~ty.decl_name~"' is not a type");
}

void semanticImpl(RefType ty, Scope s) {
	ty.base.semantic(s);
	if (ty.is_auto)
		throw new SemanticError("Can't have ref to auto");
	if (cast(RefType)ty.base !is null)
		throw new SemanticError("Can't have ref to ref");
}

void semanticImpl(ArrayType ty, Scope s) {
	ty.base.semantic(s);
	foreach(e; ty.dimensions)
		e.semantic(s);
}

void semanticImpl(DynamicArrayType ty, Scope s) {
	ty.base.semantic(s);
}

void semanticImpl(Variable v, Scope s) {
	v.type.semantic(s);
}

void semanticImpl(Bop e, Scope s) {
	e.lhs.semantic(s);
	e.rhs.semantic(s);
	assert(e.lhs.type !is null);
	assert(e.rhs.type !is null);
	if (e.lhs.type.is_auto)
		throw new SemanticError("Unresolved auto type in "~e.lhs.toString);
	if (e.rhs.type.is_auto)
		throw new SemanticError("Unresolved auto type in "~e.rhs.toString);
	e.type = bopResolver(e.lhs.type, e.op, e.rhs.type);
}

void semanticImpl(Uop e, Scope s) {
	e.e.semantic(s);
	assert(e.e.type !is null);
	if (e.e.type.is_auto)
		throw new SemanticError("Unresolved auto type in "~e.e.toString);
	e.type = uopResolver(e.op, e.e.type);
}

void semanticImpl(Decl d, Scope s) {
	auto sym = s.find_local(d.v.id);
	if (sym !is null)
		throw new SemanticError("Symbol `"~d.v.id~"' is already defined in the scope");
	d.v.semantic(s);
	if (!d.v.type.has_storage)
		throw new SemanticError("Can't declare variable with reference type");
	if (d.i !is null)
		d.i.semantic(s);
	s.add(d.v);
}

void semanticImpl(ExprStmt es, Scope s) {
	es.e.semantic(s);
}

void semanticImpl(VarRef v, Scope s) {
	auto sym = s.find(v.id);
	v.v = cast(Variable)sym;
	if (sym is null)
		throw new SemanticError("Symbol `"~v.id~"' not found");
	if (v.v is null)
		throw new SemanticError("Symbol `"~v.id~"' is not a variable");
	v.type = v.v.type;
}

void semanticImpl(Block b, Scope s) {
	foreach(a; b.statements)
		a.semantic(s);
}

void semanticImpl(Fun f, Scope s) {
	f.s = new Scope(Span.init, s);
	foreach(p; f.params) {
		p.semantic(s);
		f.s.add(p);
	}
	s.add(f);
	f.type.semantic(s);
	f.body.semantic(f.s);
}

private bool isBool(Type t) {
	auto bt = cast(BaseType)t;
	if (bt !is null && typeid(bt.decl) == typeid(BoolTypeDecl))
		return true;
	auto rt = cast(RefType)t;
	if (rt !is null && typeid((cast(BaseType)rt.base).decl) == typeid(BoolTypeDecl))
		return true;
	return false;
}

void semanticImpl(If i, Scope s) {
	i.cond.semantic(s);
	i.t.semantic(s);
	if (i.f !is null)
		i.f.semantic(s);


	if (!i.cond.type.isBool)
		throw new SemanticError("If condition is not of type bool");
}

void semanticImpl(While w, Scope s) {
	w.cond.semantic(s);
	w.body.semantic(s);

	if (!w.cond.type.isBool)
		throw new SemanticError("While condition is not of type bool");
}

void semanticImpl(Loop l, Scope s) {
	l.body.semantic(s);
	if (l.cond !is null) {
		l.cond.semantic(s);

		if (!l.cond.type.isBool)
			throw new SemanticError("Loop condition is not of type bool");
	}
}

void semanticImpl(Assign a, Scope s) {
	a.lhs.semantic(s);
	a.rhs.semantic(s);

	if (a.lhs.type.is_auto) {
		auto v = cast(VarRef)a.lhs;
		assert(v !is null);
		v.v.type = a.rhs.type;
		v.type = v.v.type;
	}
}

void semanticImpl(Call c, Scope s) {
	c.func.semantic(s);
	foreach(e; c.args)
		e.semantic(s);
}

void semanticImpl(Number n, Scope s) {
	n.type = new BaseType(new NumTypeDecl);
}

void semanticImpl(Boolean b, Scope s) {
	b.type = new BaseType(new BoolTypeDecl);
}

alias semantic = multiDispatch!semanticImpl;
