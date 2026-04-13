import NaturalLanguage

/// Shared pool of pre-configured NLTagger instances to avoid repeated allocation.
/// NLTagger is not thread-safe; all access must be serialised (e.g. from an actor).
final class NLTaggerPool {
    static let shared = NLTaggerPool()

    private let lexicalTagger: NLTagger
    private let nameTypeTagger: NLTagger

    private init() {
        lexicalTagger = NLTagger(tagSchemes: [.lexicalClass])
        lexicalTagger.setLanguage(.swedish, range: nil)
        nameTypeTagger = NLTagger(tagSchemes: [.nameType])
        nameTypeTagger.setLanguage(.swedish, range: nil)
    }

    /// Reuse the lexical-class tagger for the given text.
    /// Caller must not retain the returned tagger across async boundaries.
    func lexicalTagger(for text: String) -> NLTagger {
        lexicalTagger.string = text
        return lexicalTagger
    }

    /// Reuse the name-type tagger for the given text.
    /// Caller must not retain the returned tagger across async boundaries.
    func nameTypeTagger(for text: String) -> NLTagger {
        nameTypeTagger.string = text
        return nameTypeTagger
    }
}
