import UIKit
import WebKit
import StoreKit

var webView: WKWebView! = nil

class ViewController: UIViewController, WKNavigationDelegate, UIDocumentInteractionControllerDelegate {
    private let storeKitBridge = StoreKitBridge()
    
    var documentController: UIDocumentInteractionController?
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
    
    @IBOutlet weak var loadingView: UIView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var connectionProblemView: UIImageView!
    @IBOutlet weak var webviewView: UIView!
    var toolbarView: UIToolbar!
    
    var htmlIsLoaded = false;
    
    private var themeObservation: NSKeyValueObservation?
    var currentWebViewTheme: UIUserInterfaceStyle = .unspecified
    override var preferredStatusBarStyle : UIStatusBarStyle {
        if #available(iOS 13, *), overrideStatusBar{
            if #available(iOS 15, *) {
                return .default
            } else {
                return statusBarTheme == "dark" ? .lightContent : .darkContent
            }
        }
        return .default
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        initWebView()
        storeKitBridge.start()
        initToolbarView()
        loadRootUrl()
    
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification , object: nil)
        
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        HangTime.webView.frame = calcWebviewFrame(webviewView: webviewView, toolbarView: nil)
    }
    
    @objc func keyboardWillHide(_ notification: NSNotification) {
        HangTime.webView.setNeedsLayout()
    }
    
    func initWebView() {
        HangTime.webView = createWebView(container: webviewView, WKSMH: self, WKND: self, NSO: self, VC: self)
        webviewView.addSubview(HangTime.webView);
        
        HangTime.webView.uiDelegate = self;
        
        HangTime.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)

        if pullToRefresh {
            #if !targetEnvironment(macCatalyst)
            let refreshControl = UIRefreshControl()
            refreshControl.addTarget(self, action: #selector(refreshWebView(_:)), for: .valueChanged)
            HangTime.webView.scrollView.addSubview(refreshControl)
            HangTime.webView.scrollView.bounces = true
            #endif
        }

        if #available(iOS 15.0, *), adaptiveUIStyle {
            themeObservation = HangTime.webView.observe(\.underPageBackgroundColor) { [weak self] webView, _ in
                guard let self else { return }
                currentWebViewTheme = webView.underPageBackgroundColor.isLight() ?? true ? .light : .dark
                self.overrideUIStyle()
            }
        }
    }

    @objc func refreshWebView(_ sender: UIRefreshControl) {
        HangTime.webView?.reload()
        sender.endRefreshing()
    }

    func createToolbarView() -> UIToolbar{
        var statusBarHeight = activeWindowScene()?.statusBarManager?.statusBarFrame.height ?? 60
        
        #if targetEnvironment(macCatalyst)
        if (statusBarHeight == 0){
            statusBarHeight = 30
        }
        #endif
        
        let toolbarView = UIToolbar(frame: CGRect(x: 0, y: 0, width: webviewView.frame.width, height: 0))
        toolbarView.sizeToFit()
        toolbarView.frame = CGRect(x: 0, y: 0, width: webviewView.frame.width, height: toolbarView.frame.height + statusBarHeight)
//        toolbarView.autoresizingMask = [.flexibleTopMargin, .flexibleRightMargin, .flexibleWidth]
        
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let close = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(loadRootUrl))
        toolbarView.setItems([close,flex], animated: true)
        
        toolbarView.isHidden = true
        
        return toolbarView
    }
    
    func overrideUIStyle(toDefault: Bool = false) {
        if #available(iOS 15.0, *), adaptiveUIStyle {
            if (((htmlIsLoaded && !HangTime.webView.isHidden) || toDefault) && self.currentWebViewTheme != .unspecified) {
                UIApplication
                    .shared
                    .connectedScenes
                    .flatMap { ($0 as? UIWindowScene)?.windows ?? [] }
                    .first { $0.isKeyWindow }?.overrideUserInterfaceStyle = toDefault ? .unspecified : self.currentWebViewTheme;
            }
        }
    }
    
    func initToolbarView() {
        toolbarView =  createToolbarView()
        
        webviewView.addSubview(toolbarView)
    }
    
    @objc func loadRootUrl() {
        HangTime.webView.load(URLRequest(url: SceneDelegate.universalLinkToLaunch ?? SceneDelegate.shortcutLinkToLaunch ?? rootUrl))
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!){
        htmlIsLoaded = true
        
        self.setProgress(1.0, true)
        self.animateConnectionProblem(false)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            HangTime.webView.isHidden = false
            self.loadingView.isHidden = true
           
            self.setProgress(0.0, false)
            
            self.overrideUIStyle()
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        htmlIsLoaded = false;
        
        if (error as NSError)._code != (-999) {
            self.overrideUIStyle(toDefault: true);

            webView.isHidden = true;
            loadingView.isHidden = false;
            animateConnectionProblem(true);
            
            setProgress(0.05, true);

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.setProgress(0.1, true);
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.loadRootUrl();
                }
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

        if (keyPath == #keyPath(WKWebView.estimatedProgress) &&
                HangTime.webView.isLoading &&
                !self.loadingView.isHidden &&
                !self.htmlIsLoaded) {
                    var progress = Float(HangTime.webView.estimatedProgress);
                    
                    if (progress >= 0.8) { progress = 1.0; };
                    if (progress >= 0.3) { self.animateConnectionProblem(false); }
                    
                    self.setProgress(progress, true);
        }
    }
    
    func setProgress(_ progress: Float, _ animated: Bool) {
        self.progressView.setProgress(progress, animated: animated);
    }
    
    
    func animateConnectionProblem(_ show: Bool) {
        if (show) {
            self.connectionProblemView.isHidden = false;
            self.connectionProblemView.alpha = 0
            UIView.animate(withDuration: 0.7, delay: 0, options: [.repeat, .autoreverse], animations: {
                self.connectionProblemView.alpha = 1
            })
        }
        else {
            UIView.animate(withDuration: 0.3, delay: 0, options: [], animations: {
                self.connectionProblemView.alpha = 0 // Here you will get the animation you want
            }, completion: { _ in
                self.connectionProblemView.isHidden = true;
                self.connectionProblemView.layer.removeAllAnimations();
            })
        }
    }
        
    deinit {
        HangTime.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
    }
}

