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

/// Removes simple instructions from a program if they are not required.
struct GenericInstructionReducer: Reducer {
    func reduce(_ code: inout Code, with verifier: ReductionVerifier) {
        // TODO
        var idx = code.count - 1
        while idx >= 0 {
            let instr = code[idx]
            if !instr.isSimple || instr.op is Nop || instr.op is Comment {
                continue
            }
            
            verifier.tryNopping(instructionAt: idx, in: &code)
            idx -= 1
        }
    }
}
