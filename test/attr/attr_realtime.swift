// RUN: %target-typecheck-verify-swift

@realtime func foo() { }

struct Foo {
	@realtime func foo() { }
}