import UIKit

final class MarkdownViewController: UIViewController {

    private let markdownTextView = UITextView()
    private let markdown: String

    init(markdown: String) {
        self.markdown = markdown
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
    }

    private func configureUI() {
        title = "Markdown"
        view.backgroundColor = .systemBackground

        markdownTextView.translatesAutoresizingMaskIntoConstraints = false
        markdownTextView.text = markdown
        markdownTextView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        markdownTextView.isEditable = false
        markdownTextView.backgroundColor = .systemBackground
        markdownTextView.textColor = .label
        markdownTextView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        view.addSubview(markdownTextView)
        NSLayoutConstraint.activate([
            markdownTextView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            markdownTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            markdownTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            markdownTextView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let copyButton = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(copyMarkdown)
        )
        navigationItem.rightBarButtonItem = copyButton
    }

    @objc private func copyMarkdown() {
        UIPasteboard.general.string = markdown

        let alert = UIAlertController(title: "Copied", message: "Markdown copied to clipboard", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
