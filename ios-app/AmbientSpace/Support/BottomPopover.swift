import SwiftUI
import UIKit

extension View {
    func bottomPopover<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        background(BottomPopoverAnchor(isPresented: isPresented, content: content()))
    }
}

// SwiftUI's arrowEdge is only a preference on older SDKs. UIKit lets both
// controls require an upward-pointing arrow, placing the panel below the button.
private struct BottomPopoverAnchor<Content: View>: UIViewRepresentable {
    @Binding var isPresented: Bool
    let content: Content

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }

    func makeCoordinator() -> Coordinator { Coordinator(isPresented: $isPresented) }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.isPresented = $isPresented
        context.coordinator.update(anchor: view, content: content, presented: isPresented)
    }

    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
        coordinator.host?.dismiss(animated: false)
    }

    final class Coordinator: NSObject, UIPopoverPresentationControllerDelegate {
        var isPresented: Binding<Bool>
        var host: UIHostingController<AnyView>?

        init(isPresented: Binding<Bool>) { self.isPresented = isPresented }

        func update(anchor: UIView, content: Content, presented: Bool) {
            guard presented else {
                host?.dismiss(animated: !UIAccessibility.isReduceMotionEnabled)
                host = nil
                return
            }
            guard let window = anchor.window else { return }
            let width = min(330, window.bounds.width - 32)
            let anchorFrame = anchor.convert(anchor.bounds, to: window)
            let height = max(100, window.bounds.height - window.safeAreaInsets.bottom - anchorFrame.maxY - 24)
            let root = AnyView(
                ViewThatFits(in: .vertical) {
                    content.fixedSize(horizontal: false, vertical: true)
                    ScrollView { content }.scrollBounceBehavior(.basedOnSize)
                }
                .frame(width: width)
                .frame(maxHeight: height)
            )
            if let host {
                host.rootView = root
                return
            }
            var responder: UIResponder? = anchor
            while let current = responder, !(current is UIViewController) {
                responder = current.next
            }
            guard let presenter = responder as? UIViewController,
                  presenter.presentedViewController == nil else { return }

            let controller = UIHostingController(rootView: root)
            controller.modalPresentationStyle = .popover
            controller.sizingOptions = .preferredContentSize
            controller.preferredContentSize = controller.sizeThatFits(in: CGSize(width: width, height: height))
            controller.view.backgroundColor = .clear
            guard let popover = controller.popoverPresentationController else { return }
            popover.sourceView = anchor
            popover.sourceRect = anchor.bounds
            popover.permittedArrowDirections = .up
            popover.delegate = self
            self.host = controller
            presenter.present(controller, animated: !UIAccessibility.isReduceMotionEnabled)
        }

        func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle { .none }

        func adaptivePresentationStyle(
            for controller: UIPresentationController,
            traitCollection: UITraitCollection
        ) -> UIModalPresentationStyle { .none }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            host = nil
            isPresented.wrappedValue = false
        }

        func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
            host = nil
            isPresented.wrappedValue = false
        }
    }
}
