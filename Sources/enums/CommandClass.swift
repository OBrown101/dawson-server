//
//  CommandClassifier.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/22/26.
//

import Foundation

enum CommandClass {
    case safe
    case prompt
    case denied(reason: String)
}