extension UIColor {
    // Check if the color is light or dark, as defined by the injected lightness threshold.
    // Some people report that 0.7 is best. I suggest to find out for yourself.
    // A nil value is returned if the lightness couldn't be determined.
    func isLight(threshold: Float = 0.5) -> Bool? {
        let originalCGColor = self.cgColor

        // Now we need to convert it to the RGB colorspace. UIColor.white / UIColor.black are greyscale and not RGB.
        // If you don't do this then you will crash when accessing components index 2 below when evaluating greyscale colors.
        let RGBCGColor = originalCGColor.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil)
        guard let components = RGBCGColor?.components else {
            return nil
        }
        guard components.count >= 3 else {
            return nil
        }

        let brightness = Float(((components[0] * 299) + (components[1] * 587) + (components[2] * 114)) / 1000)
        return (brightness > threshold)
    }
}

extension ViewController: WKScriptMessageHandler {
  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "print" {
            printView(webView: HangTime.webView)
        }
        else if message.name == "push-subscribe" {
            handleSubscribeTouch(message: message)
        }
        else if message.name == "push-permission-request" {
            handlePushPermission()
        }
        else if message.name == "push-permission-state" {
            handlePushState()
        }
        else if message.name == "push-token" {
            handleFCMToken()
        }
        else if message.name == "iap-products-request" {
            Task {
                await storeKitBridge.fetchProducts()
            }
        }
        else if message.name == "iap-purchase-request" {
            let body = message.body as? [String: Any]
            let productID = body?["productID"] as? String
            Task {
                await storeKitBridge.purchase(productID: productID)
            }
        }
        else if message.name == "iap-transactions-request" {
            Task {
                await storeKitBridge.refreshEntitlements()
            }
        }
        else if message.name == "iap-restore-request" {
            Task {
                await storeKitBridge.restorePurchases()
            }
        }
  }
}

