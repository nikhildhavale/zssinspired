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

    private let channels: [RichTextEditorViewController.MentionSuggestion] = [
        RichTextEditorViewController.MentionSuggestion(mentionIdentifier: "channel-1", name: "general", image: .initials("G")),
        RichTextEditorViewController.MentionSuggestion(mentionIdentifier: "channel-2", name: "announcements", image: .initials("A")),
        RichTextEditorViewController.MentionSuggestion(mentionIdentifier: "channel-3", name: "design", image: .initials("D")),
        RichTextEditorViewController.MentionSuggestion(mentionIdentifier: "channel-4", name: "engineering", image: .initials("E")),
        RichTextEditorViewController.MentionSuggestion(mentionIdentifier: "channel-5", name: "random", image: .initials("R"))
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

        var toolbarConfiguration = editor.toolbarConfiguration
        toolbarConfiguration.plusButtonBehavior = .action(
            RichTextEditorViewController.ToolbarAction(title: "Markdown", imageName: "doc.text") { [weak self] in
                self?.showMarkdownView()
            }
        )
        editor.toolbarConfiguration = toolbarConfiguration

        editor.mentionProvider = self
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

    private func logMentionState(event: String) {
        let ids = editor.insertedMentions.map(\.mentionIdentifier).joined(separator: ", ")
        print("mention \(event)")
        print("current mention ids: [\(ids)]")
        print("export html: \(editor.html)")
    }

    private func showMarkdownView() {
        let markdownText = editor.markdown
        let alert = UIAlertController(title: "Markdown", message: markdownText.isEmpty ? "No content" : markdownText, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Copy", style: .default) { _ in
            UIPasteboard.general.string = markdownText
        })
        alert.addAction(UIAlertAction(title: "Done", style: .cancel))
        present(alert, animated: true)
    }
}

extension ViewController: MentionSuggestionsProviding {

    func fetchMentionSuggestions(for query: String, completion: @escaping ([any RichTextEditorViewController.MentionItem]) -> Void) {
        // Simulated network latency; a real host app would fire its API call here
        // and invoke `completion` from the response callback (any thread is fine).
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.65) { [remotePeople] in
            let matches = remotePeople
                .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            print("mention query '\(query)' returned \(matches.count) result(s)")
            completion(matches)
        }
    }

    func fetchHashtagSuggestions(for query: String, completion: @escaping ([any RichTextEditorViewController.MentionItem]) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.4) { [channels] in
            let matches = channels
                .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            print("hashtag query '\(query)' returned \(matches.count) result(s)")
            completion(matches)
        }
    }

    func mentionSessionDidEnd() {
        print("mention query ended")
    }

    func mentionInserted(_ mention: any RichTextEditorViewController.MentionItem) {
        logMentionState(event: "inserted \(mention.name) [\(mention.mentionIdentifier)]")
    }

    func mentionRemoved(_ mention: any RichTextEditorViewController.MentionItem) {
        logMentionState(event: "removed \(mention.name) [\(mention.mentionIdentifier)]")
    }
}
