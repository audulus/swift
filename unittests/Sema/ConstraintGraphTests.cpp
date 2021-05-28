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

TEST_F(SemaTest, TestConstraintGraphConnectedComponents) {
  ConstraintSystemOptions options;
  ConstraintSystem cs(DC, options);
  ConstraintGraph g(cs);

  auto components = g.computeConnectedComponents({});

  ASSERT_EQ(components.size(), 0);

  auto intTy = getStdlibType("Int");

  auto c0 = Constraint::create(cs, ConstraintKind::Equal, intTy, intTy, nullptr);
  g.addConstraint(c0);

  components = g.computeConnectedComponents({});

  ASSERT_EQ(components.size(), 1);
  if(components.size() == 1) {
    auto constraints = components[0].getConstraints();
    ASSERT_EQ(constraints, TinyPtrVector<Constraint *>{c0});
  }

  auto floatTy = getStdlibType("Float");

  auto c1 = Constraint::create(cs, ConstraintKind::Equal, floatTy, floatTy, nullptr);
  g.addConstraint(c1);

  components = g.computeConnectedComponents({});

  ASSERT_EQ(components.size(), 2);
  if(components.size() == 2) {
    ASSERT_EQ(components[0].getConstraints(), TinyPtrVector<Constraint *>{c0});
    ASSERT_EQ(components[1].getConstraints(), TinyPtrVector<Constraint *>{c1});
  }

}