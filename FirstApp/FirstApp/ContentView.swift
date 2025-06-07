//
//  ContentView.swift
//  FirstApp
//
//  Created by Александр on 26.04.2025.
//

import SwiftUI

// Todo model
struct Todo: Identifiable, Codable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var notes: String
    
    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, notes: String = "") {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.notes = notes
    }
}

// Dracula inspired theme
struct DraculaTheme {
    static let background = Color(hex: "282a36")
    static let currentLine = Color(hex: "44475a")
    static let selection = Color(hex: "44475a")
    static let foreground = Color(hex: "f8f8f2")
    static let comment = Color(hex: "6272a4")
    static let cyan = Color(hex: "8be9fd")
    static let green = Color(hex: "50fa7b")
    static let orange = Color(hex: "ffb86c")
    static let pink = Color(hex: "ff79c6")
    static let purple = Color(hex: "bd93f9")
    static let red = Color(hex: "ff5555")
    static let yellow = Color(hex: "f1fa8c")
}

class ThemeManager: ObservableObject {
    @Published var isDarkMode: Bool
    
    init(isDark: Bool = false) {
        self.isDarkMode = isDark
    }
    
    var background: Color {
        isDarkMode ? DraculaTheme.background : .white
    }
    
    var secondaryBackground: Color {
        isDarkMode ? DraculaTheme.currentLine : Color(hex: "f6f8fa")
    }
    
    var foreground: Color {
        isDarkMode ? DraculaTheme.foreground : .black
    }
    
    var accent: Color {
        isDarkMode ? DraculaTheme.purple : Color.blue
    }
    
    var completedColor: Color {
        isDarkMode ? DraculaTheme.green : Color.green
    }
    
    var deleteColor: Color {
        isDarkMode ? DraculaTheme.red : .red
    }
    
    var textPrimary: Color {
        isDarkMode ? DraculaTheme.foreground : .primary
    }
    
    var textSecondary: Color {
        isDarkMode ? DraculaTheme.comment : .secondary
    }
}

// Color extension for hex support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct ContentView: View {
    @AppStorage("todos") private var todosData: Data = Data()
    @State private var todos: [Todo] = []
    @State private var newTodoTitle: String = ""
    @State private var newTodoNotes: String = ""
    @State private var showAddTodoSheet: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var theme = ThemeManager()
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.background
                    .ignoresSafeArea()
                
                if todos.isEmpty {
                    VStack(spacing: 24) {
                        Image(systemName: "list.clipboard")
                            .font(.system(size: 70))
                            .foregroundStyle(theme.textSecondary)
                            .scaleEffect(1.1)
                            .animation(.easeInOut(duration: 1.5).repeatForever(), value: UUID())
                        Text("Нет задач")
                            .font(.title2.weight(.medium))
                            .foregroundStyle(theme.textSecondary)
                        Text("Нажмите + чтобы добавить новую задачу")
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary.opacity(0.8))
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(todos) { todo in
                                TodoRowView(todo: todo, theme: theme, onDelete: {
                                    withAnimation {
                                        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
                                            todos.remove(at: index)
                                            saveTodos()
                                        }
                                    }
                                }) { updatedTodo in
                                    if let index = todos.firstIndex(where: { $0.id == updatedTodo.id }) {
                                        withAnimation {
                                            todos[index] = updatedTodo
                                            saveTodos()
                                        }
                                    }
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Задачи")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { 
                        withAnimation {
                            showAddTodoSheet = true
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showAddTodoSheet) {
                AddTodoView(newTodoTitle: $newTodoTitle, newTodoNotes: $newTodoNotes, theme: theme) {
                    withAnimation {
                        addTodo()
                        showAddTodoSheet = false
                    }
                }
            }
            .foregroundStyle(theme.textPrimary)
        }
        .onAppear(perform: loadTodos)
        .onChange(of: colorScheme) {newValue in
            withAnimation(.easeInOut(duration: 0.2)) {
                theme.isDarkMode = newValue == .dark
            }
        }
    }
    
    private func loadTodos() {
        if let decoded = try? JSONDecoder().decode([Todo].self, from: todosData) {
            todos = decoded
        }
        theme.isDarkMode = colorScheme == .dark
    }
    
    private func saveTodos() {
        if let encoded = try? JSONEncoder().encode(todos) {
            todosData = encoded
        }
    }
    
    private func addTodo() {
        guard !newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let todo = Todo(title: newTodoTitle, notes: newTodoNotes)
        todos.append(todo)
        newTodoTitle = ""
        newTodoNotes = ""
        saveTodos()
    }
}

