//
//  MentionProviding.swift
//  ZSSEditorKit
//

import UIKit

/// Adopt this in the host app to supply mention suggestions to a
/// `RichTextEditorViewController` and observe the mention lifecycle.
///
/// The interface is completion-handler based on purpose so legacy call sites
/// (older Swift, Objective-C-backed networking, callback-style APIs) can adopt
/// it without Swift concurrency.
///
/// Assign the conforming object to `RichTextEditorViewController.mentionProvider`.
/// The editor holds the provider weakly, so the host app must keep it alive
/// (typically the owning view controller or a dedicated adapter it retains).
public protocol MentionSuggestionsProviding: AnyObject {

    /// Called (already debounced by the editor) whenever the text following "@"
    /// changes. Fetch the items matching `query` and pass them to `completion`;
    /// an empty string means the user just typed "@" and expects the full list.
    ///
    /// `completion` may be called from any thread — the editor hops to the main
    /// thread itself — and results from superseded queries are dropped, so it is
    /// safe to call it late. Call it at most once per invocation.
    func fetchMentionSuggestions(for query: String, completion: @escaping ([any RichTextEditorViewController.MentionItem]) -> Void)

    /// Same contract as `fetchMentionSuggestions(for:completion:)`, but for the
    /// text following "#". Implement this to supply hashtag/channel suggestions;
    /// the default implementation returns no results. Optional.
    func fetchHashtagSuggestions(for query: String, completion: @escaping ([any RichTextEditorViewController.MentionItem]) -> Void)

    /// Called when the mention session ends without a selection
    /// (escape key, caret moved away, "@" or "#" deleted). Optional.
    func mentionSessionDidEnd()

    /// Called when the user picks a suggestion and it is inserted into the text. Optional.
    func mentionInserted(_ mention: any RichTextEditorViewController.MentionItem)

    /// Called when a previously inserted mention is deleted from the text. Optional.
    func mentionRemoved(_ mention: any RichTextEditorViewController.MentionItem)
}

public extension MentionSuggestionsProviding {
    func fetchHashtagSuggestions(for query: String, completion: @escaping ([any RichTextEditorViewController.MentionItem]) -> Void) {
        completion([])
    }
    func mentionSessionDidEnd() {}
    func mentionInserted(_ mention: any RichTextEditorViewController.MentionItem) {}
    func mentionRemoved(_ mention: any RichTextEditorViewController.MentionItem) {}
}
