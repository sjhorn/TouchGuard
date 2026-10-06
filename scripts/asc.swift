// Minimal App Store Connect API client: signs a JWT with the API key and
// sends one request. Used by scripts/appstore-metadata.sh.
//
//   ASC_KEY_PATH=… ASC_KEY_ID=… ASC_ISSUER_ID=… \
//     swift scripts/asc.swift GET '/v1/apps?filter[bundleId]=com.hornmicro.TouchGuard'
//   … swift scripts/asc.swift PATCH /v1/appInfoLocalizations/<id> body.json
//   … swift scripts/asc.swift UPLOAD <url> <file> <offset> <length> [header=value …]
//
// Prints the response body. Exits 1 on an HTTP error.
import CryptoKit
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func env(_ name: String) -> String {
    guard let value = ProcessInfo.processInfo.environment[name], !value.isEmpty else { fail("\(name) is not set") }
    return value
}

func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

func token() -> String {
    guard let pem = try? String(contentsOfFile: env("ASC_KEY_PATH"), encoding: .utf8) else { fail("Can't read ASC_KEY_PATH") }
    guard let key = try? P256.Signing.PrivateKey(pemRepresentation: pem) else { fail("ASC_KEY_PATH isn't a P-256 private key") }
    let header = ["alg": "ES256", "kid": env("ASC_KEY_ID"), "typ": "JWT"]
    let now = Int(Date().timeIntervalSince1970)
    let claims: [String: Any] = ["iss": env("ASC_ISSUER_ID"), "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"]
    let signingInput = base64URL(try! JSONSerialization.data(withJSONObject: header, options: .sortedKeys)) + "."
        + base64URL(try! JSONSerialization.data(withJSONObject: claims, options: .sortedKeys))
    let signature = try! key.signature(for: Data(signingInput.utf8))
    return signingInput + "." + base64URL(signature.rawRepresentation)
}

func send(_ request: URLRequest) -> (Int, Data) {
    let semaphore = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var result: (Int, Data) = (0, Data())
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error { fail("Request failed: \(error.localizedDescription)") }
        result = ((response as? HTTPURLResponse)?.statusCode ?? 0, data ?? Data())
        semaphore.signal()
    }.resume()
    semaphore.wait()
    return result
}

var args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 2 else { fail("usage: asc.swift METHOD PATH [body.json] | UPLOAD URL FILE OFFSET LENGTH [header=value …]") }
let method = args.removeFirst().uppercased()

let request: URLRequest
if method == "UPLOAD" {
    // A screenshot or video chunk to the pre-signed URL App Store Connect hands out. No JWT.
    guard args.count >= 4, let url = URL(string: args[0]), let offset = Int(args[2]), let length = Int(args[3]) else {
        fail("usage: asc.swift UPLOAD URL FILE OFFSET LENGTH [header=value …]")
    }
    guard let handle = FileHandle(forReadingAtPath: args[1]) else { fail("Can't read \(args[1])") }
    try handle.seek(toOffset: UInt64(offset))
    var r = URLRequest(url: url)
    r.httpMethod = "PUT"
    for pair in args.dropFirst(4) {
        let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
        if parts.count == 2 { r.setValue(parts[1], forHTTPHeaderField: parts[0]) }
    }
    r.httpBody = handle.readData(ofLength: length)
    request = r
} else {
    let path = args.removeFirst()
    let urlString = path.hasPrefix("http") ? path : "https://api.appstoreconnect.apple.com" + path
    guard let url = URL(string: urlString) else { fail("Bad URL: \(urlString)") }
    var r = URLRequest(url: url)
    r.httpMethod = method
    r.setValue("Bearer \(token())", forHTTPHeaderField: "Authorization")
    if let bodyPath = args.first {
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        guard let body = try? Data(contentsOf: URL(fileURLWithPath: bodyPath)) else { fail("Can't read \(bodyPath)") }
        r.httpBody = body
    }
    request = r
}

let (status, body) = send(request)
FileHandle.standardOutput.write(body)
if !(200..<300).contains(status) {
    fail("\nHTTP \(status)")
}
