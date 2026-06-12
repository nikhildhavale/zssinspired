//
//  ViewController.swift
//  ZSSInspiredEditor
//
//  Created by Nikhil Dhavale on 22/05/26.
//

import UIKit
import ZSSEditorKit

final class ViewController: UIViewController {

    private let editor = RichTextEditorViewController()
    private var mentionSearchTask: Task<Void, Never>?

    private let remotePeople: [RichTextEditorViewController.MentionSuggestion] = [
        RichTextEditorViewController.MentionSuggestion(mentionIdentifier: "user-101", name: "Alice Johnson", image: .url(URL(string: "https://i.pravatar.cc/96?img=1")!)),
        RichTextEditorViewController.MentionSuggestion(mentionIdentifier: "user-102", name: "Bob Stone", image: .url(URL(string: "https://i.pravatar.cc/96?img=2")!)),
        RichTextEditorViewController.MentionSuggestion(mentionIdentifier: "user-103", name: "Charlie Lopez", image: .url(URL(string: "https://i.pravatar.cc/96?img=3")!)),
        RichTextEditorViewController.MentionSuggestion(mentionIdentifier: "user-104", name: "David Kim", image: .initials("DK")),
        RichTextEditorViewController.MentionSuggestion(mentionIdentifier: "user-105", name: "Emma Wilson", image: .url(URL(string: "https://i.pravatar.cc/96?img=5")!)),
        RichTextEditorViewController.MentionSuggestion(mentionIdentifier: "user-106", name: "Nikhil Dhavale", image: .initials("ND"), isSelfMention: true),
        RichTextEditorViewController.MentionSuggestion(mentionIdentifier: "user-107", name: "Priya Shah", image: .url(URL(string: "https://i.pravatar.cc/96?img=9")!)),
        RichTextEditorViewController.MentionSuggestion(mentionIdentifier: "user-108", name: "Sam Rivera", image: .initials("SR"))
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        installEditor()

        var configuration = editor.mentionConfiguration
        configuration.suggestions = [
            RichTextEditorViewController.MentionSuggestion(mentionIdentifier: "static-1", name: "Static Alice"),
            RichTextEditorViewController.MentionSuggestion(mentionIdentifier: "static-2", name: "Static Bob")
        ]
        configuration.loadingText = "Searching people..."
        configuration.exportFormat = .anchor
        editor.mentionConfiguration = configuration

        editor.onMentionQueryChanged = { [weak self] query in
            self?.performRemoteMentionSearch(query: query)
        }
        editor.onMentionInserted = { [weak self] mention in
            self?.logMentionState(event: "inserted \(mention.name) [\(mention.mentionIdentifier)]")
        }
        editor.onMentionRemoved = { [weak self] mention in
            self?.logMentionState(event: "removed \(mention.name) [\(mention.mentionIdentifier)]")
        }
    }

    private func installEditor() {
        addChild(editor)
        view.addSubview(editor.view)
        editor.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            editor.view.topAnchor.constraint(equalTo: view.topAnchor),
            editor.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            editor.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            editor.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        editor.didMove(toParent: self)
    }

    private func performRemoteMentionSearch(query: String?) {
        mentionSearchTask?.cancel()

        guard let query else {
            editor.setMentionSuggestionsLoading(false)
            print("mention query ended")
            return
        }

        editor.setMentionSuggestionsLoading(true)
        mentionSearchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled, let self else { return }

            let matches = remotePeople
                .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            await MainActor.run {
                self.editor.updateMentionSuggestions(matches)
                print("mention query '\(query)' returned \(matches.count) result(s)")
            }
        }
    }

    private func logMentionState(event: String) {
        let ids = editor.insertedMentions.map(\.mentionIdentifier).joined(separator: ", ")
        print("mention \(event)")
        print("current mention ids: [\(ids)]")
        print("export html: \(editor.html)")
    }
}
