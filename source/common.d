module common;
import type;
import sdpc : PositionRangeNonWhite;
public import sdpc : Span;
alias InputType = PositionRangeNonWhite!string;

class AstNode {
	override string toString() const {
		return "astnode";
	}
}

class Expr : AstNode {
	Type type = null;
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

class SemanticError: Exception {
	Span x;
	this(string err, Span x=Span.init, string file=__FILE__, int line=__LINE__) {
		super(err, file, line);
		this.x = x;
	}
}
