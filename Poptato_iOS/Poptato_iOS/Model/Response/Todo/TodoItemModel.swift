//
//  TodoItemModel.swift
//  Poptato_iOS
//
//  Created by 현수 노트북 on 10/23/24.
//

import Foundation
import SwiftUI

struct TodoItemModel: Codable {
    let todoId: Int
    var content: String
    var bookmark: Bool
    var dday: Int?
    var deadline: String?
}
