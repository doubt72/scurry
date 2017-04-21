//
//  evaluator.swift
//  scurry
//
//  Created by Douglas Triggs on 4/20/17.
//  Copyright © 2017 Douglas Triggs. All rights reserved.
//

import Foundation

// Evaluate parsed stuff

struct Scope {
    var bindings: [String: Function]
    var param: ListEval
}

enum Evaluation {
    case True, False, Integer(Int64), Float(Double), String(String), List(ListEval)
    case Function(Function), Exception(Exception)
}

extension Evaluation {
    var to_string: String {
        get {
            switch self {
            case .True:
                return "true"
            case .False:
                return "false"
            case .Integer(let n):
                return "\(n)"
            case .Float(let n):
                return "\(n)"
            case .String(let s):
                return s
            case .List(let l):
                return l.to_string
            case .Function(let f):
                return f.to_string
            case .Exception(let e):
                return e.to_string
            }
        }
    }
    
    var copy: Evaluation {
        get {
            switch self {
            case .True:
                return .True
            case .False:
                return .False
            case .Integer(let n):
                return .Integer(n)
            case .Float(let n):
                return .Float(n)
            case .String(let s):
                return .String(s)
            case .List(let l):
                return .List(l.copy)
            case .Function(let f):
                return .Function(f.copy)
            case .Exception(let e):
                return .Exception(e.copy)
            }
        }
    }
}

class ListEval {
    private var head: Evaluation?
    private var tail: ListEval?
    
    init(_ head: Evaluation?) {
        self.head = head
        self.tail = nil
    }
    
    public func set(_ head: Evaluation) {
        self.head = head
    }
    
    public func append(_ tail: ListEval) {
        self.tail = tail
    }
    
    var to_string: String {
        get {
            let l = self.string_accum()
            return "[" + l.joined(separator: " ") + "]"
        }
    }
    
    private func string_accum() -> [String] {
        if self.head == nil {
            return []
        } else {
            return [self.head!.to_string] + self.tail!.string_accum()
        }
    }
    
    public var length: Int {
        get {
            if self.head == nil {
                return 0
            } else {
                return 1 + self.tail!.length
            }
        }
    }
    
    public var car: Evaluation? {
        get {
            return self.head
        }
    }
    
    public var cadr: Evaluation? {
        get {
            return self.tail?.head
        }
    }
    
    public var caddr: Evaluation? {
        get {
            return self.tail?.tail?.head
        }
    }
    
    public var next: ListEval? {
        get {
            return self.tail
        }
    }
    
    public var copy: ListEval {
        if self.head != nil {
            let rc = ListEval(self.head!.copy)
            rc.append(self.tail!.copy)
            return rc
        } else {
            return ListEval(nil)
        }
    }
}

struct Function {
    var block: Block
}

extension Function {
    var to_string: String {
        get {
            return "<function>"
        }
    }
    
    var copy: Function {
        get {
            // We don't really care if this is the same data, it can't
            // be redifined anyway
            return Function(block: self.block)
        }
    }
}

class Exception {
    var flavor: ExceptionType
    var payload: Evaluation
    var stack: [String]
    
    init(flavor: ExceptionType, payload: Evaluation) {
        self.flavor = flavor
        self.payload = payload
        self.stack = []
    }
    
    var to_list: ListEval {
        get {
            let rcs = ListEval(nil);
            var current = rcs
            for s in self.stack {
                current.set(.String(s))
                current.append(ListEval(nil))
                current = current.next!
            }
            
            let rc = ListEval(.String(self.flavor.to_string))
            rc.append(ListEval(self.payload))
            rc.next!.append(ListEval(.List(rcs)))
            rc.next!.next!.append(ListEval(nil))
            return rc
        }
    }
    
    var to_string: String {
        get {
            return self.to_list.to_string
        }
    }
    
    var copy: Exception {
        get {
            // We don't really care if this is the same data, in practical
            // terms this can't happen, so not bothering to copy the stack
            return Exception(flavor: self.flavor, payload: payload.copy)
        }
    }
}

enum ExceptionType {
    case Return, Error, ArgError, ParseError, TypeError, TypeMismatch, DivByZero
    case RuntimeError, UndefError, RedefError
}

extension ExceptionType {
    var to_string: String {
        switch self {
        case .Return:
            return "return"
        case .Error:
            return "error"
        case .ArgError:
            return "parameter length"
        case .ParseError:
            return "parse error"
        case .TypeError:
            return "type error"
        case .TypeMismatch:
            return "type mismatch"
        case .DivByZero:
            return "division by zero"
        case .RuntimeError:
            return "runtime error"
        case .UndefError:
            return "undefined function"
        case .RedefError:
            return "redefinition error"
        }
    }
}

