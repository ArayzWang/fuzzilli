// Copyright 2019 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// A block is a sequence of instruction which starts at an opening instruction (isBlockBegin is true)
/// and ends at the next closing instruction (isBlockEnd is true) of the same nesting depth.
/// An example for a block is a loop:
///
///     BeginWhileLoop
///         ...
///     EndWhileLoop
///
/// A block contains the starting and ending instructions which are also referred to as "head" and "tail".
public struct Block {
    /// Index of the head of the block
    let head: Int
    
    /// Index of the tail of the block group
    let tail: Int
    
    /// The code that contains this block
    let code: Code
    
    public var size: Int {
        return tail - head + 1
    }
    
    public var begin: Instruction {
        return code[head]
    }
    
    public var end: Instruction {
        return code[tail]
    }
    
    public init(head: Int, tail: Int, in code: Code) {
        self.code = code
        self.head = head
        self.tail = tail
        
        assert(begin.isBlockBegin)
        assert(end.isBlockEnd)
        assert(Blocks.findBlockBegin(end: tail, in: code) == head)
        assert(Blocks.findBlockEnd(start: head, in: code) == tail)
    }
    
    public init(startingAt head: Int, in code: Code) {
        precondition(code[head].isBlockEnd)
        let tail = Blocks.findBlockEnd(start: head, in: code)
        self.init(head: head, tail: tail, in: code)
    }
    
    public init(endingAt tail: Int, in code: Code) {
        precondition(code[tail].isBlockEnd)
        let head = Blocks.findBlockBegin(end: tail, in: code)
        self.init(head: head, tail: tail, in: code)
    }
    
    /// Returns the list of instruction in the body of this block.
    ///
    /// TODO make iterator instead?
    public func body() -> [Int] {
        var content = [Int]()
        var idx = head + 1
        while idx < tail {
            content.append(idx)
            idx += 1
        }
        return content
    }
    
    public func foo() -> ClosedRange<Int> {
        return head...tail
    }
}

/// A block group is a sequence of blocks (and thus instructions) that is started by an opening instruction
/// that is not closing an existing block (isBlockBegin is true and isBlockEnd is false) and ends at a closing
/// instruction that doesn't open a new block (isBlockEnd is true and isBlockBegin is false).
/// An example for a block group is an if-else statement:
///
///     BeginIf
///        ; block 1
///        ...
///     BeginElse
///        ; block 2
///        ...
///     EndIf
///
public struct BlockGroup {
    /// The program that this block group is part of.
    public let code: Code
    
    /// Index of the first instruction in this block group (the opening instruction).
    public var head: Int {
        return blockInstructions.first!
    }
    
    /// Index of the last instruction in this block group (the closing instruction).
    public var tail: Int {
        return blockInstructions.last!
    }
    
    /// The number of instructions in this block group.
    public var size: Int {
        return tail - head + 1
    }
    
    /// The first instruction in this block group.
    public var begin: Instruction {
        return code[head]
    }
    
    /// The last instruction in this block group.
    public var end: Instruction {
        return code[tail]
    }
    
    /// The number of blocks that are part of this block group.
    public var numBlocks: Int {
        return blockInstructions.count - 1
    }
    
    /// Indices of the block instructions belonging to this block group
    // TODO rename this maybe?
    private let blockInstructions: [Int]
    
    /// Constructs a block group from the a list of block instructions.
    ///
    /// - Parameters:
    ///   - blockInstructions: The block instructions that make up the block group.
    ///   - program: The program that the instructions are part of.
    fileprivate init(_ blockInstructions: [Int], in code: Code) {
        self.code = code
        self.blockInstructions = blockInstructions
        assert(begin.isBlockGroupBegin)
        assert(end.isBlockGroupEnd)
    }
    
    public init(startingAt head: Int, in code: Code) {
        let blockInstructions = Blocks.collectBlockGroup(start: head, in: code)
        self.init(blockInstructions, in: code)
    }
    
