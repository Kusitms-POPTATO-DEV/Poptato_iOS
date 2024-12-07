//
//  TodayView.swift
//  Poptato_iOS
//
//  Created by 현수 노트북 on 10/27/24.
//

import SwiftUI

struct TodayView: View {
    @EnvironmentObject var viewModel: TodayViewModel
    var goToBacklog: () -> Void
    @State private var isViewActive = false
    
    var body: some View {
        ZStack {
            Color(.gray100)
                .ignoresSafeArea()
            
            VStack {
                TopBar(
                    titleText: viewModel.currentDate,
                    subText: ""
                )
                
                if isViewActive {
                    if viewModel.todayList.isEmpty {
                        EmptyTodayView(
                            goToBacklog: goToBacklog
                        )
                    } else {
                        TodayListView(
                            todayList: $viewModel.todayList,
                            swipeToday: { id in
                                Task {
                                    await viewModel.swipeToday(todoId: id)
                                }
                            },
                            updateTodoCompletion: { id in
                                Task {
                                    await viewModel.updateTodoCompletion(todoId: id)
                                }
                            },
                            onDragEnd: {
                                Task {
                                    await viewModel.dragAndDrop()
                                }
                            }
                        )
                    }
                }
            }
        }
        .onAppear {
            Task {
                isViewActive = true
                await viewModel.getTodayList()
            }
        }
        .onDisappear {
            isViewActive = false
        }
    }
}

struct TodayListView: View {
    @Binding var todayList: [TodayItemModel]
    var swipeToday: (Int) -> Void
    var updateTodoCompletion: (Int) -> Void
    var onDragEnd: () -> Void
    @State private var draggedItem: TodayItemModel?
    @State private var draggedIndex: Int?
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(todayList, id: \.todoId) { item in
                    let index = todayList.firstIndex(where: { $0.todoId == item.todoId }) ?? 0
                    
                    TodayItemView(
                        item: Binding(
                            get: { item },
                            set: { updatedItem in
                                if let index = todayList.firstIndex(where: { $0.todoId == updatedItem.todoId }) {
                                    todayList[index] = updatedItem
                                }
                            }
                        ),
                        todayList: $todayList,
                        swipeToday: swipeToday,
                        updateTodoCompletion: updateTodoCompletion
                    )
                    .onDrag {
                        self.draggedItem = item
                        self.draggedIndex = index
                        let provider = NSItemProvider(object: String(item.todoId) as NSString)
                        provider.suggestedName = ""
                        return provider
                    }
                    .onDrop(of: [.text], delegate: TodayDropViewDelegate(
                        item: item,
                        todayList: $todayList,
                        draggedItem: $draggedItem,
                        draggedIndex: $draggedIndex,
                        onReorder: { onDragEnd() }
                    ))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }
}

struct TodayItemView: View {
    @Binding var item: TodayItemModel
    @Binding var todayList: [TodayItemModel]
    var swipeToday: (Int) -> Void
    var updateTodoCompletion: (Int) -> Void
    @State private var offset: CGFloat = 0

    var body: some View {
        VStack {
            HStack(spacing: 6) {
                if (item.isBookmark) {
                    HStack(spacing: 2) {
                        Image("ic_star_filled")
                            .resizable()
                            .frame(width: 12, height: 12)
                        Text("중요")
                            .font(PoptatoTypo.xsSemiBold)
                            .foregroundColor(.primary60)
                    }
                }
                
                if let dDay = item.dday {
                    if dDay == 0 {
                        Text("D-day")
                            .font(PoptatoTypo.xsSemiBold)
                            .foregroundColor(.gray70)
                    } else if dDay > 0 {
                        Text("D-\(dDay)")
                            .font(PoptatoTypo.xsSemiBold)
                            .foregroundColor(.gray70)
                    } else {
                        Text("D+\(abs(dDay))")
                            .font(PoptatoTypo.xsSemiBold)
                            .foregroundColor(.gray70)
                    }
                }
                if (item.isBookmark || item.dday != nil) { Spacer() }
            }
            
            HStack {
                Image(item.todayStatus == "COMPLETED" ? "ic_checked" : "ic_unchecked")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .onTapGesture {
                        updateTodoCompletion(item.todoId)
                        if item.todayStatus == "INCOMPLETE" {
                            moveItemToCompleted()
                        } else {
                            moveItemToIncomplete()
                        }
                    }

                Text(item.content)
                    .font(PoptatoTypo.mdRegular)
                    .foregroundColor(.gray00)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 8))
        .foregroundColor(.gray95)
        .offset(x: offset)
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { gesture in
                    if item.todayStatus != "COMPLETED" && gesture.translation.width > 0 {
                        self.offset = gesture.translation.width
                    }
                }
                .onEnded { _ in
                    if item.todayStatus != "COMPLETED" {
                        if abs(offset) > 100 {
                            swipeToday(item.todoId)
                            offset = UIScreen.main.bounds.width
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                if let index = todayList.firstIndex(where: { $0.todoId == item.todoId }) {
                                    todayList.remove(at: index)
                                }
                                offset = 0
                            }
                        } else {
                            offset = 0
                        }
                    } else {
                        offset = 0
                    }
                }
        )
    }

    private func moveItemToCompleted() {
        if let index = todayList.firstIndex(where: { $0.todoId == item.todoId }) {
            var updatedItem = item
            updatedItem.todayStatus = "COMPLETED"
            
            todayList.remove(at: index)
            todayList.append(updatedItem)
        }
    }

    private func moveItemToIncomplete() {
        if let index = todayList.firstIndex(where: { $0.todoId == item.todoId }) {
            var updatedItem = item
            updatedItem.todayStatus = "INCOMPLETE"
            
            todayList.remove(at: index)
            
            if let lastIncompleteIndex = todayList.lastIndex(where: { $0.todayStatus == "INCOMPLETE" }) {
                todayList.insert(updatedItem, at: lastIncompleteIndex + 1)
            } else {
                todayList.insert(updatedItem, at: 0)
            }
        }
    }
}

struct EmptyTodayView: View {
    var goToBacklog: () -> Void
    
    var body: some View {
        ZStack(alignment: .center) {
            VStack {
                Text("오늘 할 일은 무엇인가요?")
                    .font(PoptatoTypo.lgMedium)
                    .foregroundColor(.gray40)
                
                Button(
                    action: { goToBacklog() }
                ) {
                    HStack {
                        Image("ic_backlog_unselected")
                            .resizable()
                            .frame(width: 16, height: 16)
                            .foregroundColor(.primary100)
                        
                        Text("할 일 가져오기")
                            .font(PoptatoTypo.smSemiBold)
                            .foregroundColor(.primary100)
                    }
                    .frame(width: 132, height: 37)
                    .background(Color(.primary60))
                    .cornerRadius(32)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    TodayView(
        goToBacklog: {}
    )
}
