//===--- ConstraintGraphTests.cpp --------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#include "SemaFixture.h"
#include "swift/Sema/ConstraintGraph.h"

using namespace swift;
using namespace swift::unittest;
using namespace swift::constraints;

TEST_F(SemaTest, TestConstraintGraph) {
  ConstraintSystemOptions options;
  ConstraintSystem cs(DC, options);
  ConstraintGraph g(cs);
}