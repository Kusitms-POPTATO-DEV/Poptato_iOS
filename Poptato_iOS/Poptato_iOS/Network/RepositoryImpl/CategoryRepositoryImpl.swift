//
//  CategoryRepositoryImpl.swift
//  Poptato_iOS
//
//  Created by 현수 노트북 on 11/26/24.
//

final class CategoryRepositoryImpl: CategoryRepository {
    func getCategoryList(page: Int, size: Int) async throws -> CategoryListResponse {
        try await NetworkManager.shared.request(type: CategoryListResponse.self, api: .getCategoryList(page: page, size: size))
    }
}