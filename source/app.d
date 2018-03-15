import std.stdio, std.file;
import parser;
import ast;
import ir;
import type;
import semantic : semantic;
import symbol;
import common;
import sdpc;

void main(string[] args) {
	auto x = InputType(args[1].readText);
	//"fn asdf(ro&num a, ro&num b, ro&num c) -> num {a+b+c;}");
	auto p = func(x);
	writeln(p.ok);
	if (!p.ok) {
		writeln(p.err);
		return;
	}
	auto fun = p.v;
	auto global = new Scope(Span.init, null, null);
	foreach(t; builtin_types())
		global.add(t);

	writeln(p.v);
	semantic(fun, global);
	writeln(p.v);

	auto ir = buildIR(fun);
	writeln(ir);
}