    public init(surrounding idx: Int, in code: Code) {
        let head = Blocks.findBlockGroupHead(surrounding: idx, in: code)
        self.init(startingAt: head, in: code)
    }
    
    /// Returns the ith block in this block group.
    func block(_ i: Int) -> Block {
        return Block(head: blockInstructions[i], tail: blockInstructions[i + 1], in: code)
    }
    
    /// Returns the ith block instruction in this block group.
    subscript(i: Int) -> Int {
        return blockInstructions[i]
    }
    
    /// Returns a list of all block instructions that make up this block group.
    func excludingContent() -> [Int] {
        return blockInstructions
    }
    
    /// Returns a list of all instructions, including content instructions, of this block group.
    // TODO should return a custom Sequence.
    func includingContent() -> [Int] {
        return Array(head...tail)
    }
}

/// Block-related utility algorithms are  implemented here, and used by the Block/BlockGroup constructors.
public class Blocks {
    // TODO see if it's possible to factor out and reuse the common traversal code.
    
    // TODO merge with findBlockBegin
    static func findBlockEnd(start: Int, in code: Code) -> Int {
        precondition(code[start].isBlockBegin)
        
        var idx = start + 1
        var depth = 1
        while idx < code.count {
            let current = code[idx]
            if current.isBlockEnd {
                depth -= 1
            }
            if depth == 0 {
                assert(current.isBlockEnd)
                return idx
            }
            if current.isBlockBegin {
                depth += 1
            }
            idx += 1
        }
        
        fatalError("Invalid code")
    }
    
    static func findBlockBegin(end: Int, in code: Code) -> Int {
        precondition(code[end].isBlockEnd)
        
        var idx = end - 1
        var depth = 1
        while idx >= 0 {
            let current = code[idx]
            if current.isBlockBegin {
                depth -= 1
            }
            // Note: the placement of this if is the only difference from the following function...
            if depth == 0 {
                assert(current.isBlockBegin)
                return idx
            }
            if current.isBlockEnd {
                depth += 1
            }
            idx -= 1
        }
        
        fatalError("Invalid code")
    }

    static func findBlockGroupHead(surrounding idx: Int, in code: Code) -> Int {
        guard !code[idx].isBlockGroupBegin else {
            return idx
        }
        
        var idx = idx - 1
        var depth = 1
        repeat {
            let current = code[idx]
            if current.isBlockBegin {
                depth -= 1
            }
            if current.isBlockEnd {
                depth += 1
            }
            if depth == 0 {
                assert(current.isBlockGroupBegin)
                return idx
            }
            idx -= 1
        } while idx >= 0
        
        fatalError("Invalid code")
    }
    
    static func collectBlockGroup(start: Int, in code: Code) -> [Int] {
        var content = [start]
        
        var idx = start + 1
        var depth = 1
        repeat {
            let current = code[idx]
            
            if current.isBlockEnd {
                depth -= 1
            }
            if current.isBlockBegin {
                if depth == 0 {
                    content.append(idx)
                }
                depth += 1
            }
            if depth == 0 {
                assert(current.isBlockGroupEnd)
                content.append(idx)
                break
            }
            idx += 1
        } while idx < code.count
        assert(idx < code.count)
        
        return content
    }
    
    static func findAllBlockGroups(in code: Code) -> [BlockGroup] {
        var groups = [BlockGroup]()
        
        var blockStack = [[Int]]()
        for (idx, instr) in code.enumerated() {
            if instr.isBlockBegin && !instr.isBlockEnd {
                // By definition, this is the start of a block group
                blockStack.append([idx])
            } else if instr.isBlockEnd {
                // Either the end of a block group or a new block in the current block group.
                blockStack[blockStack.count - 1].append(idx)
                if !instr.isBlockBegin {
                    groups.append(BlockGroup(blockStack.removeLast(), in: code))
                }
            }
        }
        
        return groups
    }
}

