//
//  main.swift
//  scurry
//
//  Created by Douglas Triggs on 4/20/17.
//  Copyright © 2017 Douglas Triggs. All rights reserved.
//

import Foundation

if (CommandLine.arguments.count < 2) {
    print("Incorrect number of arguments: expecting source file as argument")
    exit(1)
}
let filename = CommandLine.arguments[1]
var source = ""
do {
    source = try String(contentsOfFile: filename)
} catch {
    print("Error reading file: \(filename)")
    exit(1)
}

let tokens = tokenize(s: source)
let block = parse(tokens: tokens)
evaluate(block: block)
