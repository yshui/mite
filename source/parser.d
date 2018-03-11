module parser;
import ast;
import sdpc;
import common;
import std.functional, std.array, std.conv;

auto make_param(R)(R i) {
	bool isr = !i.v!0.isNull, ro = !i.v!1.isNull;
	auto ty = i.v!2;
	ty.isref = isr;
	ty.ro = ro;
	return new Variable(ty, i.v!3.to!string);
}

auto make_func(R)(R i, in ref Span span) {
	return new Fun(i.v!0 == "afn", i.v!1.to!string, i.v!2, new TypeRef(i.v!4.to!string, []), i.v!5, span);
}

auto param(I i) {
	return
	i.pipe!(seq!(
	             ws!(optional!(token!"ro")),
	             optional!(token!"&"),
	             type,
	             ws!identifier,
	), wrap!make_param);
}

auto make_typeref_bare(dchar[] ty) {
	return new TypeRef(ty.to!string, []);
}

auto type(I i) {
	return
	i.choice!(
	          pipe!(ws!identifier, wrap!make_typeref_bare)
	);
}

alias I = InputType;

alias to_astnode = wrap!((a) => cast(AstNode)a);
alias to_stmt = wrap!((a) => cast(Stmt)a);

auto param_list(I i) { return i.pipe!(chain!(ws!param, token_ws!","), wrap!"a.map!\"a.v!0\".array"); }
auto expression_statement(I i) {
	return i.pipe!(seq!(expression, token_ws!";"),
	               wrap!((a) => cast(Stmt)(new ExprStmt(a.v!0))));
}

Stmt make_decl(R)(R i) {
	return
	new Decl(
	         i.v!0,
	         i.v!1.to!string,
	         i.v!2.isNull ? null : i.v!2
	);
}

Stmt make_if(R)(R i) {
	return new If(i.v!1, i.v!2, i.v!3.isNull ? null : i.v!3.v!1);
}

auto declaration(I i) {
	return
	i.pipe!(seq!(
	       type,
	       ws!identifier,
	       optional!(pipe!(seq!(token_ws!"=", expression), wrap!"a.v!1")),
	       token_ws!";"
	), wrap!make_decl);
}

auto statement(I i) {
	return
	i.ws!(choice!(
	        expression_statement,
	        block_stmt,
	        declaration,
	        if_statement
	));
}

auto statement_list(I i) { return i.many!(statement, true); }

Block make_block(Stmt[] i) {
	return new Block(i);
}

Result!(I, Block, Err!I) block(I i) {
	return i.pipe!(between!(token_ws!"{", statement_list, token_ws!"}"), wrap!make_block);
}

alias block_stmt = pipe!(block, to_stmt);

auto func(I i) {
	return
	i.pipe!(span!(seq!(
	       ws!(choice!(token!"fn", token!"afn")),
	       ws!identifier,
	       ws!(between!(ws!(token!"("), ws!param_list, ws!(token!")"))),
	       ws!(token!"->"),
	       ws!identifier,
	       block
	)), wrap!make_func);
}

auto if_statement(I i) {
	return
	i.pipe!(seq!(
	             token_ws!"if",
	             expression,
	             block,
	             optional!(seq!(token_ws!"else", block)),
	), wrap!make_if);
}

auto make_atom_uop(R)(R i) {
	Expr e = new VarRef(i.v!1.to!string);
	foreach_reverse(x; i.v!0)
		e = new Uop(x, e);
	return e;
}

auto make_bop(R)(R[] i) {
	import std.algorithm.iteration;
	if (i.length == 1)
		return i[0].v!0;

	Expr e = new Bop(i[0].v!0, i[1].v!1, i[1].v!0);
	return i[2..$].fold!((a, b) => new Bop(a, b.v!1, b.v!0))(e);
}

Expr make_call(R)(R i) {
	return new Call(new VarRef(i.v!0.to!string), i.v!1);
}

auto expression_list(R)(R i) {
	import std.algorithm : map;
	return i.pipe!(chain!(expression, token_ws!",", true), wrap!((a) {
		import std.stdio;
		writeln(a.length);
		return a.map!"a.v!0".array;
	}));
}

private alias prefix_op = ws!(choice!(token!"!", token!"~", token!"-", token!"+"));
private alias atom =
ws!(choice!(
            pipe!(seq!(ws!identifier, between!(token_ws!"(", expression_list, token!")")), wrap!make_call),
            pipe!(seq!(many!(prefix_op, true), identifier), wrap!make_atom_uop),
            pipe!(number, wrap!((a) => cast(Expr)new Number(a))),
            between!(token_ws!"(", expression, token!")")
));

private alias op_pre1 = ws!(choice!(token!"*", token!"/"));
private alias term1 = pipe!(chain!(atom, op_pre1), wrap!make_bop);
private alias op_pre2 = ws!(choice!(token!"+", token!"-"));
private alias term2 = pipe!(chain!(term1, op_pre2), wrap!make_bop);
private alias op_pre3 = ws!(choice!(token!"||", token!"&&"));
private alias term3 = pipe!(chain!(term2, op_pre3), wrap!make_bop);

Result!(I, Expr, Err!I) expression(InputType i) {
	return term3(i);
}
