module parser;
import ast;
import sdpc;
import common;
import symbol;
import type : BaseType, RefType, ArrayType, DynamicArrayType;
import std.functional, std.array, std.conv;
import std.typecons : Nullable;

alias Result(T) = sdpc.Result!(I, T, Err!I);

private auto map_or(alias func = "a", T, R = typeof(func(T.init)))(auto ref Nullable!T i, auto ref R o) {
	if (i.isNull)
		return o;
	alias uf = unaryFun!func;
	return uf(i.get);
}

auto make_param(R)(R i) {
	return new VarDecl(i.v!0, i.v!1.to!string);
}

auto make_func(R)(R i, in ref Span span) {
	return new Fun(i.v!0 == "afn", i.v!1.to!string, i.v!2,
	i.v!3.map_or!((a) => a.v!1)(new BaseType("void")), i.v!4, span);
}

auto param(I i) {
	return
	i.pipe!(seq!(
	             type,
	             ws!identifier,
	), wrap!make_param);
}

Type make_basetype(dchar[] ty) {
	return new BaseType(ty.to!string);
}

Type make_reftype(R)(R i) {
	return new RefType(!i.v!0.isNull, i.v!2);
}

// What does array type do?
// When passed as value argument, array is copied, even for dynamic arrays
// e.g. pass num[3][4] to num[][3], all elements are copied,
// when passed as ref argument, then a reference is passed even for static sized array
Type make_type(R)(R i) {
	auto ret = i.v!1;
	if (i.v!2.length > 0)
		ret = new ArrayType(ret, i.v!2);
	if (!i.v!0.isNull)
		ret = new DynamicArrayType(ret);
	return ret;
}

Result!Type type_no_array(I i) {
	return
	i.choice!(
	          pipe!(seq!(optional!(token!"ro"), token!"&", type), wrap!make_reftype),
	          pipe!(ws!identifier, wrap!make_basetype),
	);
}

Result!Type type(I i) {
	return
	i.pipe!(seq!(
	             optional!(token_ws!"[]"),
	             type_no_array, many!(between!(token_ws!"[", expression, token_ws!"]"), true)
	        ),
	        wrap!make_type
	);
}

alias I = InputType;

alias to_astnode = wrap!((a) => cast(AstNode)a);
alias to_stmt = wrap!((a) => cast(Stmt)a);

auto param_list(I i) { return i.pipe!(chain!(ws!param, token_ws!",", true), wrap!"a.map!\"a.v!0\".array"); }
auto expression_statement(I i) {
	return i.pipe!(seq!(expression, token_ws!";"),
	               wrap!((a) => cast(Stmt)(new ExprStmt(a.v!0))));
}

Stmt make_decl(R)(R i) {
	return
	new VarDeclStmt(
	         i.v!0,
	         i.v!1.to!string,
	         i.v!2.isNull ? null : i.v!2
	);
}

Stmt make_if(R)(R i) {
	return new If(i.v!1, i.v!2, i.v!3.map_or!"a.v!1"(null));
}

Stmt make_while(R)(R i) {
	return new While(i.v!3, i.v!4, i.v!1.map_or!(to!string)(""));
}

Stmt make_loop(R)(R i) {
	return new Loop(i.v!3, i.v!4.map_or(null), i.v!1.map_or!(to!string)(""));
}

Stmt make_cf(R)(R i) {
	final switch(i.v!0) {
	case "continue":
		return new Continue(i.v!1.map_or!(to!string)(""), i.v!3.map_or(null));
	case "break":
		return new Break(i.v!1.map_or!(to!string)(""), i.v!3.map_or(null));
	}
}

Stmt make_ret(R)(R i) {
	return new Return(i.v!1);
}

