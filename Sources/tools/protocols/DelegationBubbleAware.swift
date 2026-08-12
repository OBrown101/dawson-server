//
//  DelegationBubbleAware.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/28/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

protocol DelegationBubbleAware: AnyObject {
    // Used by delegation tools
    // Allows agent run-loop treat child's suspension as tool's own suspension
    // and re-enter tool with user decision on resumeAgent.
    
    var hasPendingUserResponse: Bool { get }    // True when user decision staged for resumeAgent
    func setUserResponse(_ response: UserInputResponse) // Stages the user's decision before run-loop re-executes tool
    func consumePendingBubble() -> UserInputRequest?    // Tool last execution ended in bubble -> returns request to suspend on (consuming it); otherwise nil
    func capturePendingState() -> PendingChildSuspension?
    func restorePendingState(_ state: PendingChildSuspension?)
}
