import SwiftUI
import UIKit

struct ShareSheetPayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onDismiss: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> ShareSheetPresenterViewController {
        let controller = ShareSheetPresenterViewController()
        controller.items = items
        controller.onDismiss = onDismiss
        return controller
    }

    func updateUIViewController(_ uiViewController: ShareSheetPresenterViewController, context: Context) {
        uiViewController.items = items
        uiViewController.onDismiss = onDismiss
    }
}

final class ShareSheetPresenterViewController: UIViewController {
    var items: [Any] = []
    var onDismiss: (() -> Void)?
    private var hasPresented = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasPresented else { return }
        hasPresented = true

        let activityController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activityController.completionWithItemsHandler = { [weak self] _, _, _, _ in
            self?.onDismiss?()
        }

        if let popover = activityController.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
            popover.permittedArrowDirections = []
        }

        present(activityController, animated: true)
    }
}