private struct StoreKitSubscriptionPeriod: Encodable {
    let value: Int
    let unit: String
}

private struct StoreKitProductPayload: Encodable {
    let id: String
    let displayName: String
    let description: String
    let displayPrice: String
    let price: String
    let currencyCode: String
    let subscriptionPeriod: StoreKitSubscriptionPeriod?
}

private struct StoreKitTransactionPayload: Encodable {
    let productID: String
    let transactionID: String
    let originalTransactionID: String
    let purchaseDate: Date
    let expirationDate: Date?
}

private struct StoreKitProductsResponse: Encodable {
    let products: [StoreKitProductPayload]
    let error: String?
}

private struct StoreKitEntitlementsResponse: Encodable {
    let entitlements: [StoreKitTransactionPayload]
    let hasActiveSubscription: Bool
    let legacyPaidAppPurchase: Bool
}

private struct StoreKitPurchaseResponse: Encodable {
    let status: String
    let transaction: StoreKitTransactionPayload?
    let error: String?
}

private struct StoreKitRestoreResponse: Encodable {
    let status: String
    let error: String?
}

@MainActor
private final class StoreKitBridge {
    private static let monthlySubscriptionProductID = "subscription"
    private static let yearlySubscriptionProductID = "subscription_yearly"
    private static let subscriptionProductIDs: Set<String> = [
        monthlySubscriptionProductID,
        yearlySubscriptionProductID
    ]
    private static let freeAppCutoffDate = Date(timeIntervalSince1970: 1_784_503_448)

    private var products: [Product] = []
    private var transactionUpdates: Task<Void, Never>?

    deinit {
        transactionUpdates?.cancel()
    }

