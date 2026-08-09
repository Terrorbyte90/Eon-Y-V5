import Foundation

// Legacy seed literals were migrated to Resources/Knowledge/knowledge.v1.jsonl.
// Keep this extension as a compatibility surface for older callers; new loads
// happen through KnowledgeViewModel and KnowledgeResourceLoader.
extension KnowledgeArticle {
    static let library: [KnowledgeArticle] = []
}
