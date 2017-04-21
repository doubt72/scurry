//
//  parser.swift
//  scurry
//
//  Created by Douglas Triggs on 4/20/17.
//  Copyright © 2017 Douglas Triggs. All rights reserved.
//

import Foundation

// Simple parser, which turns tokens into our internal encoding:

// TODO: fix unterminated line

struct Block {
    var expressions: [Expression]
}

// Yeah, I know that normally enum values are lowercase.  But, uh, true and false are
// reserved words, for one.  So did this it this way for now
enum Expression {
    case True, False, Integer(Int64), Float(Double), String(String), List(SList)
    case Call(Call), Definition(Definition)
}

extension Expression {
    var to_debug: String {
        get {
            switch self {
            case .True:
                return "TRUE"
            case .False:
                return "FALSE"
            case .Integer(let n):
                return "INTEGER: \(n)"
            case .Float(let n):
                return "FLOAT: \(n)"
            case .String(let s):
                return "STRING: \(s)"
            case .List(let l):
                var rc = "LIST: [ "
                var current = l
                while current.car != nil {
                    rc += "\(current.car!.to_debug) "
                    current = current.next!
                }
                rc += "]"
                return rc
            case .Call(let c):
                return "CALL[\(c.id)] with \(Expression.List(c.param).to_debug)"
            case .Definition(let d):
                var rc = "DEFINITION[\(d.id)]: "
                for e in d.block.expressions {
                    rc += "\(e.to_debug); "
                }
                return rc
            }
        }
    }
}

class SList {
    private var head: Expression?
    private var tail: SList?
    
    init(_ head: Expression?) {
        self.head = head
        self.tail = nil
    }
    
    public func set(_ head: Expression) {
        self.head = head
    }
    
    public func append(_ tail: SList) {
        self.tail = tail
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
    
    public var car: Expression? {
        get {
            return self.head
        }
    }
    
    public var cadr: Expression? {
        get {
            return self.tail?.head
        }
    }
    
    public var next: SList? {
        get {
            return self.tail
        }
    }
}

struct Call {
    var id: String
    var param: SList
}

struct Definition {
    var id: String
    var block: Block
}

func parse_error(msg: String, pos: Int, line: String) {
    print("--- Parse error on line \(pos) :\n--- \(msg) :")
    print("\"\(line)\"")
    exit(1)
}

func get_token(tokens: [Token], start: Int) -> Token {
    if start > tokens.count - 1 {
        parse_error(msg: "unexpected end of file; statement unterminated",
                    pos: -1, line: "EOF")
    }
    return tokens[start]
}

func parse_definition(tokens: [Token], start: Int) -> (Definition?, Int) {
    let token = get_token(tokens: tokens, start: start)
    switch token.value {
    case .Colon:
        let (block, index) = parse_block(tokens: tokens, start: start + 1)
        return (Definition(id: "", block: block), index)
    case .ID(let id):
        var index = start + 1
        let token = get_token(tokens: tokens, start: index)
        switch token.value {
        case .Colon:
            index += 1
            let (block, change) = parse_block(tokens: tokens, start: index)
            return (Definition(id: id, block: block), change)
        default:
            return (nil, 0)
        }
    default:
        return (nil, 0)
    }
}

func parse_call(tokens: [Token], start: Int) -> (Call, Int) {
    var token = get_token(tokens: tokens, start: start)
    var id = ""
    switch token.value {
    case .ID(let s):
        id = s
    default:
        print("If you see this, there's a bug in the parser");
        exit(1)
    }
    var rc = Call(id: id, param: SList(nil))
    var index = start + 1
    token = get_token(tokens: tokens, start: index)
    switch token.value {
    case .OpenBracket:
        let (list, change) = parse_list(tokens: tokens, start: index)
        index = change
        rc.param = list
    default: ()
        // Bare function call so nothing to do
    }
    return (rc, index)
}

func parse_list(tokens: [Token], start: Int) -> (SList, Int) {
    var index = start + 1
    let rc = SList(nil)
    var current = rc
    var done = false
    while !done {
        let token = get_token(tokens: tokens, start: index);
        switch token.value {
        case .CloseBracket:
            done = true
        default:
            let (item, change) = parse_next_expression(tokens: tokens, start: index)
            index = change
            if item != nil {
                current.set(item!)
                current.append(SList(nil))
                current = current.next!
            } else {
                parse_error(msg: "expression or close bracket expected",
                            pos: token.lnum, line: token.line)
            }
        }
    }
    return (rc, index + 1)
}

func parse_next_expression(tokens: [Token], start: Int) -> (Expression?, Int) {
    let token = get_token(tokens: tokens, start: start)
    switch token.value {
    case .True:
        return (Expression.True, start + 1)
    case .False:
        return (Expression.False, start + 1)
    case .Integer(let n):
        return (Expression.Integer(n), start + 1)
    case .Float(let n):
        return (Expression.Float(n), start + 1)
    case .String(let s):
        return (Expression.String(s), start + 1)
    case .OpenBracket:
        let (list, index) = parse_list(tokens: tokens, start: start)
        return (Expression.List(list), index)
    case .ID(_):
        let (opt, index) = parse_definition(tokens: tokens, start: start)
        if opt != nil {
            return (Expression.Definition(opt!), index - 1)
        } else {
            let (call, index) = parse_call(tokens: tokens, start: start)
            return (Expression.Call(call), index)
        }
    case .Colon:
        let (opt, index) = parse_definition(tokens: tokens, start: start)
        if opt != nil {
            return (Expression.Definition(opt!), index - 1)
        } else {
            parse_error(msg: "expected function definition after colon, didn't get one",
                        pos: token.lnum, line: token.line)
            exit(1)
        }
    default:
        return (nil, 0)
    }
}

func parse_block(tokens: [Token], start: Int) -> (Block, Int) {
    var rc = Block(expressions: [])
    var index = start
    var done = false
    while !done {
        let (next, change) = parse_next_expression(tokens: tokens, start: index);
        if next != nil {
            index = change
            // DEBUG:
            //print(next!.to_debug)
            rc.expressions.append(next!)
            let check = get_token(tokens: tokens, start: index)
            switch check.value {
            case .Semicolon: ()
            // do nothing; semicolon expected
            default:
                parse_error(msg: "semicolon expected after expression, got",
                            pos: check.lnum, line: check.line)
            }
            index += 1
        } else {
            index += 1
            done = true
        }
    }
    return (rc, index)
}

func parse(tokens: [Token]) -> Block {
    let (block, index) = parse_block(tokens: tokens, start: 0);
    if index < tokens.count {
        parse_error(msg: "syntax error, unexpected token",
                    pos: tokens[index].lnum, line: tokens[index].line)
    }
    return block
}
