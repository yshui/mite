module semantic;
import symbol;
import common;
import ast;
import md;
import type;

class SemanticError: Exception {
	Span x;
	this(string err, Span x=Span.init, string file=__FILE__, int line=__LINE__) {
		super(err, file, line);
		this.x = x;
	}
}

void semanticImpl(TypeRef ty, Scope s) {
	if (ty.ro && !ty.isref)
		throw new SemanticError("`ro' but parameter is not a reference");
	if (ty.base_type_name == "auto") {
		if (ty.dimensions)
			throw new SemanticError("`auto' shouldn't have dimensions");
		ty.base_type = null;
		return;
	}
	auto sym = s.find(ty.base_type_name);
	if (sym is null)
		throw new SemanticError("Type `"~ty.base_type_name~"' is not defined");
	ty.base_type = cast(Type)sym;
	if (ty.base_type is null)
		throw new SemanticError("Symbol `"~ty.base_type_name~"' is not a type");
}

void semanticImpl(Variable v, Scope s) {
	v.type.semantic(s);
}

void semanticImpl(Bop e, Scope s) {
	e.lhs.semantic(s);
	e.rhs.semantic(s);
}

void semanticImpl(Uop e, Scope s) {
	e.e.semantic(s);
}

void semanticImpl(Decl d, Scope s) {
	auto sym = s.find_local(d.v.id);
	if (sym !is null)
		throw new SemanticError("Symbol `"~d.v.id~"' is already defined in the scope");
	d.v.semantic(s);
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

void semanticImpl(If i, Scope s) {
	i.cond.semantic(s);
	i.t.semantic(s);
	if (i.f !is null)
		i.f.semantic(s);
}

void semanticImpl(Call c, Scope s) {
	c.func.semantic(s);
	foreach(e; c.args)
		e.semantic(s);
}

void semanticImpl(Number n, Scope s) { }

alias semantic = multiDispatch!semanticImpl;
