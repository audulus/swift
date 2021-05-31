// RUN: %target-typecheck-verify-swift

@realtime func foo() { }

struct Foo {
	@realtime func foo() { }
}

@realtime // expected-error {{@realtime may only be used on 'func' declarations}}
struct Bar { }