    func start() {
        guard transactionUpdates == nil else { return }

        transactionUpdates = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = result else { continue }

                await transaction.finish()
                await self?.refreshEntitlements()
            }
        }
    }

    func fetchProducts() async {
        do {
            products = try await Product.products(for: Self.subscriptionProductIDs)
                .filter(isSupportedSubscription)

            dispatch(
                eventName: "iap-products-result",
                payload: StoreKitProductsResponse(
                    products: products.map(productPayload),
                    error: products.isEmpty ? "The subscriptions are not available." : nil
                )
            )
        } catch {
            products = []
            dispatch(
                eventName: "iap-products-result",
                payload: StoreKitProductsResponse(products: [], error: error.localizedDescription)
            )
        }
    }

    func purchase(productID: String?) async {
        guard let productID, Self.subscriptionProductIDs.contains(productID) else {
            dispatchPurchase(status: "failed", error: "Invalid subscription product.")
            return
        }

        if products.isEmpty {
            do {
                products = try await Product.products(for: Self.subscriptionProductIDs)
                    .filter(isSupportedSubscription)
            } catch {
                dispatchPurchase(status: "failed", error: error.localizedDescription)
                return
            }
        }

        guard let product = products.first(where: { $0.id == productID }) else {
            dispatchPurchase(status: "failed", error: "The selected subscription is not available.")
            return
        }

        do {
            switch try await product.purchase() {
            case .success(let verificationResult):
                guard case .verified(let transaction) = verificationResult else {
                    dispatchPurchase(status: "failed", error: "The App Store transaction could not be verified.")
                    return
                }

                await transaction.finish()
                await refreshEntitlements()
                dispatchPurchase(status: "success", transaction: transactionPayload(transaction))
            case .userCancelled:
                dispatchPurchase(status: "cancelled")
            case .pending:
                dispatchPurchase(status: "pending")
            @unknown default:
                dispatchPurchase(status: "failed", error: "The App Store returned an unknown purchase status.")
            }
        } catch {
            dispatchPurchase(status: "failed", error: error.localizedDescription)
        }
    }

    func refreshEntitlements() async {
        var entitlements: [StoreKitTransactionPayload] = []

        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard Self.subscriptionProductIDs.contains(transaction.productID) else { continue }

            entitlements.append(transactionPayload(transaction))
        }

        dispatch(
            eventName: "iap-transactions-result",
            payload: StoreKitEntitlementsResponse(
                entitlements: entitlements,
                hasActiveSubscription: !entitlements.isEmpty,
                legacyPaidAppPurchase: await hasLegacyPaidAppPurchase()
            )
        )
    }

    private func hasLegacyPaidAppPurchase() async -> Bool {
        guard #available(iOS 16.0, *) else {
            return false
        }

        do {
            guard case .verified(let appTransaction) = try await AppTransaction.shared else {
                return false
            }

            return appTransaction.originalPurchaseDate < Self.freeAppCutoffDate
        } catch {
            return false
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            dispatch(
                eventName: "iap-restore-result",
                payload: StoreKitRestoreResponse(status: "success", error: nil)
            )
        } catch {
            dispatch(
                eventName: "iap-restore-result",
                payload: StoreKitRestoreResponse(status: "failed", error: error.localizedDescription)
            )
        }
    }

    private func productPayload(_ product: Product) -> StoreKitProductPayload {
        StoreKitProductPayload(
            id: product.id,
            displayName: product.displayName,
            description: product.description,
            displayPrice: product.displayPrice,
            price: NSDecimalNumber(decimal: product.price).stringValue,
            currencyCode: product.priceFormatStyle.currencyCode,
            subscriptionPeriod: subscriptionPeriodPayload(product.subscription?.subscriptionPeriod)
        )
    }

    private func isSupportedSubscription(_ product: Product) -> Bool {
        guard product.type == .autoRenewable else { return false }
        guard let period = product.subscription?.subscriptionPeriod else { return false }
        guard period.value == 1 else { return false }
        return period.unit == .month || period.unit == .year
    }

    private func subscriptionPeriodPayload(
        _ period: Product.SubscriptionPeriod?
    ) -> StoreKitSubscriptionPeriod? {
        guard let period else { return nil }

        let unit: String
        switch period.unit {
        case .day:
            unit = "day"
        case .week:
            unit = "week"
        case .month:
            unit = "month"
        case .year:
            unit = "year"
        @unknown default:
            unit = "unknown"
        }

        return StoreKitSubscriptionPeriod(value: period.value, unit: unit)
    }

    private func transactionPayload(_ transaction: StoreKit.Transaction) -> StoreKitTransactionPayload {
        StoreKitTransactionPayload(
            productID: transaction.productID,
            transactionID: String(transaction.id),
            originalTransactionID: String(transaction.originalID),
            purchaseDate: transaction.purchaseDate,
            expirationDate: transaction.expirationDate
        )
    }

    private func dispatchPurchase(
        status: String,
        transaction: StoreKitTransactionPayload? = nil,
        error: String? = nil
    ) {
        dispatch(
            eventName: "iap-purchase-result",
            payload: StoreKitPurchaseResponse(status: status, transaction: transaction, error: error)
        )
    }

    private func dispatch<Payload: Encodable>(eventName: String, payload: Payload) {
        guard let webView = HangTime.webView else { return }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(payload)
            let payloadObject = try JSONSerialization.jsonObject(with: data)

            Task {
                do {
                    _ = try await webView.callAsyncJavaScript(
                        "window.dispatchEvent(new CustomEvent(eventName, { detail: payload }))",
                        arguments: ["eventName": eventName, "payload": payloadObject],
                        in: nil,
                        contentWorld: .page
                    )
                } catch {
                    print("StoreKit web event failed: \(error.localizedDescription)")
                }
            }
        } catch {
            print("StoreKit response encoding failed: \(error.localizedDescription)")
        }
    }
}
