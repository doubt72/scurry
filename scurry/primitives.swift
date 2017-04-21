//
//  primitives.swift
//  scurry
//
//  Created by Douglas Triggs on 4/20/17.
//  Copyright © 2017 Douglas Triggs. All rights reserved.
//

import Foundation

func expect_args(count: Int, param: ListEval, id: String) -> Evaluation? {
    if count != param.length {
        return make_exception(flavor: .ArgError, id: id,
                              msg: "expected argument list of length \(count) but got \(param.length)")
    } else {
        return nil
    }
}

class SystemFunction {
    var id = ""
    
    public func call(param: ListEval) -> Evaluation {
        print("oops, subclass didn't override call")
        exit(1)
    }
}

class Primitives {
    static var functions: [String: SystemFunction] = [:]
    static var arity: [String: Int] = [:]
    static var done = false
    
    static func populate() {
        if (done == false) {
            self.add(id: "int", function: PFInt(), arity: 1)
            self.add(id: "float", function: PFFloat(), arity: 1)
            self.add(id: "string", function: PFString(), arity: 1)
            self.add(id: ">>", function: PFOut(), arity: 1)
            self.add(id: "+", function: PFPlus(), arity: 2)
            self.add(id: "-", function: PFMinus(), arity: 2)
            self.add(id: "*", function: PFMult(), arity: 2)
            self.add(id: "/", function: PFDiv(), arity: 2)
            self.add(id: "%", function: PFMod(), arity: 2)
            self.add(id: "!", function: PFNot(), arity: 1)
            self.add(id: "&", function: PFAnd(), arity: 2)
            self.add(id: "|", function: PFOr(), arity: 2)
            self.add(id: "?", function: PFTrinary(), arity: 3)
            self.add(id: "=", function: PFEqual(), arity: 2)
            self.add(id: ">", function: PFGreater(), arity: 2)
            self.add(id: "<", function: PFLess(), arity: 2)
            self.add(id: "substr", function: PFSubstr(), arity: 3)
            self.add(id: "strlen", function: PFStrlen(), arity: 1)
            self.add(id: "car", function: PFCar(), arity: 1)
            self.add(id: "cdr", function: PFCdr(), arity: 1)
            self.add(id: "catch", function: PFCatch(), arity: 1)
            self.add(id: "raise", function: PFRaise(), arity: 1)
            self.add(id: "~", function: PFReturn(), arity: 1)
            done = true
        }
    }
    
    static public func add(id: String, function f: SystemFunction, arity a: Int) {
        f.id = id
        functions[id] = f
        arity[id] = a
    }
}


func system_functions(id: String, param: ListEval) -> Evaluation {
    Primitives.populate()
    
    if id != "?" && id != "catch" {
        // All functions other than these pass exceptions through
        var current = param
        while current.car != nil {
            switch current.car! {
            case .Exception(_):
                return current.car!
            default: ()
                // not an exception; move along
            }
            current = current.next!
        }
    }

    if Primitives.functions.keys.contains(id) {
        let check = expect_args(count: Primitives.arity[id]!, param: param, id: id)
        if check == nil {
            return Primitives.functions[id]!.call(param: param)
        } else {
            return check!
        }
    } else {
        return make_exception(flavor: .UndefError, id: id,
                              msg: "function is not defined in scope")
    }
}

// Primitive functions:

class PFInt: SystemFunction {
    public override func call(param: ListEval) -> Evaluation {
        switch param.car! {
        case .Float(let n):
            return .Integer(Int64(n))
        case .String(let s):
            let rc = Int64(s)
            if rc == nil {
                return make_exception(flavor: .ParseError, id: self.id,
                                      msg: "unable to parse string \(s)")
            } else {
                return .Integer(rc!)
            }
        default:
            return make_exception(flavor: .TypeError, id: self.id,
                                  msg: "float or string argument expected")
        }
    }
}

class PFFloat: SystemFunction {
    public override func call(param: ListEval) -> Evaluation {
        switch param.car! {
        case .Integer(let n):
            return .Float(Double(n))
        case .String(let s):
            let rc = Double(s)
            if rc == nil {
                return make_exception(flavor: .ParseError, id: self.id,
                                      msg: "unable to parse string \(s)")
            } else {
                return .Float(rc!)
            }
        default:
            return make_exception(flavor: .TypeError, id: self.id,
                                  msg: "float or string argument expected")
        }
    }
}

class PFString: SystemFunction {
    public override func call(param: ListEval) -> Evaluation {
        return .String(param.car!.to_string)
    }
}

