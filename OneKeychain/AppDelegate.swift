//
//  AppDelegate.swift
//  OneKeychain
//
//  AAP-21412 repro build. Migrated to Swift 5 + a launch-time group.* keychain burst.
//

import UIKit
import Security

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?

  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    // AAP-21412 (item-4): concurrent group.* access-group keychain reads at launch.
    // The load-time constructor in ReproLoad.m fires even earlier (overlapping the injector init).
    ReproKeychain.fireConcurrentBurst()
    return true
  }
}

/// AAP-21412 repro helper — group.* (App-Group) access-group keychain access.
enum ReproKeychain {
  static let accessGroup = "group.com.browserstack.onekeychain.repro"

  static func hit() {
    let query: [String: Any] = [
      kSecClass as String:          kSecClassGenericPassword,
      kSecAttrAccount as String:    "aap21412",
      kSecAttrAccessGroup as String: accessGroup,   // group.* ⇒ injector replaceTeamIdentifier → getTeamIdentifier
      kSecReturnData as String:     kCFBooleanTrue as Any,
      kSecMatchLimit as String:     kSecMatchLimitOne,
    ]
    var result: CFTypeRef?
    _ = SecItemCopyMatching(query as CFDictionary, &result)
  }

  /// Many concurrent threads hammering the group.* keychain at launch: reproduces the
  /// process-global-flag race (a concurrent app read losing its access-group rewrite).
  static func fireConcurrentBurst() {
    for _ in 0..<16 {
      DispatchQueue.global().async { for _ in 0..<300 { hit() } }
    }
  }
}