struct NotesView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var notes: String
    let theme: ThemeManager
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                TextEditor(text: $notes)
                    .scrollContentBackground(.hidden)
                    .background(theme.secondaryBackground)
                    .cornerRadius(8)
                    .padding()
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(theme.textSecondary.opacity(0.2), lineWidth: 1)
                    }
                
                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Заметки")
            .navigationBarTitleDisplayMode(.inline)
            .background(theme.background)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                    .foregroundStyle(theme.accent)
                }
            }
        }
        .foregroundStyle(theme.textPrimary)
    }
}

struct TodoRowView: View {
    let todo: Todo
    let theme: ThemeManager
    let onDelete: () -> Void
    let onUpdate: (Todo) -> Void
    @State private var offset: CGFloat = 0
    @State private var isSwiped = false
    @State private var showNotes = false
    @State private var editedNotes: String
    
    init(todo: Todo, theme: ThemeManager, onDelete: @escaping () -> Void, onUpdate: @escaping (Todo) -> Void) {
        self.todo = todo
        self.theme = theme
        self.onDelete = onDelete
        self.onUpdate = onUpdate
        _editedNotes = State(initialValue: todo.notes)
    }
    
    var body: some View {
        ZStack {
            // Delete button
            HStack {
                Spacer()
                Button(action: {
                    withAnimation(.spring()) {
                        onDelete()
                    }
                }) {
                    Image(systemName: "trash.fill")
                        .font(.title2)
                        .foregroundStyle(theme.foreground)
                        .frame(width: 60, height: 50)
                }
                .background(theme.deleteColor)
                .cornerRadius(8)
                .padding(.trailing, 16)
                .opacity(isSwiped ? 1 : 0)
            }
            
            // Todo item
            HStack(spacing: 16) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        var updatedTodo = todo
                        updatedTodo.isCompleted.toggle()
                        onUpdate(updatedTodo)
                    }
                }) {
                    Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(todo.isCompleted ? theme.completedColor : theme.textSecondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(todo.title)
                        .font(.body)
                        .strikethrough(todo.isCompleted)
                        .foregroundStyle(todo.isCompleted ? theme.textSecondary : theme.textPrimary)
                    
                    if !todo.notes.isEmpty {
                        Text(todo.notes)
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if !todo.isCompleted {
                    HStack(spacing: 12) {
                        Button(action: {
                            showNotes = true
                        }) {
                            Image(systemName: "note.text")
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                        
                        Image(systemName: "chevron.left")
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.secondaryBackground)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.textSecondary.opacity(0.2), lineWidth: 1)
            }
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        withAnimation(.interactiveSpring()) {
                            offset = value.translation.width
                            isSwiped = offset < -50
                        }
                    }
                    .onEnded { value in
                        withAnimation(.interactiveSpring()) {
                            if value.translation.width < -100 {
                                onDelete()
                            } else {
                                offset = 0
                                isSwiped = false
                            }
                        }
                    }
            )
            .sheet(isPresented: $showNotes) {
                NotesView(notes: $editedNotes, theme: theme)
                    .onDisappear {
                        var updatedTodo = todo
                        updatedTodo.notes = editedNotes
                        onUpdate(updatedTodo)
                    }
            }
        }
    }
}

struct AddTodoView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var newTodoTitle: String
    @Binding var newTodoNotes: String
    let theme: ThemeManager
    let onAdd: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    TextField("Новая задача", text: $newTodoTitle)
                        .textFieldStyle(.plain)
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(theme.secondaryBackground)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(theme.textSecondary.opacity(0.2), lineWidth: 1)
                        }
                        .font(.title3)
                    
                    TextEditor(text: $newTodoNotes)
                        .frame(height: 100)
                        .scrollContentBackground(.hidden)
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(theme.secondaryBackground)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(theme.textSecondary.opacity(0.2), lineWidth: 1)
                        }
                        .overlay(alignment: .topLeading) {
                            if newTodoNotes.isEmpty {
                                Text("Заметки (необязательно)")
                                    .foregroundStyle(theme.textSecondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                            }
                        }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Добавить задачу")
            .navigationBarTitleDisplayMode(.inline)
            .background(theme.background)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundStyle(theme.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Добавить") {
                        onAdd()
                        dismiss()
                    }
                    .font(.body.weight(.medium))
                    .foregroundStyle(theme.accent)
                    .disabled(newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .foregroundStyle(theme.textPrimary)
    }
}

#Preview {
    ContentView()
}
