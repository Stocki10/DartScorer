import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins
import AVFoundation
import MultipeerConnectivity

// MARK: - QR Host View
// Shown from within the New Game Dialog when hosting a session.

struct QRHostView: View {
    @ObservedObject var session: MultipeerSessionManager
    @Binding var inputMode: InputMode
    @Binding var undoPermission: UndoPermission
    let players: [Player]
    let onDismiss: () -> Void

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        if let payload = session.qrPayload, let img = qrImage(from: payload) {
                            Image(uiImage: img)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 180, height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        Text(session.sessionToken)
                            .font(.system(.title3, design: .monospaced).bold())
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            } header: {
                Text("Share this QR code with other players")
            }

            Section(L10n.format("Connected Devices (%@/4)", "\(session.connectedPeers.count + 1)")) {
                Label("This device (Host)", systemImage: "iphone")
                ForEach(session.connectedPeers, id: \.displayName) { peer in
                    HStack {
                        Label(peer.displayName, systemImage: "iphone")
                        Spacer()
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
            }

            Section(L10n.string("Multiplayer Settings")) {
                Picker("Input Mode", selection: $inputMode) {
                    ForEach(InputMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: inputMode) { _, mode in
                    session.updateSessionConfig(inputMode: mode, undoPermission: undoPermission)
                }

                Text(inputMode.explanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Picker("Undo", selection: $undoPermission) {
                    ForEach(UndoPermission.allCases) { permission in
                        Text(permission.label).tag(permission)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: undoPermission) { _, permission in
                    session.updateSessionConfig(inputMode: inputMode, undoPermission: permission)
                }
            }

            Section(L10n.string("Player Assignments")) {
                let hostEntry = (id: session.deviceID, name: "This device (Host)")
                let peerEntries = session.peerDisplayNames.map { (id: $0.key, name: $0.value) }
                    .sorted { $0.name < $1.name }
                let devices = [hostEntry] + peerEntries

                ForEach(players, id: \.id) { player in
                    let currentDeviceID = assignedDeviceID(for: player.id, in: session.playerAssignments)
                    HStack {
                        Circle()
                            .fill(player.colorHex.flatMap { Color(hex: $0) } ?? Color.accentColor)
                            .frame(width: 12, height: 12)
                        Text(player.name)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { currentDeviceID ?? "" },
                            set: { session.setPlayerAssignment(playerID: player.id, toDeviceID: $0) }
                        )) {
                            Text("Unassigned").tag("")
                            ForEach(devices, id: \.id) { device in
                                Text(device.name).tag(device.id)
                            }
                        }
                        .labelsHidden()
                    }
                }
            }
        }
        .navigationTitle("Hosting")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { session.endSession(); onDismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { onDismiss() }
                    .fontWeight(.semibold)
                    .disabled(!allPlayersAssigned)
            }
        }
    }

    private var allPlayersAssigned: Bool {
        guard session.inputMode != .free else { return true }
        return players.allSatisfy { player in
            assignedDeviceID(for: player.id, in: session.playerAssignments) != nil
        }
    }

    private func assignedDeviceID(for playerID: UUID, in assignments: [String: [String]]) -> String? {
        let pidStr = playerID.uuidString
        for (devID, playerIDs) in assignments {
            if playerIDs.contains(pidStr) { return devID }
        }
        return nil
    }

    private func qrImage(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let ci = filter.outputImage else { return nil }
        let scaled = ci.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - QR Joiner View
// Shown from within the New Game Dialog when joining a session.
// Three visual states: scanning → connecting → joined (waiting) → game starting.

struct QRJoinerView: View {
    @ObservedObject var session: MultipeerSessionManager
    let onDismiss: () -> Void

    var body: some View {
        Group {
            if session.gameHasStarted {
                startingBody
            } else if !session.connectedPeers.isEmpty {
                joinedBody
            } else if session.role == .joiner {
                connectingBody
            } else {
                scannerBody
            }
        }
        .navigationTitle("Join Game")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { session.endSession(); onDismiss() }
            }
        }
    }

    // MARK: Scanner

    private var scannerBody: some View {
        VStack(spacing: 16) {
            Text("Point the camera at the host's QR code")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 16)
            QRScannerRepresentable { session.joinSession(qrPayload: $0) }
                .frame(maxWidth: .infinity, maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            Spacer()
        }
    }

    // MARK: Connecting (QR scanned, waiting for handshake)

    private var connectingBody: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView().scaleEffect(1.5)
            Text("Connecting…")
                .font(.headline)
            Text("Establishing a secure connection with the host")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal)
    }

    // MARK: Joined (connected, waiting for host to start)

    private var joinedBody: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Joined Game")
                .font(.title.bold())
            Text("Waiting for host to start…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(L10n.format("Connected to %@", session.connectedPeers.first?.displayName ?? L10n.string("host")))
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
            Spacer()
        }
        .padding(.horizontal)
    }

    // MARK: Game Starting

    private var startingBody: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("Game Starting")
                .font(.title.bold())
            Spacer()
        }
    }
}

// MARK: - Inline New Game Multiplayer Views

struct InlineHostLobbyView: View {
    @ObservedObject var session: MultipeerSessionManager
    @Binding var inputMode: InputMode
    @Binding var undoPermission: UndoPermission
    let players: [Player]

    private var allPlayersAssigned: Bool {
        players.allSatisfy { player in
            assignedDeviceID(for: player.id, in: session.playerAssignments) != nil
        }
    }

