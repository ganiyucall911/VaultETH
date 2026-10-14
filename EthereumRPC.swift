import Foundation

/// JSON-RPC client capable of interacting with any EVM-compatible blockchain network.
/// Supports multi-endpoint failover, dynamic EIP-1559 and legacy gas pricing,
/// contract detection, balance checks, and raw transaction broadcast.
struct EthereumRPC: Sendable {
    var network: BlockchainNetwork
    var session: URLSession = .shared

    init(network: BlockchainNetwork = .ethereum, session: URLSession = .shared) {
        self.network = network
        self.session = session
    }

    static func isSecureEndpoint(_ rawValue: String) -> Bool {
        guard let url = URL(string: rawValue), let scheme = url.scheme?.lowercased() else { return false }
        let host = url.host?.lowercased() ?? ""
        if scheme == "https" { return true }
        if scheme == "http" { return host == "localhost" || host == "127.0.0.1" || host == "::1" }
        return false
    }

    var endpoints: [URL] {
        network.rpcEndpoints
            .compactMap { URL(string: $0) }
            .filter { Self.isSecureEndpoint($0.absoluteString) }
    }

    private struct NodeError: Error {
        let message: String
        let data: String?
    }

    private func call(_ method: String, _ params: [Any]) async throws -> Any {
        var lastError: Error = WalletError.rpcFailure("No reachable secure RPC endpoint for \(network.name).")
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
                    let host = url.host ?? "node"
                    throw WalletError.rpcFailure("HTTP error from \(host).")
                }
                guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw WalletError.rpcMalformedResult
                }
                if let err = object["error"] as? [String: Any] {
                    let msg = err["message"] as? String ?? "RPC error"
                    let errData = err["data"] as? String
                    let code = err["code"] as? Int ?? 0
                    let isTransientNodeIssue = code == 429 || code == -32005 || code == -32603 ||
                        msg.localizedCaseInsensitiveContains("rate limit") ||
                        msg.localizedCaseInsensitiveContains("too many requests") ||
                        msg.localizedCaseInsensitiveContains("syncing") ||
                        msg.localizedCaseInsensitiveContains("internal")
                    if isTransientNodeIssue {
                        throw WalletError.rpcFailure(msg)
                    }
                    throw NodeError(message: msg, data: errData)
                }
                guard let result = object["result"] else { throw WalletError.rpcMalformedResult }
                return result
            } catch let e as NodeError {
                let detail = e.data != nil ? "\(e.message) (\(e.data!))" : e.message
                throw WalletError.rpcFailure(detail)
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

    func feeQuote(from: String, to: String, value: Data) async throws -> FeeQuote {
        let standardGasLimit = Data(vaultHex: "5208")!
        let estimatedGas: Data
        do {
            estimatedGas = try await quantity("eth_estimateGas", [["from": from, "to": to, "value": value.rpcQuantity]])
        } catch {
            if let isContract = try? await isContract(address: to), !isContract {
                estimatedGas = standardGasLimit
            } else if let fallbackGas = try? await quantity("eth_estimateGas", [["to": to, "value": value.rpcQuantity]]) {
                estimatedGas = fallbackGas
            } else {
                estimatedGas = standardGasLimit
            }
        }
        let gasLimit = Wei.compare(estimatedGas, standardGasLimit) == .orderedAscending ? standardGasLimit : estimatedGas

        if let block = try? await call("eth_getBlockByNumber", ["latest", false]) as? [String: Any],
           let baseHex = block["baseFeePerGas"] as? String,
           let baseFee = Data(vaultHex: baseHex) {
            let minTip = Data(vaultHex: "3b9aca00")!
            var tip = (try? await quantity("eth_maxPriorityFeePerGas", [])) ?? Data(vaultHex: "59682f00")!
            if Wei.compare(tip, minTip) == .orderedAscending { tip = minTip }
            let maxFee = Wei.add(Wei.multiply(baseFee, Wei.from(2)), tip)
            return FeeQuote(gasLimit: gasLimit, maxFeePerGas: maxFee, maxPriorityFeePerGas: tip)
        }

        let gasPrice = (try? await quantity("eth_gasPrice", [])) ?? Data(vaultHex: "04a817c800")!
        let tip = (try? await quantity("eth_maxPriorityFeePerGas", [])) ?? gasPrice
        return FeeQuote(gasLimit: gasLimit, maxFeePerGas: gasPrice, maxPriorityFeePerGas: tip)
    }

    func sendRaw(_ rawHex: String) async throws -> String {
        guard let hash = try await call("eth_sendRawTransaction", [rawHex]) as? String,
              hash.hasPrefix("0x"), hash.count == 66 else { throw WalletError.rpcMalformedResult }
        return hash
    }

    func receipt(hash: String) async throws -> ReceiptStatus? {
        guard let object = try await call("eth_getTransactionReceipt", [hash]) as? [String: Any],
              let statusHex = object["status"] as? String,
              let statusData = Data(vaultHex: statusHex) else { return nil }
        return !Wei.isZero(statusData) ? .success : .failed
    }

    func ethCall(to: String, data: String) async throws -> String {
        guard let result = try await call("eth_call", [["to": to, "data": data], "latest"]) as? String else {
            throw WalletError.rpcMalformedResult
        }
        return result
    }

    func simulateTransaction(from: String,
                             to: String,
                             value: Data,
                             isContract: Bool,
                             symbol: String) async -> TransactionSimulation {
        var warnings: [String] = []

        if isContract {
            warnings.append("Recipient is a deployed smart contract. Confirm it accepts direct native asset transfers.")
        }

        let callParams: [String: Any] = [
            "from": from,
            "to": to,
            "value": value.rpcQuantity
        ]

        do {
            _ = try await call("eth_call", [callParams, "latest"])
            let gasLimit = (try? await quantity("eth_estimateGas", [callParams])) ?? Data(vaultHex: "5208")!
            let gasUnits = Wei.toUInt64(gasLimit) ?? 21000
            let valText = ETHAmount.format(wei: value)
            let assetDesc = "- \(valText) \(symbol) from Sender"
            let status: TransactionSimulation.Status = warnings.isEmpty ? .success : .warning
            return TransactionSimulation(
                status: status,
                isSuccess: true,
                revertReason: nil,
                gasEstimated: gasUnits,
                assetChangeDescription: assetDesc,
                warnings: warnings
            )
        } catch {
            let errorMsg = error.localizedDescription
            let reason = Self.decodeRevertReason(from: errorMsg)
            warnings.append("On-chain simulation detected that this execution will revert.")

            return TransactionSimulation(
                status: .revert,
                isSuccess: false,
                revertReason: reason,
                gasEstimated: 21000,
                assetChangeDescription: "0 \(symbol) (Reverts on-chain)",
                warnings: warnings
            )
        }
    }

    static func decodeRevertReason(from hexOrMsg: String) -> String {
        let text = hexOrMsg.replacingOccurrences(of: "\\n", with: " ")
        if let range = text.range(of: "08c379a0", options: .caseInsensitive) {
            let hex = String(text[range.lowerBound...])
            if let data = Data(vaultHex: hex), data.count >= 68 {
                let lengthData = data.subdata(in: 36..<68)
                if let strLen = Wei.toUInt64(lengthData), strLen > 0, 68 + Int(strLen) <= data.count {
                    let strData = data.subdata(in: 68..<(68 + Int(strLen)))
                    if let decoded = String(data: strData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !decoded.isEmpty {
                        return decoded
                    }
                }
            }
        }

        var s = text
        if let r = s.range(of: "reverted:", options: .caseInsensitive) {
            s = String(s[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let r = s.range(of: "revert:", options: .caseInsensitive) {
            s = String(s[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return s.isEmpty ? "Execution reverted by smart contract" : s
    }
}
