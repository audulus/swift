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
#include "swift/Demangling/Demangle.h"

using namespace llvm;
using namespace swift;

char SwiftRealtimeVerifier::ID = 0;

void SwiftRealtimeVerifier::getAnalysisUsage(llvm::AnalysisUsage &AU) const {
  // do nothing for now
}

bool SwiftRealtimeVerifier::runOnFunction(llvm::Function &F) {

  auto mdNode = F.getMetadata("realtime");

  if(mdNode == nullptr) {
    return false;
  }

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
        }
      }
    }
  }

  if(!safe) {
    errs() << "Function ";
    errs().write_escaped(Demangle::demangleSymbolAsString(F.getName())) << " contains swift runtime calls.\n";
  }

  return false;

}

//===----------------------------------------------------------------------===//
//                           Top Level Entry Point
//===----------------------------------------------------------------------===//

llvm::FunctionPass *swift::createSwiftRealtimeVerifierPass() {
  return new SwiftRealtimeVerifier();
}
