//
//  Tool.swift
//  
//
//  Created by Ethan Brown on 3/19/26.
//

import Foundation

protocol Tool {
    var name: String { get }
    func schema() -> [String: Any]
    func execute(args: [String: Any]) -> String
}
