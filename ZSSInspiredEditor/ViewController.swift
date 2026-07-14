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
        RichTextEditorViewController.MentionSuggestion(mentionIdentifier: "user-101", displayName: "Alice Johnson", image: .url(URL(string: "https://i.pravatar.cc/96?img=1")!)),
        RichTextEditorViewController.MentionSuggestion(mentionIdentifier: "user-102", displayName: "Bob Stone", image: .url(URL(string: "https://i.pravatar.cc/96?img=2")!)),
        RichTextEditorViewController.MentionSuggestion(mentionIdentifier: "user-103", displayName: "Charlie Lopez", image: .url(URL(string: "https://i.pravatar.cc/96?img=3")!)),
        RichTextEditorViewController.MentionSuggestion(mentionIdentifier: "user-104", displayName: "David Kim", image: .initials("DK")),
        RichTextEditorViewController.MentionSuggestion(mentionIdentifier: "user-105", displayName: "Emma Wilson", image: .url(URL(string: "https://i.pravatar.cc/96?img=5")!)),
        RichTextEditorViewController.MentionSuggestion(mentionIdentifier: "user-106", displayName: "Nikhil Dhavale", image: .initials("ND"), isSelfMention: true),
        RichTextEditorViewController.MentionSuggestion(mentionIdentifier: "user-107", displayName: "Priya Shah", image: .url(URL(string: "https://i.pravatar.cc/96?img=9")!)),
        RichTextEditorViewController.MentionSuggestion(mentionIdentifier: "user-108", displayName: "Sam Rivera", image: .initials("SR"))
    ]

    private let hashtags: [RichTextEditorViewController.HashtagSuggestion] = [
        RichTextEditorViewController.HashtagSuggestion(name: "helpful", color: .systemYellow),
        RichTextEditorViewController.HashtagSuggestion(name: "highpriority", color: .systemOrange),
        RichTextEditorViewController.HashtagSuggestion(name: "Honesty", color: .label)
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        installEditor()

        var configuration = editor.mentionConfiguration
        configuration.suggestions = [
            RichTextEditorViewController.MentionSuggestion(mentionIdentifier: "static-1", displayName: "Static Alice"),
            RichTextEditorViewController.MentionSuggestion(mentionIdentifier: "static-2", displayName: "Static Bob")
        ]
        configuration.loadingText = "Searching people..."
        configuration.exportFormat = .anchor
        editor.mentionConfiguration = configuration

        var toolbarConfiguration = editor.toolbarConfiguration
        toolbarConfiguration.plusButtonBehavior = .action(
            RichTextEditorViewController.ToolbarAction(title: "Markdown", imageName: "doc.text") { [weak self] in
                guard let self else { return }
                self.showMarkdownView(self.editor.markdown)
            }
        )
        toolbarConfiguration.markdownPlusButtonBehavior = .action(
            RichTextEditorViewController.MarkdownToolbarAction(title: "Markdown", imageName: "doc.text") { [weak self] markdown in
                self?.showMarkdownView(markdown)
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

    private func logHashtagState(event: String) {
        let ids = editor.insertedHashtags.map(\.hashtagIdentifier).joined(separator: ", ")
        print("hashtag \(event)")
        print("current hashtag ids: [\(ids)]")
        print("export html: \(editor.html)")
    }

    private func showMarkdownView(_ markdownText: String) {
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
                .filter { query.isEmpty || $0.mentionDisplayName.localizedCaseInsensitiveContains(query) }
                .sorted { $0.mentionDisplayName.localizedCaseInsensitiveCompare($1.mentionDisplayName) == .orderedAscending }
            print("mention query '\(query)' returned \(matches.count) result(s)")
            completion(matches)
        }
    }

    func fetchHashtagSuggestions(for query: String, completion: @escaping ([any RichTextEditorViewController.HashtagItem]) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.4) { [hashtags] in
            let matches = hashtags
                .filter { query.isEmpty || $0.hashtagDisplayName.localizedCaseInsensitiveContains(query) }
                .sorted { $0.hashtagDisplayName.localizedCaseInsensitiveCompare($1.hashtagDisplayName) == .orderedAscending }
            print("hashtag query '\(query)' returned \(matches.count) result(s)")
            completion(matches)
        }
    }

    func mentionSessionDidEnd() {
        print("mention query ended")
    }

    func mentionInserted(_ mention: any RichTextEditorViewController.MentionItem) {
        logMentionState(event: "inserted \(mention.mentionDisplayName) [\(mention.mentionIdentifier)]")
    }

    func mentionRemoved(_ mention: any RichTextEditorViewController.MentionItem) {
        logMentionState(event: "removed \(mention.mentionDisplayName) [\(mention.mentionIdentifier)]")
    }

    func hashtagInserted(_ hashtag: any RichTextEditorViewController.HashtagItem) {
        logHashtagState(event: "inserted \(hashtag.hashtagDisplayName) [\(hashtag.hashtagIdentifier)]")
    }

    func hashtagRemoved(_ hashtag: any RichTextEditorViewController.HashtagItem) {
        logHashtagState(event: "removed \(hashtag.hashtagDisplayName) [\(hashtag.hashtagIdentifier)]")
    }
}
