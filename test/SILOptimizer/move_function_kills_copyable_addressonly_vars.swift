// RUN: %target-swift-frontend -enable-experimental-move-only -verify %s -parse-stdlib -emit-sil -o /dev/null

import Swift

//////////////////
// Declarations //
//////////////////

public class Klass {
    public func getOtherKlass() -> Klass? { return nil }
}

struct KlassWrapper {
    var k: Klass
}

func consumingUse<T>(_ k: __owned T) {}
var booleanValue: Bool { false }
func nonConsumingUse<T>(_ k: T) {}
func exchangeUse<T>(_ k: __owned T) -> T { k }

public protocol P {
    var k: Klass { get }

    static func getP() -> Self

    func doSomething()
}

public protocol SubP1 : P {}
public protocol SubP2 : P {}

///////////
// Tests //
///////////

public func performMoveOnVarSingleBlock<T>(_ p: T) {
    var x = p
    let _ = _move x
    x = p
    nonConsumingUse(x)
}

public func performMoveOnVarSingleBlockError<T>(_ p: T) {
    var x = p // expected-error {{'x' used after being moved}}
    let _ = _move x // expected-note {{move here}}
    nonConsumingUse(x) // expected-note {{use here}}
    x = p
    nonConsumingUse(x)
}

public func performMoveOnVarMultiBlock<T>(_ p: T) {
    var x = p
    let _ = _move x

    while booleanValue {
        print("true")
    }

    while booleanValue {
        print("true")
    }

    x = p
    nonConsumingUse(x)
}

public func performMoveOnVarMultiBlockError1<T>(_ p: T) {
    var x = p // expected-error {{'x' used after being moved}}
    let _ = _move x // expected-note {{move here}}

    nonConsumingUse(x) // expected-note {{use here}}

    while booleanValue {
        print("true")
    }

    // We only emit an error on the first one.
    nonConsumingUse(x)

    while booleanValue {
        print("true")
    }

    // We only emit an error on the first one.
    nonConsumingUse(x)

    x = p
    nonConsumingUse(x)
}

public func performMoveOnVarMultiBlockError2<T>(_ p: T) {
    var x = p // expected-error {{'x' used after being moved}}
    let _ = _move x // expected-note {{move here}}

    while booleanValue {
        print("true")
    }

    nonConsumingUse(x) // expected-note {{use here}}

    while booleanValue {
        print("true")
    }

    // We only error on the first one.
    nonConsumingUse(x)

    x = p
    nonConsumingUse(x)
}

public func performMoveOnInOut<T>(_ p: inout T) { // expected-error {{'p' used after being moved}}
    let buf = _move p // expected-note {{move here}}
    let _ = buf
} // expected-note {{use here}}

public func performMoveOnInOut2<T>(_ p: inout T, _ p2: T) {
    let buf = _move p
    let _ = buf
    p = p2
}

struct S<T> {
    var buffer: T?

    mutating func appendNoError() {
        let b = (_move self).buffer
        let maybeNewB = exchangeUse(b)
        self = .init(buffer: maybeNewB)
    }

    mutating func appendError() { // expected-error {{'self' used after being moved}}
        let b = (_move self).buffer // expected-note {{move here}}
        let _ = b
    } // expected-note {{use here}}

    mutating func appendThrowingNoError1(_ f: () throws -> ()) throws {
        let b = (_move self).buffer
        let maybeNewB = exchangeUse(b)
        // We have to initialize self before we call try since otherwise we will
        // not initialize self along the throws path.
        self = .init(buffer: maybeNewB)
        try f()
    }

    mutating func appendThrowingNoError2(_ f: () throws -> ()) {
        do {
            let b = (_move self).buffer
            try f()
            let maybeNewB = exchangeUse(b)
            self = .init(buffer: maybeNewB)
        } catch {
            self = .init(buffer: nil)
        }
    }

    // In this case, since we initialize self before the try point, we will have
    // re-initialized self before hitting either the code after the try that is
    // inline or the catch block.
    mutating func appendThrowingNoError3(_ f: () throws -> ()) {
        do {
            let b = (_move self).buffer
            let maybeNewB = exchangeUse(b)
            self = .init(buffer: maybeNewB)
            try f()
        } catch {
        }
    }

    mutating func appendThrowingError0(_ f: () throws -> ()) throws { // expected-error {{'self' used after being moved}}
        let b = (_move self).buffer // expected-note {{move here}}
        let maybeNewB = exchangeUse(b)
        try f() // expected-note {{use here}}
        self = .init(buffer: maybeNewB)
    }