extension SList {
    func evaluate(scope: inout [Scope]) -> ListEval {
        if self.car != nil {
            let rc = ListEval(self.car!.evaluate(scope: &scope))
            rc.append(self.next!.evaluate(scope: &scope))
            return rc
        } else {
            return ListEval(nil)
        }
    }
}

extension Call {
    func evaluate(scope: inout [Scope]) -> Evaluation {
        for s in scope.reversed() {
            if s.bindings.keys.contains(self.id) {
                let binding = s.bindings[self.id]
                let eval = self.param.evaluate(scope: &scope)
                return binding!.block.evaluate(scope: &scope, param: eval, context: self.id)
            }
        }
        if self.id == "," {
            if self.param.length < 2 {
                return make_exception(flavor: .ArgError, id: self.id,
                                      msg: "expected argument list of length 2 but got \(self.param.length)")
            }
            let eval = self.param.car!.evaluate(scope: &scope)
            switch eval {
            case .Exception(_):
                return eval
            case .Function(let f):
                let p = self.param.cadr!
                switch p {
                case .List(let l):
                    let elist = l.evaluate(scope: &scope)
                    return f.block.evaluate(scope: &scope, param: elist, context: self.id)
                default:
                    return make_exception(flavor: .TypeError, id: self.id,
                                          msg: "list expected as second argument")
                }
            default:
                return make_exception(flavor: .TypeError, id: self.id,
                                      msg: "function expected as first argument")
            }
        } else {
            let first = self.id.characters.first
            if first != nil && first! == "_" {
                // Parametric functions
                var depth = 0
                for c in self.id.characters {
                    if c == "_" {
                        depth += 1
                    } else {
                        return make_exception(flavor: .UndefError, id: self.id,
                                              msg: "function \(self.id) is not defined in scope")
                    }
                }
                if depth > scope.count {
                    return make_exception(flavor: .UndefError, id: self.id,
                                          msg: "attempt to reach out of main scope with _*")
                }
                let param = scope[scope.count - depth].param;
                return Evaluation.List(param)
            } else {
                return system_functions(id: self.id, param: param.evaluate(scope: &scope))
            }
        }
    }
}

extension Definition {
    func evaluate(scope: inout [Scope]) -> Evaluation {
        var last = scope.last;
        if last != nil {
            if (last!.bindings.keys.contains(self.id)) {
                return make_exception(flavor: .RedefError, id: "",
                                      msg: "attempt to redefine \(self.id)")
            }
            let f = Function(block: self.block)
            last!.bindings[self.id] = f
            scope[scope.count - 1] = last!
            return Evaluation.Function(f)
        } else {
            print("internal error: no scope supplied to definition evaluation")
            exit(1)
        }
    }
}

extension Expression {
    func evaluate(scope: inout [Scope]) -> Evaluation {
        switch self {
        case .True:
            return .True
        case .False:
            return .False
        case .Integer(let n):
            return .Integer(n)
        case .Float(let n):
            return .Float(n)
        case .String(let s):
            return .String(s)
        case .List(let l):
            return .List(l.evaluate(scope: &scope))
        case .Call(let c):
            return c.evaluate(scope: &scope)
        case .Definition(let d):
            return d.evaluate(scope: &scope)
        }
    }
}

extension Block {
    func evaluate(scope: inout [Scope], param: ListEval, context: String) -> Evaluation {
        let current = Scope(bindings: [:], param: param)
        scope.append(current)
        
        // Evaluate
        var value = Evaluation.False
        for exp in self.expressions {
            let eval = exp.evaluate(scope: &scope)
            switch eval {
            case .Exception(let e):
                scope.removeLast()
                switch e.flavor {
                case .Return:
                    return e.payload
                default:
                    e.stack.append(context);
                    return .Exception(e)
                }
            default:
                value = eval
            }
        }
        scope.removeLast()
        return value
    }
}

func make_exception(flavor: ExceptionType, id: String, msg: String) -> Evaluation {
    return .Exception(Exception(flavor: flavor,
                                payload: .String("\(id) : \(msg)")))
}

func evaluate(block: Block) {
    var scope: [Scope] = [];
    let result = block.evaluate(scope: &scope, param: ListEval(nil), context: "[main program]")
    switch result {
    case .Exception(let e):
        var s = "\nRUNTIME EXCEPTION: \(e.flavor.to_string)\n" +
            "\(e.payload.to_string):\n\n  calling context:\n"
        var index = e.stack.count
        for i in e.stack {
            s += "   -- called from function \(index - 1): \(i)\n"
            index -= 1
        }
        print(s)
        exit(1)
    default: ()
        // no errors, do nothing
    }
}
