module md;

class OverloadNotFoundException : Exception {
	this(string err, string file=__FILE__, int line=__LINE__) {
		super(err, file, line);
	}
}

template multiDispatch(alias func) {
	import std.traits;
	import std.meta;
	struct _types(T...) {}
	bool doesArgsMatch(alias F, T...)() {
		bool ret = true;
		alias p = Parameters!F;
		static if (p.length != T.length)
			ret = false;
		else {
			foreach(id, FT; Parameters!F)
				static if (!is(FT: T[id]))
					ret = false;
		}
		return ret;
	}
	/// filter overloads according to argument types
	template filterOverloads(T, Funs...) {
		static if (is(T == _types!Ts, Ts...)) {
			static if (Funs.length == 1) {
				static if (doesArgsMatch!(Funs[0], Ts))
					alias filterOverloads = Funs;
				else
					alias filterOverloads = AliasSeq!();
			} else
				alias filterOverloads = AliasSeq!(filterOverloads!(T, Funs[0..$/2]), filterOverloads!(T, Funs[$/2..$]));
		} else
			static assert(false);
	}
	template isIClass(T) {
		enum isIClass = is(T == class) || is(T == interface);
	}
	auto multiDispatch(T...)(T args) {
		import std.algorithm : map;
		import std.string : join;
		import std.array : array;
		import std.conv : to;
		alias ovrld =
		    filterOverloads!(_types!T, __traits(getOverloads, __traits(parent, func), __traits(identifier, func)));
		static assert(ovrld.length != 0, "No suitable overload found for argument type: "~T.stringof);
		TypeInfo[T.length] ti;
		static foreach(i; 0..T.length)
			static if (isIClass!(T[i]))
				ti[i] = typeid(args[i]);
		oloop:foreach(o; ovrld) {
			alias p = Parameters!o;
			static foreach(i; 0..T.length) {
				static if (isIClass!(T[i]))
					if (ti[i] != typeid(p[i]))
						continue oloop;
			}
			p args2;
			static foreach(i; 0..T.length) {
				args2[i] = cast(p[i])args[i];
				assert(args2[i] !is null);
			}
			return o(args2);
		}

		throw new OverloadNotFoundException("no suitable overload of function `"~fullyQualifiedName!func~"', "~
		       "argument types: "~ti[].map!((a) => a.toString).join(", ").array.to!string);
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