    mutating func appendThrowingError1(_ f: () throws -> ()) throws { // expected-error {{'self' used after being moved}}
        let b = (_move self).buffer // expected-note {{move here}}
        let maybeNewB = exchangeUse(b)
        let _ = maybeNewB
        try f() // expected-note {{use here}}
    }

    mutating func appendThrowingError2(_ f: () throws -> ()) { // expected-error {{'self' used after being moved}}
        do {
            let b = (_move self).buffer // expected-note {{move here}}
            let _ = b
            try f()
        } catch {
            self = .init(buffer: nil)
        }
    } // expected-note {{use here}}

    mutating func appendThrowingError3(_ f: () throws -> ()) { // expected-error {{'self' used after being moved}}
        do {
            let b = (_move self).buffer // expected-note {{move here}}
            try f()
            let maybeNewB = exchangeUse(b)
            self = .init(buffer: maybeNewB)
        } catch {
        }
    } // expected-note {{use here}}

    mutating func appendThrowingError4(_ f: () throws -> ()) { // expected-error {{'self' used after being moved}}
        do {
            let b = (_move self).buffer // expected-note {{move here}}
            let _ = b
            try f()
        } catch {
        }
    } // expected-note {{use here}}
}

/////////////////
// Defer Tests //
/////////////////

protocol DeferTestProtocol : P {
}

extension DeferTestProtocol {
    mutating func deferTestSuccess1() {
        let selfType = type(of: self)
        let _ = (_move self)
        defer {
            self = selfType.getP()
        }
        print("123")
    }

    // Make sure we can init/reinit self multiple times without error.
    mutating func deferTestSuccess2() {
        let selfType = type(of: self)
        let _ = (_move self)
        self = selfType.getP()
        let _ = (_move self)
        defer {
            self = selfType.getP()
        }
        print("123")
    }

    mutating func deferTestSuccess3() {
        let selfType = type(of: self)
        let _ = (_move self)
        defer {
            self = selfType.getP()
        }
        defer {
            self = selfType.getP()
        }
        print("123")
    }

    // We do not support moving within a defer right now.
    mutating func deferTestFail1() {
        let selfType = type(of: self)
        let _ = (_move self)
        defer {
            self = selfType.getP()
            let _ = (_move self) // expected-error {{_move applied to value that the compiler does not support checking}}
        }
        print("123")
    }

    // We do not support moving within a defer right now.
    mutating func deferTestFail2() { // expected-error {{'self' used after being moved}}
        let selfType = type(of: self)
        let _ = (_move self) // expected-note {{move here}}
        defer {
            nonConsumingUse(k) // expected-note {{use here}}
            self = selfType.getP()
        }
        print("123")
    }


    mutating func deferTestFail3() { // expected-error {{'self' used after being moved}}
        let selfType = type(of: self)
        let _ = (_move self) // expected-note {{move here}}
        nonConsumingUse(k) // expected-note {{use here}}
        defer {
            nonConsumingUse(k)
            self = selfType.getP()
        }
        print("123")
    }

    mutating func deferTestFail4() { // expected-error {{'self' used after being moved}}
        let selfType = type(of: self)
        let _ = (_move self) // expected-note {{move here}}
        defer {
            consumingUse(k) // expected-note {{use here}}
            self = selfType.getP()
        }
        print("123")
    }

    // TODO: We should definitely be erroring on consuming use I think.
    mutating func deferTestFail5() { // expected-error {{'self' used after being moved}}
        let selfType = type(of: self)
        let _ = (_move self) // expected-note {{move here}}
        for _ in 0..<1024 {
            defer {
                consumingUse(k)
                self = selfType.getP()
            }
            print("foo bar")
        }
        print("123")
    }  // expected-note {{use here}}

    // TODO: We should be erroring on nonConsumingUse rather than the end of
    // scope use.
    //
    mutating func deferTestFail6() { // expected-error {{'self' used after being moved}}
        let selfType = type(of: self)
        let _ = (_move self) // expected-note {{move here}}
        for _ in 0..<1024 {
            defer {
                nonConsumingUse(k)
                self = selfType.getP()
            }
            print("foo bar")
        }
        print("123")
    }  // expected-note {{use here}}

    mutating func deferTestFail7() { // expected-error {{'self' used after being moved}}
        let selfType = type(of: self)
        for _ in 0..<1024 {
            let _ = (_move self) // expected-note {{move here}}
            defer {
                nonConsumingUse(k) // expected-note {{use here}}
                self = selfType.getP()
            }
            print("foo bar")
        }
        print("123")
    }

