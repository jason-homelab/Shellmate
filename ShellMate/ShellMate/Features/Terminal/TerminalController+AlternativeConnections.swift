import Foundation

// MARK: - 替代协议连接（Telnet / Serial / ProxyJump）

extension TerminalController {

    // MARK: - Telnet 连接

    func connectTelnet() async throws {
        userDisconnected = false
        pendingHostKeyState = nil
        state = .connecting
        delegate?.terminalController(self, didChangeState: state)

        let conn = TelnetConnection()
        let coalescer = TerminalDataCoalescer()

        await conn.configure(
            onDataReceived: { [weak self] data in
                let bytes = [UInt8](data)
                Task { [weak self] in
                    let shouldFlush = await coalescer.append(bytes)
                    guard shouldFlush else { return }
                    try? await Task.sleep(nanoseconds: AppConstants.terminalCoalescerIntervalNs)
                    let flushed = await coalescer.drain()
                    guard !flushed.isEmpty else { return }
                    await MainActor.run { [weak self] in
                        guard let self else { return }
                        let processed = HighlightEngine.shared.process(Data(flushed))
                        self.terminalView?.feed(byteArray: [UInt8](processed)[...])
                        self.delegate?.terminalController(self, didReceiveData: Data(flushed))
                        self.appendToSessionLog(flushed)
                        let decoded = String(bytes: flushed, encoding: .utf8) ?? ""
                        self.terminalVM.updateOutputBuffer(decoded)
                        self.logOutputLines(decoded)
                        Task { await self.recorder.appendOutput(decoded) }
                        if AISettingsStore.shared.isEnabled && AISettingsStore.shared.errorDetectiveEnabled {
                            self.terminalVM.detectErrors(in: decoded)
                        }
                        AutomationTriggerEngine.shared.process(output: decoded, sessionId: self.sessionId, controller: self)
                    }
                }
            },
            onDisconnected: { [weak self] in
                Task { @MainActor [weak self] in self?.handleConnectionLost() }
            }
        )

        self.telnetConnection = conn

        do {
            let port = UInt16(clamping: max(1, session.port))
            try await conn.connect(host: session.host, port: port)
            await conn.updateWindowSize(columns: terminalSize.columns, rows: terminalSize.rows)

            state = .connected
            connectedAt = Date()
            delegate?.terminalController(self, didChangeState: state)
            logSystemEvent("已通过 Telnet 连接至 \(session.host):\(session.port)")
            executeStartupCommandIfNeeded()
            AutomationTriggerEngine.shared.processEvent(.onConnect, sessionId: sessionId, controller: self)

        } catch {
            self.telnetConnection = nil
            state = .failed(error.localizedDescription)
            delegate?.terminalController(self, didChangeState: state)
            let wrapped = SSHError.connectionFailed(host: session.host, port: session.port, underlying: error)
            delegate?.terminalController(self, didFailWithError: wrapped)
            throw error
        }
    }

    // MARK: - Serial 连接

    func connectSerial() async throws {
        guard let portPath = session.serialPortPath, !portPath.isEmpty else {
            let err = SerialError.portOpenFailed(path: "(未配置)", code: 0)
            state = .failed(err.localizedDescription)
            delegate?.terminalController(self, didChangeState: state)
            throw err
        }

        userDisconnected = false
        pendingHostKeyState = nil
        state = .connecting
        delegate?.terminalController(self, didChangeState: state)

        let conn = SerialConnection()
        let coalescer = TerminalDataCoalescer()

        await conn.configure(
            onDataReceived: { [weak self] data in
                let bytes = [UInt8](data)
                Task { [weak self] in
                    let shouldFlush = await coalescer.append(bytes)
                    guard shouldFlush else { return }
                    try? await Task.sleep(nanoseconds: AppConstants.terminalCoalescerIntervalNs)
                    let flushed = await coalescer.drain()
                    guard !flushed.isEmpty else { return }
                    await MainActor.run { [weak self] in
                        guard let self else { return }
                        let processed = HighlightEngine.shared.process(Data(flushed))
                        self.terminalView?.feed(byteArray: [UInt8](processed)[...])
                        self.delegate?.terminalController(self, didReceiveData: Data(flushed))
                        self.appendToSessionLog(flushed)
                        let decoded = String(bytes: flushed, encoding: .utf8) ?? ""
                        self.terminalVM.updateOutputBuffer(decoded)
                        self.logOutputLines(decoded)
                        Task { await self.recorder.appendOutput(decoded) }
                        if AISettingsStore.shared.isEnabled && AISettingsStore.shared.errorDetectiveEnabled {
                            self.terminalVM.detectErrors(in: decoded)
                        }
                        AutomationTriggerEngine.shared.process(output: decoded, sessionId: self.sessionId, controller: self)
                    }
                }
            },
            onDisconnected: { [weak self] in
                Task { @MainActor [weak self] in self?.handleConnectionLost() }
            }
        )

        self.serialConnection = conn

        do {
            try await conn.connect(
                portPath:    portPath,
                baudRate:    session.serialBaudRate,
                dataBits:    session.serialDataBits,
                parity:      session.serialParity,
                stopBits:    session.serialStopBits,
                flowControl: session.serialFlowControl
            )

            state = .connected
            connectedAt = Date()
            delegate?.terminalController(self, didChangeState: state)
            logSystemEvent("已连接串口 \(portPath) @ \(session.serialBaudRate) bps")
            executeStartupCommandIfNeeded()
            AutomationTriggerEngine.shared.processEvent(.onConnect, sessionId: sessionId, controller: self)

        } catch {
            self.serialConnection = nil
            state = .failed(error.localizedDescription)
            delegate?.terminalController(self, didChangeState: state)
            let wrapped = SSHError.connectionFailed(host: portPath, port: 0, underlying: error)
            delegate?.terminalController(self, didFailWithError: wrapped)
            throw error
        }
    }