Stmt make_assign(R)(R i) {
	return new Assign(i.v!0, i.v!2);
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

auto control_flow(I i) {
	return
	i.pipe!(seq!(
	             choice!(token!"continue", token!"break"),
	             optional!block_tag, skip!whitespace, optional!expression,
	             token_ws!";"
	), wrap!make_cf);
}

auto return_(I i) {
	return
	i.pipe!(seq!(token_ws!"return", optional!expression, token_ws!";"), wrap!make_ret);
}

auto statement(I i) {
	return
	i.ws!(choice!(
	              control_flow,
	              return_,
	              expression_statement,
	              assign_statement,
	              block_statement,
	              declaration,
	              if_statement,
	              while_statement,
	              loop_statment
	));
}

auto statement_list(I i) { return i.many!(statement, true); }

Block make_block(Stmt[] i) {
	return new Block(i);
}

Result!Block block(I i) {
	return i.pipe!(between!(token_ws!"{", statement_list, token_ws!"}"), wrap!make_block);
}

Result!Stmt assign_statement(I i) {
	return i.pipe!(seq!(lvalue, token_ws!"=", expression, token_ws!";"), wrap!make_assign);
}

alias block_statement = pipe!(block, to_stmt);

auto func(I i) {
	return
	i.pipe!(span!(seq!(
	       ws!(choice!(token!"fn", token!"afn")),
	       ws!identifier,
	       ws!(between!(ws!(token!"("), ws!param_list, ws!(token!")"))),
	       optional!(seq!(ws!(token!"->"), type)),
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

alias block_tag = between!(token_ws!"[", ws!identifier, token_ws!"]");

auto while_statement(I i) {
	return
	i.pipe!(seq!(
	             token!"while",
	             optional!block_tag,
	             skip!whitespace,
	             expression,
	             block
	), wrap!make_while);
}

auto loop_statment(I i) {
	return
	i.pipe!(seq!(
	             token!"loop",
	             optional!block_tag,
	             skip!whitespace,
	             block,
	             optional!(between!(token_ws!"until", expression, token_ws!";"))
	), wrap!make_loop);
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
	return new Call(!i.v!0.isNull, i.v!1, i.v!2);
}

auto expression_list(R)(R i) {
	import std.algorithm : map;
	return i.pipe!(chain!(expression, token_ws!",", true), wrap!((a) => a.map!"a.v!0".array));
}

Lvalue make_varref(R)(R i) {
	return new VarRef(i.to!string);
}

auto lvalue(R)(R i) {
	return i.ws!(choice!(pipe!(identifier, wrap!make_varref)));
}

alias lvalue_expr = pipe!(lvalue, wrap!((a) => cast(Expr)a));

private alias prefix_op = ws!(choice!(token!"!", token!"~", token!"-", token!"+"));
private alias atom =
ws!(choice!(
            pipe!(choice!(token!"true", token!"false"), wrap!((a) => cast(Expr)new Boolean(a.to!string == "true"))),
            pipe!(seq!(optional!(token_ws!"$"), lvalue, between!(token_ws!"(", expression_list, token_ws!")")), wrap!make_call),
            pipe!(seq!(many!(prefix_op, true), lvalue), wrap!make_atom_uop),
            pipe!(number, wrap!((a) => cast(Expr)new Number(a))),
            pipe!(parse_string, wrap!((a) => cast(Expr)new String(a.to!string))),
            between!(token_ws!"(", expression, token!")"),
            lvalue_expr,
));

private alias op_pre1 = ws!(choice!(token!"*", token!"/"));
private alias term1 = pipe!(chain!(atom, op_pre1), wrap!make_bop);
private alias op_pre2 = ws!(choice!(token!"+", token!"-"));
private alias term2 = pipe!(chain!(term1, op_pre2), wrap!make_bop);
private alias op_pre3 = ws!(choice!(token!"==", token!"<=", token!">=", token!">", token!"<", token!"!="));
private alias term3 = pipe!(chain!(term2, op_pre3), wrap!make_bop);
private alias op_pre4 = ws!(choice!(token!"||", token!"&&"));
private alias term4 = pipe!(chain!(term3, op_pre4), wrap!make_bop);

Result!Expr expression(InputType i) {
	return term4(i);
}