    mutating func deferTestFail8() { // expected-error {{'self' used after being moved}}
        let selfType = type(of: self)
        let _ = (_move self) // expected-note {{move here}}
        defer {
            if booleanValue {
                nonConsumingUse(k) // expected-note {{use here}}
            }
            self = selfType.getP()
        }
        print("foo bar")
    }

    mutating func deferTestFail9() { // expected-error {{'self' used after being moved}}
        let selfType = type(of: self)
        let _ = (_move self) // expected-note {{move here}}
        defer {
            if booleanValue {
                nonConsumingUse(k) // expected-note {{use here}}
            } else {
                nonConsumingUse(k)
            }
            self = selfType.getP()
        }
        print("foo bar")
    }

    mutating func deferTestFail10() { // expected-error {{'self' used after being moved}}
        let selfType = type(of: self)
        let _ = (_move self) // expected-note {{move here}}
        defer {
            for _ in 0..<1024 {
                nonConsumingUse(k) // expected-note {{use here}}
            }
            self = selfType.getP()
        }
        print("foo bar")
    }

    mutating func deferTestFail11() { // expected-error {{'self' used after being moved}}
        let selfType = type(of: self)
        let _ = (_move self) // expected-note {{move here}}
        if booleanValue {
            print("creating blocks")
        } else {
            print("creating blocks2")
        }
        defer {
            for _ in 0..<1024 {
                nonConsumingUse(k) // expected-note {{use here}}
            }
            self = selfType.getP()
        }
        print("foo bar")
    }

    mutating func deferTestFail12() { // expected-error {{'self' used after being moved}}
        let selfType = type(of: self)
        if booleanValue {
            print("creating blocks")
        } else {
            let _ = (_move self) // expected-note {{move here}}
            print("creating blocks2")
        }

        defer {
            for _ in 0..<1024 {
                nonConsumingUse(k) // expected-note {{use here}}
            }
            self = selfType.getP()
        }
        print("foo bar")
    }

    mutating func deferTestSuccess13() {
        let selfType = type(of: self)
        if booleanValue {
            print("creating blocks")
        } else {
            let _ = (_move self)
            print("creating blocks2")
        }

        defer {
            self = selfType.getP()
        }
        print("foo bar")
    }

    mutating func deferTestSuccess14() {
        let selfType = type(of: self)
        if booleanValue {
            print("creating blocks")
            self.doSomething()
        } else {
            let _ = (_move self)
            print("creating blocks2")
        }

        defer {
            self = selfType.getP()
        }
        print("foo bar")
    }
}

////////////////
// Cast Tests //
////////////////

public func castTest0<T : SubP1>(_ x: __owned T) -> P {
    var x2 = x  // expected-error {{'x2' used after being moved}}
    x2 = x
    let _ = _move x2 // expected-note {{move here}}
    return x2 as P // expected-note {{use here}}
}

public func castTest1<T : P>(_ x: __owned T) -> SubP1 {
    var x2 = x  // expected-error {{'x2' used after being moved}}
    x2 = x
    let _ = _move x2 // expected-note {{move here}}
    return x2 as! SubP1 // expected-note {{use here}}
}

public func castTest2<T : P>(_ x: __owned T) -> SubP1? {
    var x2 = x // expected-error {{'x2' used after being moved}}
    x2 = x
    let _ = _move x2 // expected-note {{move here}}
    return x2 as? SubP1 // expected-note {{use here}}
}

public func castTestSwitch1<T : P>(_ x : __owned T) {
    var x2 = x // expected-error {{'x2' used after being moved}}
    x2 = x
    let _ = _move x2 // expected-note {{move here}}
    switch x2 {  // expected-note {{use here}}
    case let k as SubP1:
        print(k)
    default:
        print("Nope")
    }
}

public func castTestSwitch2<T : P>(_ x : __owned T) {
    var x2 = x // expected-error {{'x2' used after being moved}}
    x2 = x
    let _ = _move x2 // expected-note {{move here}}
    switch x2 { // expected-note {{use here}}
    case let k as SubP1:
        print(k)
    case let k as SubP2:
        print(k)
    default:
        print("Nope")
    }
}

public func castTestSwitchInLoop<T : P>(_ x : __owned T) {
    var x2 = x // expected-error {{'x2' used after being moved}}
    x2 = x
    let _ = _move x2 // expected-note {{move here}}

    for _ in 0..<1024 {
        switch x2 { // expected-note {{use here}}
        case let k as SubP1:
            print(k)
        default:
            print("Nope")
        }
    }
}

public func castTestIfLet<T : P>(_ x : __owned T) {
    var x2 = x // expected-error {{'x2' used after being moved}}
    x2 = x
    let _ = _move x2 // expected-note {{move here}}
    if case let k as SubP1 = x2 { // expected-note {{use here}}
        print(k)
    } else {
        print("no")
    }
}

