//
//  DelegationStep.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/28/26.
//

enum DelegationStep {
    case completed(DelegationOutcome)
    case needsUser(request: UserInputRequest, pending: PendingChildSuspension)
}