class PFOut: SystemFunction {
    public override func call(param: ListEval) -> Evaluation {
        switch param.car! {
        case .String(let s):
            print(s)
            return .True
        default:
            return make_exception(flavor: .TypeError, id: self.id,
                                  msg: "string argument expected")
        }
    }
}

class PFPlus: SystemFunction {
    public override func call(param: ListEval) -> Evaluation {
        switch param.car! {
        case .Integer(let x):
            switch param.cadr! {
            case .Integer(let y):
                return .Integer(x + y)
            case .Float(let y):
                return .Float(Double(x) + y)
            default:
                return make_exception(flavor: .TypeMismatch, id: self.id,
                                      msg: "mismatched argument types")
            }
        case .Float(let x):
            switch param.cadr! {
            case .Integer(let y):
                return .Float(x + Double(y))
            case .Float(let y):
                return .Float(x + y)
            default:
                return make_exception(flavor: .TypeMismatch, id: self.id,
                                      msg: "mismatched argument types")
            }
        case .List(let x):
            switch param.cadr! {
            case .List(let y):
                if x.car == nil {
                    return .List(y.copy)
                } else {
                    let rc = x.copy
                    var current = rc
                    while current.next!.car != nil {
                        current = current.next!
                    }
                    current.append(y.copy)
                    return .List(rc)
                }
            default:
                return make_exception(flavor: .TypeMismatch, id: self.id,
                                      msg: "mismatched argument types")
            }
        case .String(let x):
            switch param.cadr! {
            case .String(let y):
                return .String(x + y)
            default:
                return make_exception(flavor: .TypeMismatch, id: self.id,
                                      msg: "mismatched argument types")
            }
        default:
            return make_exception(flavor: .TypeError, id: self.id,
                                  msg: "number, list, or string arguments expected")
        }
    }
}

class PFMinus: SystemFunction {
    public override func call(param: ListEval) -> Evaluation {
        switch param.car! {
        case .Integer(let x):
            switch param.cadr! {
            case .Integer(let y):
                return .Integer(x - y)
            case .Float(let y):
                return .Float(Double(x) - y)
            default:
                return make_exception(flavor: .TypeMismatch, id: self.id,
                                      msg: "mismatched argument types")
            }
        case .Float(let x):
            switch param.cadr! {
            case .Integer(let y):
                return .Float(x - Double(y))
            case .Float(let y):
                return .Float(x - y)
            default:
                return make_exception(flavor: .TypeMismatch, id: self.id,
                                      msg: "mismatched argument types")
            }
        default:
            return make_exception(flavor: .TypeError, id: self.id,
                                  msg: "numeric arguments expected")
        }
    }
}

class PFMult: SystemFunction {
    public override func call(param: ListEval) -> Evaluation {
        switch param.car! {
        case .Integer(let x):
            switch param.cadr! {
            case .Integer(let y):
                return .Integer(x * y)
            case .Float(let y):
                return .Float(Double(x) * y)
            default:
                return make_exception(flavor: .TypeMismatch, id: self.id,
                                      msg: "mismatched argument types")
            }
        case .Float(let x):
            switch param.cadr! {
            case .Integer(let y):
                return .Float(x * Double(y))
            case .Float(let y):
                return .Float(x * y)
            default:
                return make_exception(flavor: .TypeMismatch, id: self.id,
                                      msg: "mismatched argument types")
            }
        default:
            return make_exception(flavor: .TypeError, id: self.id,
                                  msg: "numeric arguments expected")
        }
    }
}

class PFDiv: SystemFunction {
    public override func call(param: ListEval) -> Evaluation {
        switch param.car! {
        case .Integer(let x):
            switch param.cadr! {
            case .Integer(let y):
                if y == 0 {
                    return make_exception(flavor: .DivByZero, id: self.id,
                                          msg: "attempt to divide by zero")
                }
                return .Integer(x / y)
            case .Float(let y):
                if y == 0 {
                    return make_exception(flavor: .DivByZero, id: self.id,
                                          msg: "attempt to divide by zero")
                }
                return .Float(Double(x) / y)
            default:
                return make_exception(flavor: .TypeMismatch, id: self.id,
                                      msg: "mismatched argument types")
            }
        case .Float(let x):
            switch param.cadr! {
            case .Integer(let y):
                if y == 0 {
                    return make_exception(flavor: .DivByZero, id: self.id,
                                          msg: "attempt to divide by zero")
                }
                return .Float(x / Double(y))
            case .Float(let y):
                if y == 0 {
                    return make_exception(flavor: .DivByZero, id: self.id,
                                          msg: "attempt to divide by zero")
                }
                return .Float(x / y)
            default:
                return make_exception(flavor: .TypeMismatch, id: self.id,
                                      msg: "mismatched argument types")
            }
        default:
            return make_exception(flavor: .TypeError, id: self.id,
                                  msg: "numeric arguments expected")
        }
    }
}

