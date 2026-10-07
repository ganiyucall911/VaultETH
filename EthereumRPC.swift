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
                    let msg = err["message"] as? String ?? "RPC error"
                    let code = err["code"] as? Int ?? 0
                    // Fall through to the backup endpoint if this node is rate-limited or unavailable
                    let isTransientNodeIssue = code == 429 || code == -32005 || code == -32603 ||
                        msg.localizedCaseInsensitiveContains("rate limit") ||
                        msg.localizedCaseInsensitiveContains("too many requests") ||
                        msg.localizedCaseInsensitiveContains("syncing") ||
                        msg.localizedCaseInsensitiveContains("internal")
                    if isTransientNodeIssue {
                        throw WalletError.rpcFailure(msg)
                    }
                    throw NodeError(message: msg)
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
        guard let data = Data(vaultHex: code) else { return false }
        return !Wei.isZero(data)
    }

    /// EIP-1559 fee quote. maxFee = 2 x baseFee + tip, a common headroom rule that survives a few full blocks.
    func feeQuote(from: String, to: String, value: Data) async throws -> FeeQuote {
        let standardGasLimit = Data(vaultHex: "5208")! // 21,000 protocol minimum
        let estimatedGas: Data
        do {
            estimatedGas = try await quantity("eth_estimateGas", [["from": from, "to": to, "value": value.rpcQuantity]])
        } catch {
            // If the recipient is not a contract, gas is mathematically guaranteed to be 21,000.
            // Nodes often fail eth_estimateGas if the sender has insufficient balance to cover value + fee.
            // Using 21,000 for standard transfers lets the wallet calculate the fee and surface an exact
            // insufficientBalance error instead of a confusing raw node revert message.
            if let isContract = try? await isContract(address: to), !isContract {
                estimatedGas = standardGasLimit
            } else if let fallbackGas = try? await quantity("eth_estimateGas", [["to": to, "value": value.rpcQuantity]]) {
                estimatedGas = fallbackGas
            } else {
                throw error
            }
        }
        let gasLimit = Wei.compare(estimatedGas, standardGasLimit) == .orderedAscending ? standardGasLimit : estimatedGas

        guard let block = try await call("eth_getBlockByNumber", ["latest", false]) as? [String: Any],
              let baseHex = block["baseFeePerGas"] as? String,
              let baseFee = Data(vaultHex: baseHex) else { throw WalletError.rpcMalformedResult }

        let minTip = Data(vaultHex: "3b9aca00")! // 1.0 gwei minimum tip floor to prevent stuck transactions
        var tip = (try? await quantity("eth_maxPriorityFeePerGas", [])) ?? Data(vaultHex: "59682f00")!  // 1.5 gwei fallback
        if Wei.compare(tip, minTip) == .orderedAscending {
            tip = minTip
        }

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
        guard let object = try await call("eth_getTransactionReceipt", [hash]) as? [String: Any],
              let statusHex = object["status"] as? String,
              let statusData = Data(vaultHex: statusHex) else { return nil }
        // Accommodates both "0x1" (quantity) and "0x01" (fixed data) status representations
        return !Wei.isZero(statusData) ? .success : .failed
    }

    /// Executes a read-only `eth_call` and returns the raw ABI-encoded hex result.
    /// Used by `ENSResolver` for registry and resolver lookups.
    func ethCall(to: String, data: String) async throws -> String {
        guard let result = try await call("eth_call", [["to": to, "data": data], "latest"]) as? String else {
            throw WalletError.rpcMalformedResult
        }
        return result
    }
}
