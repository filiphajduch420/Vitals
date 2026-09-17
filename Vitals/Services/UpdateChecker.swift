import Foundation
import os

/// Checks GitHub Releases for a newer version of Vitals.
///
/// Runs only when the user explicitly taps "Check for Updates" — there is no
/// automatic/background network request, keeping in line with the privacy
/// stance introduced in v2.4. A single unauthenticated `GET` to the public
/// releases endpoint is enough; no account or token is required.
actor UpdateChecker {

    /// Result of a successful check.
    enum CheckResult: Sendable, Equatable {
        case upToDate
        /// A newer release exists; `version` is the normalized tag (no "v"),
        /// `url` points at the release page.
        case updateAvailable(version: String, url: URL)
    }

    /// Failure modes surfaced to the caller. All are logged before being thrown,
    /// so the UI only needs a single generic "could not check" message.
    enum UpdateCheckError: Error {
        case requestFailed
        case invalidResponse
        case decodingFailed
        case invalidRelease
    }

    /// Minimal projection of the GitHub Releases payload we care about.
    private struct Release: Decodable {
        let tagName: String
        let htmlURL: String

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    private let releasesURL = URL(
        string: "https://api.github.com/repos/filiphajduch420/Vitals/releases/latest"
    )!

    /// Fetches the latest release and compares it against the running build.
    /// - Throws: `UpdateCheckError` on any network/parse failure (already logged).
    func checkForUpdate() async throws -> CheckResult {
        var request = URLRequest(url: releasesURL)
        request.timeoutInterval = 10
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            VitalsLog.app.error("update check: network request failed: \(error.localizedDescription)")
            throw UpdateCheckError.requestFailed
        }

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            VitalsLog.app.error("update check: unexpected HTTP status \(code, privacy: .public)")
            throw UpdateCheckError.invalidResponse
        }

        let release: Release
        do {
            release = try JSONDecoder().decode(Release.self, from: data)
        } catch {
            VitalsLog.app.error("update check: failed to decode releases response: \(error.localizedDescription)")
            throw UpdateCheckError.decodingFailed
        }

        let latest = Self.normalizedVersion(release.tagName)
        guard !latest.isEmpty, let releaseURL = URL(string: release.htmlURL) else {
            VitalsLog.app.error("update check: release payload missing version or URL")
            throw UpdateCheckError.invalidRelease
        }

        if Self.isNewer(latest, than: Self.currentVersion) {
            VitalsLog.app.info("update check: newer version \(latest, privacy: .public) available")
            return .updateAvailable(version: latest, url: releaseURL)
        }

        VitalsLog.app.info("update check: running the latest version")
        return .upToDate
    }

    // MARK: - Version helpers

    /// `CFBundleShortVersionString` of the running app, e.g. "2.4".
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// Strips a leading "v"/"V" and surrounding whitespace from a release tag.
    static func normalizedVersion(_ tag: String) -> String {
        var version = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if version.hasPrefix("v") || version.hasPrefix("V") {
            version.removeFirst()
        }
        return version
    }

    /// Compares two dotted version strings numerically, component by component,
    /// so that "2.10" is correctly treated as newer than "2.4". Missing trailing
    /// components count as 0 ("2.4" == "2.4.0"); non-numeric parts count as 0.
    /// - Returns: `true` if `candidate` is strictly newer than `current`.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let lhs = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let rhs = current.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(lhs.count, rhs.count) {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right { return left > right }
        }
        return false
    }
}