    // MARK: - ProxyJump 连接

    /// 通过跳板机链连接目标服务器（9.1/9.2 ProxyJump）
    func connectViaProxyJump() async throws {
        let password = try? await CredentialVault.shared.load(sessionId: session.id, type: .password)
        let passphrase = try? await CredentialVault.shared.load(sessionId: session.id, type: .passphrase)

        var resolvedChain: [ProxyJumpConfig] = []
        for var hop in session.jumpHosts {
            if let vid = hop.vaultId {
                hop.resolvedPassword = try? await CredentialVault.shared.load(
                    sessionId: vid, type: .password
                )
            }
            resolvedChain.append(hop)
        }

        var targetConfig = SSHSessionConfig.from(
            session: session,
            password: password,
            passphrase: passphrase
        )
        targetConfig.terminalColumns = terminalSize.columns
        targetConfig.terminalRows = terminalSize.rows

        let manager = ProxyJumpManager(
            proxyChain: resolvedChain,
            targetConfig: targetConfig
        )

        do {
            try await manager.connect()
        } catch {
            let sshError: SSHError
            if let e = error as? SSHError {
                sshError = e
            } else {
                sshError = SSHError.connectionFailed(host: session.host, port: session.port, underlying: error)
            }
            state = .failed(sshError.localizedDescription)
            delegate?.terminalController(self, didChangeState: state)
            delegate?.terminalController(self, didFailWithError: sshError)
            throw sshError
        }

        proxyJumpManager = manager

        // 将数据流桥接到 SwiftTerm（高亮 + ProxyJump 路径合并器）
        if let stream = await manager.getDataStream() {
            Task { [weak self] in
                let coalescer = TerminalDataCoalescer()
                for await data in stream {
                    guard self != nil else { return }
                    let bytes = [UInt8](data)
                    let shouldFlush = await coalescer.append(bytes)
                    guard shouldFlush else { continue }
                    try? await Task.sleep(nanoseconds: AppConstants.terminalCoalescerIntervalNs)
                    let flushed = await coalescer.drain()
                    guard !flushed.isEmpty else { continue }
                    await MainActor.run { [weak self] in
                        guard let self else { return }
                        if let text = String(bytes: flushed, encoding: .utf8),
                           self.tmuxStore.isInCollectionMode || text.contains("__SM_TMUX_") {
                            var terminalBytes: [UInt8] = []
                            let parts = text.components(separatedBy: "\n")
                            for (i, line) in parts.enumerated() {
                                let wasCollecting = self.tmuxStore.isInCollectionMode
                                if !self.tmuxStore.filterLine(line) {
                                    terminalBytes.append(contentsOf: Array(line.utf8))
                                    if i < parts.count - 1 {
                                        terminalBytes.append(UInt8(ascii: "\n"))
                                    }
                                } else {
                                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !trimmed.hasPrefix("__SM_TMUX_") && !wasCollecting && !trimmed.isEmpty {
                                        terminalBytes.append(UInt8(ascii: "\r"))
                                    }
                                }
                            }
                            guard !terminalBytes.isEmpty else { return }
                            let processed = HighlightEngine.shared.process(Data(terminalBytes))
                            self.terminalView?.feed(byteArray: [UInt8](processed)[...])
                        } else {
                            let processed = HighlightEngine.shared.process(Data(flushed))
                            self.terminalView?.feed(byteArray: [UInt8](processed)[...])
                        }
                    }
                }
            }
        }

        state = .connected
        connectedAt = Date()
        latencyMs = sshConnection?.connectionLatencyMs
        delegate?.terminalController(self, didChangeState: state)
        startMetricsMonitor()
        executeStartupCommandIfNeeded()
        let tmuxCfgPJ = TmuxConfigStore.load(sessionId: sessionId)
        if tmuxCfgPJ.enabled {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run {
                    guard self?.state == .connected else { return }
                    self?.tmuxStore.detectTmux()
                }
            }
        }
    }
}