class PFMod: SystemFunction {
    public override func call(param: ListEval) -> Evaluation {
        switch param.car! {
        case .Integer(let x):
            switch param.cadr! {
            case .Integer(let y):
                if y == 0 {
                    return make_exception(flavor: .DivByZero, id: self.id,
                                          msg: "attempt to divide by zero")
                }
                return .Integer(x % y)
            default:
                return make_exception(flavor: .TypeMismatch, id: self.id,
                                      msg: "integer arguments expected")
            }
        default:
            return make_exception(flavor: .TypeError, id: self.id,
                                  msg: "integer arguments expected")
        }
    }
}

class PFNot: SystemFunction {
    public override func call(param: ListEval) -> Evaluation {
        switch param.car! {
        case .True:
            return .False
        case .False:
            return .True
        default:
            return make_exception(flavor: .TypeError, id: self.id,
                                  msg: "boolean argument expected")
        }
    }
}

class PFAnd: SystemFunction {
    public override func call(param: ListEval) -> Evaluation {
        switch param.car! {
        case .True:
            switch param.cadr! {
            case .True:
                return .True
            case .False:
                return .False
            default:
                return make_exception(flavor: .TypeMismatch, id: self.id,
                                      msg: "mismatched argument types")
            }
        case .False:
            switch param.cadr! {
            case .True:
                return .False
            case .False:
                return .False
            default:
                return make_exception(flavor: .TypeMismatch, id: self.id,
                                      msg: "mismatched argument types")
            }
        default:
            return make_exception(flavor: .TypeError, id: self.id,
                                  msg: "boolean arguments expected")
        }
    }
}

class PFOr: SystemFunction {
    public override func call(param: ListEval) -> Evaluation {
        switch param.car! {
        case .True:
            switch param.cadr! {
            case .True:
                return .True
            case .False:
                return .True
            default:
                return make_exception(flavor: .TypeMismatch, id: self.id,
                                      msg: "mismatched argument types")
            }
        case .False:
            switch param.cadr! {
            case .True:
                return .True
            case .False:
                return .False
            default:
                return make_exception(flavor: .TypeMismatch, id: self.id,
                                      msg: "mismatched argument types")
            }
        default:
            return make_exception(flavor: .TypeError, id: self.id,
                                  msg: "boolean arguments expected")
        }
    }
}

class PFTrinary: SystemFunction {
    public override func call(param: ListEval) -> Evaluation {
        switch param.car! {
        case .True:
            return param.cadr!
        case .False:
            return param.caddr!
        case .Exception(_):
            return param.car!
        default:
            return make_exception(flavor: .TypeError, id: self.id,
                                  msg: "boolean arguments expected")
        }
    }
}

class PFEqual: SystemFunction {
    private func equal(_ a: Evaluation, _ b: Evaluation) -> Evaluation {
        switch a {
        case .True:
            switch b {
            case .True:
                return .True
            default:
                return .False
            }
        case .False:
            switch b {
            case .False:
                return .True
            default:
                return .False
            }
        case .Integer(let x):
            switch b {
            case .Integer(let y):
                if x == y {
                    return .True
                } else {
                    return .False
                }
            default:
                return .False
            }
        case .Float(let x):
            switch b {
            case .Float(let y):
                if x == y {
                    return .True
                } else {
                    return .False
                }
            default:
                return .False
            }
        case .String(let x):
            switch b {
            case .String(let y):
                if x == y {
                    return .True
                } else {
                    return .False
                }
            default:
                return .False
            }
        case .List(let x):
            switch b {
            case .List(let y):
                if x.length != y.length {
                    return .False
                }
                var currentx = x
                var currenty = y
                while currentx.car != nil {
                    switch self.equal(currentx.car!, currenty.car!) {
                    case .True: ()
                        // item is equal, still good here
                    default:
                        return .False
                    }
                    currentx = currentx.next!
                    currenty = currenty.next!
                }
                return .True
            default:
                return .False
            }
        default:
            return .False
        }
    }
    
    public override func call(param: ListEval) -> Evaluation {
        return self.equal(param.car!, param.cadr!)
    }
}

