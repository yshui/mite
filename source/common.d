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

class Expr: AstNode { }