public func castTestIfLetInLoop<T : P>(_ x : __owned T) {
    var x2 = x // expected-error {{'x2' used after being moved}}
    x2 = x
    let _ = _move x2 // expected-note {{move here}}
    for _ in 0..<1024 {
        if case let k as SubP1 = x2 { // expected-note {{use here}}
            print(k)
        } else {
            print("no")
        }
    }
}

public enum EnumWithP<T> {
    case none
    case klass(T)
}

public func castTestIfLet2<T : P>(_ x : __owned EnumWithP<T>) {
    var x2 = x // expected-error {{'x2' used after being moved}}
    x2 = x
    let _ = _move x2 // expected-note {{move here}}
    if case let .klass(k as SubP1) = x2 { // expected-note {{use here}}
        print(k)
    } else {
        print("no")
    }
}

///////////////
// GEP Tests //
///////////////

public func castAccess<T : P>(_ x : __owned T) {
    var x2 = x // expected-error {{'x2' used after being moved}}
    x2 = x
    let _ = _move x2 // expected-note {{move here}}
    let _ = x2.k // expected-note {{use here}}
}

public func castAccess2<T : P>(_ x : __owned T) {
    var x2 = x // expected-error {{'x2' used after being moved}}
    x2 = x
    let _ = _move x2 // expected-note {{move here}}
    let _ = x2.k.getOtherKlass() // expected-note {{use here}}
}

/////////////////////////
// Partial Apply Tests //
/////////////////////////

// This makes sure we always fail if we are asked to check in a partial apply.
public func partialApplyTest<T : P>(_ x: __owned T) {
    var x2 = x
    x2 = x
    let _ = _move x2 // expected-error {{move applied to value that the compiler does not support checking}}
    let f = {
        print(x2)
    }
    f()
}

////////////////////////
// Misc Tests on Self //
////////////////////////

protocol MiscTests : P {}

extension MiscTests {

    // This test makes sure that we are able to properly put in the destroy_addr
    // in the "creating blocks" branch. There used to be a bug where the impl
    // would need at least one destroy_addr to properly infer the value to put
    // into blocks not reachable from the _move but that are on the dominance
    // frontier from the _move. This was unnecessary and the test makes sure we
    // do not fail on this again.
    mutating func noDestroyAddrBeforeOptInsertAfter() {
        let selfType = type(of: self)
        if booleanValue {
            print("creating blocks")
        } else {
            let _ = (_move self)
            print("creating blocks2")
        }

        self = selfType.getP()
        print("foo bar")
    }

    // A derived version of noDestroyAddrBeforeOptInsertAfter that makes sure
    // when we insert the destroy_addr, we destroy self at the end of the block.
    mutating func noDestroyAddrBeforeOptInsertAfter2() {
        let selfType = type(of: self)
        if booleanValue {
            print("creating blocks")
            self.doSomething()
        } else {
            let _ = (_move self)
            print("creating blocks2")
        }

        self = selfType.getP()
        print("foo bar")
    }
}

//////////////////////////////////
// Multiple Captures from Defer //
//////////////////////////////////

func multipleCapture1<T : P>(_ k: T) -> () {
    let kType = type(of: k)
    var k2 = k
    var k3 = k
    let _ = _move k2
    let _ = _move k3
    var k4 = k
    k4 = k
    defer {
        k2 = kType.getP()
        print(k4)
        k3 = kType.getP()
    }
    print("foo bar")
}

func multipleCapture2<T : P>(_ k: T) -> () {
    let kType = type(of: k)
    var k2 = k // expected-error {{'k2' used after being moved}}
    k2 = k
    var k3 = k
    let _ = _move k2 // expected-note {{move here}}
    let _ = _move k3
    var k4 = k
    k4 = k
    defer {
        print(k2) // expected-note {{use here}}
        print(k4)
        k3 = kType.getP()
    }
    print("foo bar")
}

//////////////////////
// Reinit in pieces //
//////////////////////

// These tests exercise the diagnostic to see how we error if we re-initialize a
// var in pieces. Eventually we should teach either this diagnostic pass how to
// handle this or teach DI how to combine the initializations into one large
// reinit.
struct ProtPair<T : P> {
    var lhs: T
    var rhs: T
}

func reinitInPieces1<T : P>(_ k: ProtPair<T>) {
    let selfType = type(of: k.lhs)
    var k2 = k
    k2 = k

    let _ = _move k2 // expected-error {{_move applied to value that the compiler does not support checking}}
    k2.lhs = selfType.getP()
    k2.rhs = selfType.getP()
}
