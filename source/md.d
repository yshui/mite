module md;

private struct _types(T_...) {
	alias T = T_;
}
class OverloadNotFoundException : Exception {
	this(string err, string file=__FILE__, int line=__LINE__) {
		super(err, file, line);
	}
}
private bool isCompatible(alias F, T...)() {
	import std.traits;
	alias STC = ParameterStorageClass;
	alias p = Parameters!F;
	alias stc = ParameterStorageClassTuple!F;
	static if (p.length != T.length)
		return false;
	else {
		bool ret = true;
		static foreach(id, FT; Parameters!F)
		if (!is(FT == T[id])) {
			// Requires casting
			if (stc[id] == STC.ref_)
				// can't cast when ref is used
				ret = false;
			else if (is(FT == class)) {
				// if the candidate takes a class
				// then only downcasting is allowed
				if (!is(FT: T[id]))
					ret = false;
			} else if (!is(T[id]: FT))
				// otherwise, only upcasting is allowed
				ret = false;
		}
		return ret;
	}
}
private bool isPerfectMatch(alias F, T...)() {
	import std.traits;
	alias STC = ParameterStorageClass;
	alias p = Parameters!F;
	alias stc = ParameterStorageClassTuple!F;
	static if (p.length != T.length)
		return false;
	else {
		bool ret = true;
		static foreach(id, FT; Parameters!F)
		if (!__traits(isFinalClass, FT))
			// If the function doesn't take a final class,
			// then even if the static type matches, runtime
			// type can still mismatch
			ret = false;
		else if (!is(FT == T[id])) {
			// Casting is required
			if (stc[id] == STC.ref_)
				ret = false;
			else if (is(FT == class))
				// parameters of class types have to
				// match perfectly
				ret = false;
			else if (!is(T[id]: FT))
				// non class type can be casted
				ret = false;
		}
		return ret;
	}
}
/// filter overloads according to argument types
private template filterOverloads(alias M, T, Funs...) {
	import std.meta : AliasSeq;
	static if (is(T == _types!Ts, Ts...)) {
		static if (Funs.length == 1) {
			static if (M!(Funs[0], Ts))
				alias filterOverloads = Funs;
			else
				alias filterOverloads = AliasSeq!();
		} else
			alias filterOverloads = AliasSeq!(filterOverloads!(M, T, Funs[0..$/2]), filterOverloads!(M, T, Funs[$/2..$]));
	} else
		static assert(false);
}
private template stringOfFun(alias fun) {
	enum string stringOfFun = typeof(fun).stringof;
}
private template joinStr(string delim, T...) {
	static if (T.length == 1)
		enum string joinStr = T[0];
	else
		enum string joinStr = joinStr!(delim, T[0..$/2])~delim~joinStr!(delim, T[$/2..$]);
}
private string genCall(T...)() {
	import std.format;
	import std.string : join;
	static assert(T.length%2 == 0);
	alias CandParamsT = T[0..$/2];
	alias ArgsT = T[$/2..$];
	string[] ret;
	static foreach(id, P; CandParamsT) {
		static if (is(P == ArgsT[id]))
			ret ~= "args[%s]".format(id);
		else
			ret ~= "args2[%s]".format(id);
	}
	return "return o("~ret.join(",")~");";
}
private template isIClass(T) {
	enum isIClass = is(T == class) || is(T == interface);
}

private template Params(alias fun) {
	import std.traits;
	alias Params = _types!(Parameters!fun);
}

template multiDispatch(alias func) {
	import std.traits;
	import std.meta;
	auto ref multiDispatch(T...)(auto ref T args) {
		alias overloads = AliasSeq!(__traits(getOverloads, __traits(parent, func), __traits(identifier, func)));
		alias perfect_match = filterOverloads!(isPerfectMatch, _types!T, overloads);
		static if (perfect_match.length != 0) {
			static assert(perfect_match.length == 1, "Conflicting overloads: \n\t"~
			              joinStr!("\n\t", staticMap!(stringOfFun, perfect_match)));
			return perfect_match[0](args);
		} else {
			import std.algorithm : map;
			import std.string : join;
			import std.array : array;
			import std.conv : to;
			alias cand =
			    filterOverloads!(isCompatible, _types!T, overloads);
			static assert(cand.length != 0, "No suitable overload found for argument type: "~T.stringof~
			              "\nCandidates are: \n\t"~joinStr!("\n\t", staticMap!(stringOfFun, overloads)));
			TypeInfo_Class[T.length] ti;
			static foreach(i; 0..T.length)
				static if (is(T[i] == class))
					ti[i] = typeid(args[i]);
				else static if (is(T[i] == interface))
					ti[i] = typeid(cast(Object)args[i]);
			oloop:foreach(o; cand) {
				alias p = Parameters!o;
				static foreach(i; 0..T.length) {
					static if (is(p[i] == class))
						if (ti[i] != typeid(p[i]))
							continue oloop;
				}

				p args2;
				static foreach(i; 0..T.length) {
					static if (!is(p[i] == T[i])) {
						args2[i] = cast(p[i])args[i];
						static if (isIClass!(p[i]))
							assert(args2[i] !is null);
					}
				}

				mixin(genCall!(p, T));
			}
			throw new OverloadNotFoundException("no suitable overload of function `"~fullyQualifiedName!func~"', "~
			       "argument types: "~ti[].map!((a) => a.toString).join(", ").array.to!string);
		}
	}
}
unittest {
	class A {}
	class B : A {}
	class C : A {}
	struct c {
		static int a(A x){ assert(false); }
		static int a(B x){ return 1; }
		static int a(C x){ return 2; }
	}
	import std.stdio;
	import std.traits;
	pragma(msg, fullyQualifiedName!A);
	writeln(typeid(A).name);
	A tmp = new B();
	alias overloaded_a = multiDispatch!(c.a);
	assert(overloaded_a(tmp) == 1);
	tmp = new C();
	assert(overloaded_a(tmp) == 2);
}
