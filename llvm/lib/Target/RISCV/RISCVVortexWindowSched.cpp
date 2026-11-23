//===-- RISCVVortexWindowSched.cpp - Window-friendly pre-RA scheduling ----===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// With Vortex register windows, each operand field switches window only when
// consecutive instructions take that field from different 32-register blocks.
// Unrolled code runs many independent copies of one computation; scheduling
// them a step at a time instead of a copy at a time keeps each field in one
// block across a phase. After register pressure, this strategy prefers the
// candidate at the lowest DAG level, then the opcode just scheduled.
//
//===----------------------------------------------------------------------===//

#include "RISCV.h"
#include "RISCVRegisterInfo.h"
#include "MCTargetDesc/RISCVMCTargetDesc.h"
#include "llvm/CodeGen/MachineScheduler.h"
#include "llvm/CodeGen/RegisterClassInfo.h"

using namespace llvm;

namespace {

class VortexWindowSchedStrategy : public GenericScheduler {
  const RegisterClassInfo *RCI;
  unsigned LastOpc = 0;
  bool HaveLast = false;

  // Level order widens the live set (every chain's next value at once); it
  // only applies while the integer register file is under three quarters full.
  bool haveRoom() const {
    if (!DAG->isTrackingPressure())
      return true;
    const std::vector<unsigned> &Cur =
        DAG->getTopRPTracker().getRegSetPressureAtPos();
    for (const int *PS = TRI->getRegClassPressureSets(&RISCV::GPRRegClass);
         *PS != -1; ++PS)
      if (4 * Cur[*PS] > 3 * RCI->getRegPressureSetLimit(*PS))
        return false;
    return true;
  }

public:
  VortexWindowSchedStrategy(const MachineSchedContext *C)
      : GenericScheduler(C), RCI(C->RegClassInfo) {}

  void initialize(ScheduleDAGMI *Dag) override {
    GenericScheduler::initialize(Dag);
    HaveLast = false;
  }

  // Levels are only uniform across chains from the top: a reduction at the
  // bottom gives every chain a different height.
  void initPolicy(MachineBasicBlock::iterator Begin,
                  MachineBasicBlock::iterator End,
                  unsigned NumRegionInstrs) override {
    GenericScheduler::initPolicy(Begin, End, NumRegionInstrs);
    RegionPolicy.OnlyTopDown = true;
    RegionPolicy.OnlyBottomUp = false;
  }

  void schedNode(SUnit *SU, bool IsTopNode) override {
    GenericScheduler::schedNode(SU, IsTopNode);
    LastOpc = SU->getInstr()->getOpcode();
    HaveLast = true;
  }

protected:
  bool tryCandidate(SchedCandidate &Cand, SchedCandidate &TryCand,
                    SchedBoundary *Zone) const override {
    if (Cand.isValid() && HaveLast) {
      if (!haveRoom())
        return GenericScheduler::tryCandidate(Cand, TryCand, Zone);
      if (DAG->isTrackingPressure() &&
          tryPressure(TryCand.RPDelta.Excess, Cand.RPDelta.Excess, TryCand,
                      Cand, RegExcess, TRI, DAG->MF))
        return TryCand.Reason != NoCand;
      // One step of every independent chain before the next step: lowest
      // level (depth top-down, height bottom-up) first.
      if (Zone) {
        bool Top = Zone->isTop();
        unsigned TryLvl = Top ? TryCand.SU->getDepth() : TryCand.SU->getHeight();
        unsigned CandLvl = Top ? Cand.SU->getDepth() : Cand.SU->getHeight();
        if (tryLess(TryLvl, CandLvl, TryCand, Cand, Cluster))
          return TryCand.Reason != NoCand;
      }
      bool TrySame = TryCand.SU->getInstr()->getOpcode() == LastOpc;
      bool CandSame = Cand.SU->getInstr()->getOpcode() == LastOpc;
      if (tryGreater(TrySame, CandSame, TryCand, Cand, Cluster))
        return TryCand.Reason != NoCand;
    }
    return GenericScheduler::tryCandidate(Cand, TryCand, Zone);
  }
};

} // end anonymous namespace

ScheduleDAGMILive *llvm::createVortexWindowSchedLive(MachineSchedContext *C) {
  ScheduleDAGMILive *DAG =
      new ScheduleDAGMILive(C, std::make_unique<VortexWindowSchedStrategy>(C));
  DAG->addMutation(createCopyConstrainDAGMutation(DAG->TII, DAG->TRI));
  return DAG;
}
