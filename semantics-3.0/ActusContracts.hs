{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE NamedFieldPuns #-}
module ActusContracts where


import Data.Maybe
import qualified Data.List as List
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Time
import Data.Time.Clock
import Data.Time.Clock.POSIX
import Data.Time.Clock.System
import Debug.Trace

import ACTUS
import Semantics4

zcb ied md notional discount = (emptyContractConfig ied)
    { maturityDate = Just md
    , notional = notional
    , premiumDiscountAtIED = discount }

cb ied md notional rate = (emptyContractConfig ied)
    { maturityDate = Just md
    , notional = notional
    , nominalInterestRate = rate
    , interestPaymentCycle = Just $ Cycle 6 Month LongLastStub
    , premiumDiscountAtIED = 0 }


genPrincialAtMaturnityContract :: Party -> Party -> ContractConfig -> Contract
genPrincialAtMaturnityContract investor issuer config@ContractConfig{..} = let
    (f, _) = foldl generator (id, state) schedule
    in f RefundAll
  where
    acc = AccountId 1 investor
    maturityDay = fromJust maturityDate
    maturitySlot = dayToSlot maturityDay
    state = pamStateInit initialExchangeDate maturityDay
    cs = pamContractSchedule config state
    scheduledEvents = eventScheduleByDay cs
    startDate = dayToSlot initialExchangeDate
    schedule = traceShow scheduledEvents $ Map.toList scheduledEvents

    generator (f, state) (day, events) =
        let (daysum, newState) = foldl
                (\(amount, st) event -> let
                    (amount', st') = pamPayoffAndStateTransition RPA config event day st
                    in (amount + amount', st'))
                (0, state) events
            from = if daysum <= 0 then investor else issuer
            to   = if daysum <= 0 then issuer else investor
            amount = abs daysum
            cont = if amount == 0 then id
                   else \contract -> f $ When [Case (Deposit acc from $ Constant amount)
                        (Pay acc (Party to) (Constant amount) contract)] (dayToSlot day) RefundAll
            in (cont, newState)