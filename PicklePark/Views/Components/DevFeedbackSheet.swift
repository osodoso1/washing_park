import SwiftUI

public struct DevFeedbackSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var cloudKitManager = CloudKitManager.shared
    
    @State private var feedbackType: String = "Feature Request"
    @State private var feedbackText: String = ""
    @State private var authorName: String = ""
    @State private var isSubmitting: Bool = false
    @State private var isSubmitted: Bool = false
    @State private var hiddenItemIds: Set<String> = []
    @State private var blockedAuthors: Set<String> = []
    
    private let types = ["Feature Request", "Bug Report", "Court / Schedule Issue", "Snack Suggestion", "Other"]
    
    public init() {}
    
    private var visibleCommunityFeedback: [CommunityFeedbackItem] {
        cloudKitManager.communityFeedbackList.filter { item in
            !hiddenItemIds.contains(item.id) && !blockedAuthors.contains(item.authorName.lowercased())
        }
    }
    
    public var body: some View {
        NavigationView {
            Form {
                // Section 1: Quick In-App Anonymous Feedback Submission
                Section(
                    header: Text("SUBMIT FEEDBACK & SUGGESTIONS"),
                    footer: Text("Your feedback is 100% anonymous by default. Community Guidelines: Zero tolerance for objectionable content or abusive behavior.")
                ) {
                    Picker("Topic", selection: $feedbackType) {
                        ForEach(types, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    TextField("Name / Handle (Optional — default: Anonymous)", text: $authorName)
                        .font(.system(size: 14))
                    
                    ZStack(alignment: .topLeading) {
                        if feedbackText.isEmpty {
                            Text("Tell us what you'd like added, improved, or fixed for Washington Park...")
                                .font(.system(size: 14))
                                .foregroundColor(.gray.opacity(0.6))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $feedbackText)
                            .frame(minHeight: 100)
                            .font(.system(size: 14))
                    }
                    
                    Button(action: {
                        submitFeedback()
                    }) {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: isSubmitted ? "checkmark.circle.fill" : "paperplane.fill")
                                Text(isSubmitted ? "Posted! ✓" : "Post to Community Board")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                            }
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .background(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.3) : AppTheme.burlingameBlue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                    .buttonStyle(.plain)
                }
                
                // Section 2: Live Community Feedback Feed
                Section(header: Text("COMMUNITY SUGGESTIONS (\(visibleCommunityFeedback.count))")) {
                    if visibleCommunityFeedback.isEmpty {
                        Text("No suggestions posted yet. Be the first to share an idea!")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textSecondary)
                    } else {
                        ForEach(visibleCommunityFeedback) { item in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(item.topic)
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2.5)
                                        .background(AppTheme.pickleballLime)
                                        .clipShape(Capsule())
                                    
                                    Spacer()
                                    
                                    Text(item.authorName.isEmpty || item.authorName.lowercased().contains("dominic") ? "Local Player" : item.authorName)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(AppTheme.textPrimary)
                                    
                                    Menu {
                                        Button(role: .destructive) {
                                            hiddenItemIds.insert(item.id)
                                            HapticFeedback.light()
                                        } label: {
                                            Label("Flag Inappropriate Post", systemImage: "flag.fill")
                                        }
                                        
                                        Button(role: .destructive) {
                                            blockedAuthors.insert(item.authorName.lowercased())
                                            hiddenItemIds.insert(item.id)
                                            HapticFeedback.light()
                                        } label: {
                                            Label("Block User & Hide Posts", systemImage: "hand.raised.slash.fill")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .font(.system(size: 13))
                                            .foregroundColor(AppTheme.textSecondary)
                                            .padding(.leading, 4)
                                    }
                                }
                                
                                Text(item.message)
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.textPrimary)
                                
                                Text(item.timestamp, style: .relative)
                                    .font(.system(size: 10))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                // Section 3: Support & Patreon Appreciation
                Section(header: Text("SUPPORT & APPRECIATION")) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color.red.opacity(0.85))
                                .padding(.top, 2)
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Thank You Patreon Supporters!")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                
                                Text("A sincere thank you to our Patreon community for their continued use and backing to keep PicklePark free and ad-free.")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        
                        Button(action: {
                            HapticFeedback.light()
                            if let url = URL(string: "https://www.buymeacoffee.com/osodoso") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 7) {
                                Text("☕️")
                                    .font(.system(size: 14))
                                Text("Buy me a coffee")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color(red: 1.0, green: 0.867, blue: 0.0))
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Community Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.burlingameBlue)
                }
            }
            .onAppear {
                Task {
                    await cloudKitManager.fetchCommunityFeedback()
                }
            }
        }
    }
    
    private func submitFeedback() {
        isSubmitting = true
        HapticFeedback.light()
        
        let enteredText = feedbackText
        let enteredTopic = feedbackType
        let enteredAuthor = authorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Local Player" : authorName
        
        Task {
            let success = await cloudKitManager.submitFeedback(
                topic: enteredTopic,
                message: enteredText,
                author: enteredAuthor
            )
            
            await MainActor.run {
                isSubmitting = false
                if success {
                    isSubmitted = true
                    HapticFeedback.success()
                    feedbackText = ""
                    authorName = ""
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        isSubmitted = false
                    }
                }
            }
        }
    }
}
