module ir.validater;

// Things to validate:
// SSA
// Assigned before use
// Writability -> Liveness analysis, only one writable ref Var alive at the same time
