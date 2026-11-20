import Foundation

struct AudioImportSource: Sendable {
    let url: URL
    /// A child URL obtained by enumerating a folder needs the folder's security scope.
    let scope: URL
}

struct ImportIssue: Identifiable, Sendable {
    let id = UUID()
    let filename: String
    let reason: String
}

struct ImportReport: Sendable {
    var added = 0
    var duplicates = 0
    var issues: [ImportIssue] = []
    var stopped = false
    var finished = false
    var summary: String { "新增 \(added) 首 · 重复 \(duplicates) 首 · 失败 \(issues.count) 首" }
}

struct ImportProgress: Sendable {
    let completed: Int
    let total: Int
    let filename: String
}
