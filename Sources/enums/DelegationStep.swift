//
//  DelegationStep.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/28/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

enum DelegationStep {
    case completed(DelegationOutcome)
    case needsUser(request: UserInputRequest, pending: PendingChildSuspension)
}