    private var connectedDeviceCount: Int {
        session.connectedPeers.count + 1
    }

    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.format("Hosting: %@", session.sessionToken))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(L10n.format("%@ Players Connected", "\(session.connectedPeers.count + 1)"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            if let payload = session.qrPayload, let image = qrImage(from: payload) {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 160, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Text(session.sessionToken)
                            .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.string("Connected Players"))
                    .font(.subheadline.weight(.semibold))

                connectedDeviceRow(
                    name: L10n.string("This device (Host)"),
                    isHost: true
                )

                ForEach(session.connectedPeers, id: \.displayName) { peer in
                    connectedDeviceRow(name: peer.displayName, isHost: false)
                }
            }
            .padding(.top, 4)

            Picker("Input Mode", selection: $inputMode) {
                ForEach(InputMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: inputMode) { _, mode in
                session.updateSessionConfig(inputMode: mode, undoPermission: undoPermission)
            }

            Text(inputMode.explanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, -4)

            Picker("Undo", selection: $undoPermission) {
                ForEach(UndoPermission.allCases) { permission in
                    Text(permission.label).tag(permission)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: undoPermission) { _, permission in
                session.updateSessionConfig(inputMode: inputMode, undoPermission: permission)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L10n.string("Manage Players"))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }

                if players.count > connectedDeviceCount {
                    Text(L10n.string("You can assign multiple players to one device."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                let hostEntry = (id: session.deviceID, name: L10n.string("This device (Host)"))
                let peerEntries = session.peerDisplayNames.map { (id: $0.key, name: $0.value) }
                    .sorted { $0.name < $1.name }
                let devices = [hostEntry] + peerEntries

                ForEach(players, id: \.id) { player in
                    let currentDeviceID = assignedDeviceID(for: player.id, in: session.playerAssignments)
                    HStack(spacing: 12) {
                        Circle()
                            .fill(player.colorHex.flatMap { Color(hex: $0) } ?? Color(.systemGray4))
                            .frame(width: 12, height: 12)
                        Text(player.name)
                            .lineLimit(1)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { currentDeviceID ?? "" },
                            set: { session.setPlayerAssignment(playerID: player.id, toDeviceID: $0) }
                        )) {
                            Text(L10n.string("Unassigned")).tag("")
                            ForEach(devices, id: \.id) { device in
                                Text(device.name).tag(device.id)
                            }
                        }
                        .labelsHidden()
                    }
                }

                if inputMode != .free && !allPlayersAssigned {
                    Text(L10n.string("All players need to be assigned."))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                        .padding(.top, 2)
                }
            }
            .padding(.top, 4)
        }
    }

    private func assignedDeviceID(for playerID: UUID, in assignments: [String: [String]]) -> String? {
        let pidStr = playerID.uuidString
        for (devID, playerIDs) in assignments {
            if playerIDs.contains(pidStr) { return devID }
        }
        return nil
    }

    private func qrImage(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let ci = filter.outputImage else { return nil }
        let scaled = ci.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    private func connectedDeviceRow(name: String, isHost: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isHost ? "iphone.gen3" : "iphone")
                .foregroundStyle(.tint)

            Text(name)
                .font(.subheadline)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }
}

struct InlineJoinLobbyView: View {
    @ObservedObject var session: MultipeerSessionManager
    @Binding var isScannerVisible: Bool
    let scannerResetID: UUID
    let onDisconnect: () -> Void

    var body: some View {
        Group {
            if session.gameHasStarted {
                statusCard(
                    icon: "checkmark.circle.fill",
                    title: L10n.string("Game Starting"),
                    message: nil,
                    tint: .green
                )
            } else if !session.connectedPeers.isEmpty {
                statusCard(
                    icon: "checkmark.circle",
                    title: L10n.string("Joined Game"),
                    message: L10n.string("Waiting for host to start…"),
                    tint: .accentColor
                )

                Text(L10n.format("Connected to %@", session.connectedPeers.first?.displayName ?? L10n.string("host")))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button(L10n.string("Leave Session"), role: .destructive, action: onDisconnect)
            } else if session.role == .joiner {
                statusCard(
                    icon: "wifi",
                    title: L10n.string("Connecting…"),
                    message: L10n.string("Establishing a secure connection with the host"),
                    tint: .secondary
                )

                Button(L10n.string("Leave Session"), role: .destructive, action: onDisconnect)
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isScannerVisible.toggle()
                    }
                } label: {
                    Label(L10n.string("Scan QR"), systemImage: "camera")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)

                if isScannerVisible {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.string("Point the camera at the host's QR code"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        QRScannerRepresentable { session.joinSession(qrPayload: $0) }
                            .id(scannerResetID)
                            .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private func statusCard(icon: String, title: String, message: String?, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}


// MARK: - QR Scanner (AVFoundation UIViewRepresentable)

private struct QRScannerRepresentable: UIViewRepresentable {
    let onScan: (String) -> Void
    func makeUIView(context: Context) -> QRScannerView { let v = QRScannerView(); v.onScan = onScan; return v }
    func updateUIView(_ uiView: QRScannerView, context: Context) {}
}

private final class QRScannerView: UIView {
    var onScan: ((String) -> Void)?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard superview != nil else {
            tearDownScanner()
            return
        }
        startScanning()
    }

    private func startScanning() {
        guard captureSession == nil else { return }
        let s = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device), s.canAddInput(input) else { return }
        s.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard s.canAddOutput(output) else { return }
        s.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        let preview = AVCaptureVideoPreviewLayer(session: s)
        preview.videoGravity = .resizeAspectFill
        layer.addSublayer(preview)
        previewLayer = preview
        DispatchQueue.global(qos: .userInitiated).async { s.startRunning() }
        captureSession = s
    }

    private func tearDownScanner() {
        captureSession?.stopRunning()
        captureSession = nil
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }

    deinit {
        tearDownScanner()
    }
}

extension QRScannerView: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let obj = objects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        tearDownScanner()
        onScan?(value)
    }
}
