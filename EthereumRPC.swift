import Foundation

/// Minimal JSON-RPC client for Ethereum Mainnet with endpoint fallback.
/// Network/HTTP failures fall through to the next endpoint; an error returned *by* the node
/// (e.g. "insufficient funds", "nonce too low") is surfaced immediately and not retried elsewhere.
struct EthereumRPC: Sendable {
    static let mainnetChainID = Data([1])

    var endpoints: [URL] = [
        URL(string: "https://ethereum-rpc.publicnode.com")!,
        URL(string: "https://cloudflare-eth.com")!
    ]
    var session: URLSession = .shared

    private struct NodeError: Error { let message: String }

    private func call(_ method: String, _ params: [Any]) async throws -> Any {
        var lastError: Error = WalletError.rpcFailure("No network endpoint reachable.")
        for url in endpoints {
            do {
                var request = URLRequest(url: url, timeoutInterval: 15)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: [
                    "jsonrpc": "2.0", "id": 1, "method": method, "params": params
                ] as [String: Any])
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    throw WalletError.rpcFailure("HTTP error from \(url.host ?? "node").")
                }
                guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw WalletError.rpcMalformedResult
                }
                if let err = object["error"] as? [String: Any] {
                    throw NodeError(message: err["message"] as? String ?? "RPC error")
                }
                guard let result = object["result"] else { throw WalletError.rpcMalformedResult }
                return result            // may be NSNull (e.g. receipt not yet available)
            } catch let e as NodeError {
                throw WalletError.rpcFailure(e.message)
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private func quantity(_ method: String, _ params: [Any]) async throws -> Data {
        guard let hex = try await call(method, params) as? String, let data = Data(vaultHex: hex) else {
            throw WalletError.rpcMalformedResult
        }
        return data
    }

    func chainID() async throws -> Data { try await quantity("eth_chainId", []) }
    func balance(address: String) async throws -> Data { try await quantity("eth_getBalance", [address, "latest"]) }
    func nonce(address: String) async throws -> Data { try await quantity("eth_getTransactionCount", [address, "pending"]) }

    func isContract(address: String) async throws -> Bool {
        guard let code = try await call("eth_getCode", [address, "latest"]) as? String else {
            throw WalletError.rpcMalformedResult
        }
        return code != "0x"
    }

    /// EIP-1559 fee quote. maxFee = 2 x baseFee + tip, a common headroom rule that survives a few full blocks.
    func feeQuote(from: String, to: String, value: Data) async throws -> FeeQuote {
        let gasLimit = try await quantity("eth_estimateGas", [["from": from, "to": to, "value": value.rpcQuantity]])
        guard let block = try await call("eth_getBlockByNumber", ["latest", false]) as? [String: Any],
              let baseHex = block["baseFeePerGas"] as? String,
              let baseFee = Data(vaultHex: baseHex) else { throw WalletError.rpcMalformedResult }
        let tip = (try? await quantity("eth_maxPriorityFeePerGas", [])) ?? Data(vaultHex: "0x59682f00")!  // 1.5 gwei fallback
        let maxFee = Wei.add(Wei.multiply(baseFee, Wei.from(2)), tip)
        return FeeQuote(gasLimit: gasLimit, maxFeePerGas: maxFee, maxPriorityFeePerGas: tip)
    }

    func sendRaw(_ rawHex: String) async throws -> String {
        guard let hash = try await call("eth_sendRawTransaction", [rawHex]) as? String,
              hash.hasPrefix("0x"), hash.count == 66 else { throw WalletError.rpcMalformedResult }
        return hash
    }

    /// nil while the transaction is still pending.
    func receipt(hash: String) async throws -> ReceiptStatus? {
        guard let object = try await call("eth_getTransactionReceipt", [hash]) as? [String: Any] else { return nil }
        return (object["status"] as? String) == "0x1" ? .success : .failed
    }
}