class PFGreater: SystemFunction {
    public override func call(param: ListEval) -> Evaluation {
        switch param.car! {
        case .Integer(let x):
            switch param.cadr! {
            case .Integer(let y):
                if x > y {
                    return .True
                } else {
                    return .False
                }
            case .Float(let y):
                if Double(x) > y {
                    return .True
                } else {
                    return .False
                }
            default:
                return make_exception(flavor: .TypeMismatch, id: self.id,
                                      msg: "numeric arguments expected")
            }
        case .Float(let x):
            switch param.cadr! {
            case .Integer(let y):
                if x > Double(y) {
                    return .True
                } else {
                    return .False
                }
            case .Float(let y):
                if x > y {
                    return .True
                } else {
                    return .False
                }
            default:
                return make_exception(flavor: .TypeMismatch, id: self.id,
                                      msg: "numeric arguments expected")
            }
        default:
            return make_exception(flavor: .TypeError, id: self.id,
                                  msg: "numeric arguments expected")
        }
    }
}

class PFLess: SystemFunction {
    public override func call(param: ListEval) -> Evaluation {
        switch param.car! {
        case .Integer(let x):
            switch param.cadr! {
            case .Integer(let y):
                if x < y {
                    return .True
                } else {
                    return .False
                }
            case .Float(let y):
                if Double(x) < y {
                    return .True
                } else {
                    return .False
                }
            default:
                return make_exception(flavor: .TypeMismatch, id: self.id,
                                      msg: "numeric arguments expected")
            }
        case .Float(let x):
            switch param.cadr! {
            case .Integer(let y):
                if x < Double(y) {
                    return .True
                } else {
                    return .False
                }
            case .Float(let y):
                if x < y {
                    return .True
                } else {
                    return .False
                }
            default:
                return make_exception(flavor: .TypeMismatch, id: self.id,
                                      msg: "numeric arguments expected")
            }
        default:
            return make_exception(flavor: .TypeError, id: self.id,
                                  msg: "numeric arguments expected")
        }
    }
}

class PFSubstr: SystemFunction {
    public override func call(param: ListEval) -> Evaluation {
        switch param.car! {
        case .String(let s):
            switch param.cadr! {
            case .Integer(let start):
                switch param.caddr! {
                case .Integer(let len):
                    if Int(start) >= s.characters.count {
                        return .String("")
                    } else if Int(start + len) >= s.characters.count {
                        return .String(s.substring(from: s.index(s.startIndex, offsetBy: Int(start))))
                    } else {
                        let sfrom = s.index(s.startIndex, offsetBy: Int(start))
                        let sto = s.index(s.startIndex, offsetBy: Int(start + len))
                        return .String(s.substring(with: sfrom..<sto))
                    }
                default:
                    return make_exception(flavor: .TypeError, id: self.id,
                                          msg: "third argument expects integer for length")
                }
            default:
                return make_exception(flavor: .TypeError, id: self.id,
                                      msg: "second argument expects integer for start")
            }
        default:
            return make_exception(flavor: .TypeError, id: self.id,
                                  msg: "first argument must be string")
        }
    }
}

class PFStrlen: SystemFunction {
    public override func call(param: ListEval) -> Evaluation {
        switch param.car! {
        case .String(let s):
            return .Integer(Int64(s.characters.count))
        default:
            return make_exception(flavor: .TypeError, id: self.id,
                                  msg: "string argument expected")
        }
    }
}

class PFCar: SystemFunction {
    public override func call(param: ListEval) -> Evaluation {
        switch param.car! {
        case .List(let l):
            if l.car != nil {
                return l.car!.copy
            } else {
                return make_exception(flavor: .RuntimeError, id: self.id,
                                      msg: "attempt to get head of empty list")
            }
        default:
            return make_exception(flavor: .TypeError, id: self.id,
                                  msg: "list argument expected")
        }
    }
}

class PFCdr: SystemFunction {
    public override func call(param: ListEval) -> Evaluation {
        switch param.car! {
        case .List(let l):
            if l.next != nil {
                return .List(l.next!.copy)
            } else {
                return make_exception(flavor: .RuntimeError, id: self.id,
                                      msg: "attempt to get tail of empty list")
            }
        default:
            return make_exception(flavor: .TypeError, id: self.id,
                                  msg: "list argument expected")
        }
    }
}

class PFCatch: SystemFunction {
    public override func call(param: ListEval) -> Evaluation {
        switch param.car! {
        case .Exception(let e):
            return .List(e.to_list)
        default:
            let rc = ListEval(.String("ok"))
            rc.append(ListEval(param.car!))
            rc.next!.append(ListEval(nil))
            return .List(rc)
        }
    }
}

class PFRaise: SystemFunction {
    public override func call(param: ListEval) -> Evaluation {
        return Evaluation.Exception(Exception(flavor: .Error, payload: param.car!))
    }
}

class PFReturn: SystemFunction {
    public override func call(param: ListEval) -> Evaluation {
        return Evaluation.Exception(Exception(flavor: .Return, payload: param.car!))
    }
}

