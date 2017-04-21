//
//  tokenizer.swift
//  scurry
//
//  Created by Douglas Triggs on 4/20/17.
//  Copyright © 2017 Douglas Triggs. All rights reserved.
//

import Foundation

// Super simple tokenizer/scanner:

struct LineLookup {
    var lnums: [Int]
    var lines: [String]
}

struct Token {
    var value: TokenValue
    var lnum: Int
    var line: String
    
    var to_debug: String {
        get {
            switch self.value {
            case .CloseBracket:
                return "\(self.lnum): CLOSEBRACKET"
            case .Colon:
                return "\(self.lnum): COLON"
            case .EOF:
                return "\(self.lnum): EOF"
            case .False:
                return "\(self.lnum): FALSE"
            case .Float(let n):
                return "\(self.lnum): FLOAT \(n)"
            case .ID(let s):
                return "\(self.lnum): ID \(s)"
            case .Integer(let n):
                return "\(self.lnum): INT \(n)"
            case .OpenBracket:
                return "\(self.lnum): OPENBRACKET"
            case .Semicolon:
                return "\(self.lnum): SEMICOLON"
            case .String(let s):
                return "\(self.lnum): STRING \(s)"
            case .True:
                return "\(self.lnum): TRUE"
            }
        }
    }
}

// Yeah, I know that normally enum values are lowercase.  But, uh, true and false are
// reserved words, for one.  So did this it this way for now
enum TokenValue {
    case Colon, Semicolon, OpenBracket, CloseBracket
    case ID(String), Integer(Int64), Float(Double), String(String)
    case True, False, EOF
}

func get_lnum(pos: Int, key: LineLookup) -> Int {
    return key.lnums[pos] + 1
}

func get_line(pos: Int, key: LineLookup) -> String {
    return key.lines[key.lnums[pos]]
}

func is_whitespace(_ char: Character) -> Bool {
    let whitespace: Set<Character> = [" ", "　", "\r", "\n", "\t"]
    if whitespace.contains(char) {
        return true
    }
    return false
}

func next_token(chars: [Character], start: Int, key: LineLookup) ->
    (Token, Int) {
        let reserved: Set<Character> = [":", ";", "[", "]", "\"", "#"]
        
        var index = start
        var c = chars[index]
        while is_whitespace(c) {
            if index == chars.count - 1 {
                // EOF is only returned with trailing whitespace (or closing comment), but
                // we need to return something when there's no "real" token left to return
                return (Token (value: TokenValue.EOF, lnum: -1, line: ""), index + 1)
            }
            index += 1
            c = chars[index]
        }
        let from = index
        var value = TokenValue.EOF
        var pos = index + 1
        switch c {
        case ":":
            value = .Colon
        case ";":
            value = .Semicolon
        case "[":
            value = .OpenBracket
        case "]":
            value = .CloseBracket
        case "#":
            index += 1
            c = chars[index]
            // Comment; eat the rest of the line
            while index < chars.count - 1 && c != "\n" && c != "\r" {
                index += 1
                c = chars[index]
            }
            // This is a comment, so we return the next token after it
            return next_token(chars: chars, start: index, key: key)
        case "\"":
            index += 1
            c = chars[index]
            // Everything to next double-quote is string
            // TODO: string escapes
            while index < chars.count - 1 && c != "\"" {
                index += 1
                c = chars[index]
            }
            let s = String(chars[from + 1..<index])
            if c != "\"" {
                parse_error(msg: "unterminated string in source: \(s)", pos: -1, line: "EOF")
            }
            pos = index + 1
            value = .String(s)
        default:
            while index < chars.count - 1 && !is_whitespace(c) &&
                !reserved.contains(c) {
                    index += 1
                    c = chars[index]
            }
            pos = index
            let s = String(chars[from...index - 1])
            if s == "true" {
                value = .True
            } else if s == "false" {
                value = .False
            } else {
                let n = Int64(s)
                if n != nil {
                    value = .Integer(n!)
                } else {
                    let x = Double(s)
                    if (x != nil) {
                        value = .Float(x!)
                    } else {
                        value = .ID(s)
                    }
                }
            }
        }
        let token = Token (value: value, lnum: get_lnum(pos: pos, key: key),
                           line: get_line(pos: pos, key: key) )
        return (token, pos)
}

func build_line_key(chars: [Character]) -> LineLookup {
    var key = LineLookup(lnums: [], lines: [])
    
    var line_num = 0
    var start = 0
    var current = 0
    for i in 0..<chars.count {
        key.lnums.append(line_num)
        if chars[i] == "\n" || chars[i] == "\r" {
            let line = String(chars[start...current])
            key.lines.append(line)
            start = current + 1
            line_num += 1
        }
        current += 1
    }
    if start > current {
        key.lnums.append(line_num)
        key.lines.append(String(chars[start...current - 1]))
    }
    return key
}

func tokenize(s: String) -> [Token] {
    let chars = Array(s.characters)
    let key = build_line_key(chars: chars)
    
    var tokens: [Token] = []
    
    var index = 0
    while index < chars.count {
        let (token, change) = next_token(chars: chars, start: index, key: key)
        index = change
        // DEBUG:
        //print(token.to_debug)
        tokens.append(token)
    }
    return tokens
}
