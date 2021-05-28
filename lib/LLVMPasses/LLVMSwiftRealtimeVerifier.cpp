//===------- LLVMSwiftRealtimeVerifier.cpp - LLVM Realtime Verification --===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#include "swift/LLVMPasses/Passes.h"
#include "llvm/Analysis/TargetLibraryInfo.h"
#include "llvm/IR/LegacyPassManager.h" 
#include "llvm/IR/Module.h"
#include "llvm/IR/Instructions.h"

using namespace llvm;
using namespace swift;

char SwiftRealtimeVerifier::ID = 0;

void SwiftRealtimeVerifier::getAnalysisUsage(llvm::AnalysisUsage &AU) const {
  // do nothing for now
}

bool SwiftRealtimeVerifier::runOnFunction(llvm::Function &F) {

  bool safe = true;

  for(auto& block : F) {
    for(auto& inst : block) {
      if(inst.getOpcode() == Instruction::Call) {
        auto call = static_cast<CallInst*>(&inst);
        Function *fun = call->getCalledFunction();
        if (fun) {
          auto name = fun->getName();
          if(name.startswith("_swift") || name.startswith("__swift")) {
            safe = false;
          }
          errs().write_escaped(fun->getName()) << '\n';
        }
      }
    }
  }

  if(!safe) {
    errs() << "Function ";
    errs().write_escaped(F.getName()) << " contains swift runtime calls.\n";
  }

  return false;

}

//===----------------------------------------------------------------------===//
//                           Top Level Entry Point
//===----------------------------------------------------------------------===//

llvm::FunctionPass *swift::createSwiftRealtimeVerifierPass() {
  return new SwiftRealtimeVerifier();
}
