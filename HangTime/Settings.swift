import WebKit

struct Cookie {
    var name: String
    var value: String
}

let gcmMessageIDKey = "292866814265" // update this with actual ID if using Firebase

// URL for first launch
let rootUrl = URL(string: "https://hangtime.stevie-ray.nl/?utm_source=homescreen")!

// allowed origin is for what we are sticking to pwa domain
// This should also appear in Info.plist
let allowedOrigins: [String] = ["hangtime.stevie-ray.nl"]

// auth origins will open in modal and show toolbar for back into the main origin.
// These should also appear in Info.plist
let authOrigins: [String] = ["accounts.google.com","appleid.apple.com","identitytoolkit.googleapis.com","hangtime-app.firebaseapp.com","hangtime-app.appspot.com"]
// allowedOrigins + authOrigins <= 10

let platformCookie = Cookie(name: "app-platform", value: "iOS App Store")

// UI options
let displayMode = "standalone" // standalone / fullscreen.
let adaptiveUIStyle = true     // iOS 15+ only. Change app theme on the fly to dark/light related to WebView background color.
let overrideStatusBar = false   // iOS 13-14 only. if you don't support dark/light system theme.
let statusBarTheme = "dark"    // dark / light, related to override option.
let pullToRefresh = true    // Enable/disable pull down to refresh page
