import SwiftUI

struct CommentComposerContext: Identifiable, Hashable {
    let parentCommentID: Int?
    let parentName: String?

    var id: String {
        parentCommentID.map { "reply-\($0)" } ?? "artwork"
    }

    static let artwork = CommentComposerContext(parentCommentID: nil, parentName: nil)
}

struct CommentComposerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PixivRepository.self) private var repository

    let illustrationID: Int
    let context: CommentComposerContext

    @State private var draft = ""
    @State private var isPosting = false
    @State private var errorMessage: String?
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("写评论", text: $draft, axis: .vertical)
                        .lineLimit(4...10)
                        .focused($isEditorFocused)
                        .disabled(isPosting)
                        .onChange(of: draft) { _, value in
                            if value.count > 140 {
                                draft = String(value.prefix(140))
                            }
                        }
                } header: {
                    if let parentName = context.parentName {
                        Text("回复 \(parentName)")
                    } else {
                        Text("评论作品")
                    }
                } footer: {
                    Text("\(draft.count) / 140")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(context.parentCommentID == nil ? "写评论" : "写回复")
            .safeAreaInset(edge: .bottom) {
                sendButton
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", systemImage: "xmark") {
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                    .disabled(isPosting)
                }
            }
            .task {
                isEditorFocused = true
            }
            .alert("发送失败", isPresented: errorBinding) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
        }
    }

    private var sendButton: some View {
        Button {
            Task { await post() }
        } label: {
            Group {
                if isPosting {
                    ProgressView()
                } else {
                    Text("发送")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isPosting || trimmedDraft.isEmpty)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func post() async {
        guard !trimmedDraft.isEmpty, !isPosting else { return }
        isPosting = true
        defer { isPosting = false }
        do {
            try await repository.postComment(
                illustrationID: illustrationID,
                comment: trimmedDraft,
                parentCommentID: context.parentCommentID
            )
            dismiss()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
