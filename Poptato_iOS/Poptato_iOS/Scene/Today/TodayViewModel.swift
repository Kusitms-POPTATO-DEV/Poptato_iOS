//
//  TodayViewModel.swift
//  Poptato_iOS
//
//  Created by 현수 노트북 on 10/27/24.
//

import SwiftUI
import Foundation

final class TodayViewModel: ObservableObject {
    @Published var todayList: Array<TodayItemModel> = []
    @Published var currentDate: String = ""
    @Published var selectedTodoItem: TodoItemModel? = nil
    @Published var activeItemId: Int? = nil
    private var snapshotList: [TodayItemModel] = []
    private let todayRepository: TodayRepository
    private let todoRepository: TodoRepository
    private let backlogRepository: BacklogRepository
    
    init(
        todayRepository: TodayRepository = TodayRepositoryImpl(),
        todoRepository: TodoRepository = TodoRepositoryImpl(),
        backlogRepository: BacklogRepository = BacklogRepositoryImpl()
    ) {
        self.todayRepository = todayRepository
        self.todoRepository = todoRepository
        self.backlogRepository = backlogRepository
        let formatter = DateFormatter()
        formatter.dateFormat = "MM.dd"
        currentDate = formatter.string(from: Date())
    }
    
    func getTodayList() async {
        do {
            let response = try await todayRepository.getTodayList(page: 0, size: 50)
            DispatchQueue.main.async {
                self.todayList = response.todays.map { item in
                    TodayItemModel(
                        todoId: item.todoId,
                        content: item.content,
                        todayStatus: item.todayStatus,
                        isBookmark: item.isBookmark,
                        dday: item.dday,
                        deadline: item.deadline,
                        isRepeat: item.isRepeat
                    )
                }
                self.snapshotList = self.todayList
            }
        } catch {
            DispatchQueue.main.async {
                print("Error getTodayList \(error)")
            }
        }
    }
    
    func swipeToday(todoId: Int) async {
        await MainActor.run {
            self.snapshotList = self.todayList
        }
        
        do {
            try await todoRepository.swipeTodo(request: TodoIdModel(todoId: todoId))
            await MainActor.run {
                self.snapshotList = self.todayList
            }
        } catch {
            await MainActor.run {
                print("Error swipe today: \(error)")
                self.todayList = self.snapshotList
            }
        }
    }
    
    func updateTodoCompletion(todoId: Int) async {
        let previousSnapshot = todayList
        
        do {
            try await todoRepository.updateTodoCompletion(todoId: todoId)
            snapshotList = todayList
        } catch {
            DispatchQueue.main.async {
                print("Error update todocompletion: \(error)")
                self.todayList = previousSnapshot
            }
        }
    }
    
    func dragAndDrop() async {
        do {
            let todoIds = todayList.filter{ $0.todayStatus == "INCOMPLETE" }.map{ $0.todoId }
            try await todoRepository.dragAndDrop(type: "TODAY", todoIds: todoIds)
        } catch {
            print("Error dragAndDrop: \(error)")
        }
    }
    
    func deleteTodo(todoId: Int) async {
        do {
            await MainActor.run {
                self.todayList.removeAll { $0.todoId == todoId }
            }
            
            try await backlogRepository.deleteBacklog(todoId: todoId)
        } catch {
            DispatchQueue.main.async {
                print("Error delete today: \(error)")
            }
        }
    }
    
    func updateBookmark(todoId: Int) async {
        await MainActor.run { selectedTodoItem?.isBookmark.toggle() }
        
        do {
            try await todoRepository.updateBookmark(todoId: todoId)
            
            await MainActor.run {
                if let index = todayList.firstIndex(where: { $0.todoId == todoId }) {
                    todayList[index].isBookmark.toggle()
                }
            }
        } catch {
            DispatchQueue.main.async {
                print("Error updateBookmark: \(error)")
            }
        }
    }
    
    func updateDeadline(todoId: Int, deadline: String?) async {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        await MainActor.run { selectedTodoItem?.deadline = deadline }
        
        do {
            try await backlogRepository.updateDeadline(todoId: todoId, request: UpdateDeadlineRequest(deadline: deadline))
            await MainActor.run {
                if let index = todayList.firstIndex(where: { $0.todoId == todoId }) {
                    todayList[index].deadline = deadline
                    
                    if let deadline = deadline,
                        let parsedDate = dateFormatter.date(from: deadline) {
                        
                        let deadlineDate = Calendar.current.startOfDay(for: parsedDate)
                        let currentDate = Calendar.current.startOfDay(for: Date())
                        let calendar = Calendar.current

                        let components = calendar.dateComponents([.day], from: currentDate, to: deadlineDate)
                        if let daysDifference = components.day {
                            todayList[index].dday = daysDifference
                            selectedTodoItem?.dday = daysDifference
                        }
                    } else {
                        todayList[index].dday = nil
                        selectedTodoItem?.dday = nil
                    }
                }
            }
        } catch {
            print("Error updating deadline: \(error)")
        }
    }
    
    func updateTodoRepeat(todoId: Int) async {
        do {
            try await todoRepository.updateTodoRepeat(todoId: todoId)
            
            await MainActor.run {
                if let index = todayList.firstIndex(where: { $0.todoId == todoId }) {
                    todayList[index].isRepeat.toggle()
                }
            }
        } catch {
            print("Error updateTodoRepeat: \(error)")
        }
    }
}
