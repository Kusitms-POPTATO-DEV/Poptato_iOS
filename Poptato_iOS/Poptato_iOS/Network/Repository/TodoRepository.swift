//
//  TodoRepository.swift
//  Poptato_iOS
//
//  Created by 현수 노트북 on 10/28/24.
//

protocol TodoRepository {
    func swipeTodo(request: TodoIdModel) async throws -> Void
}
