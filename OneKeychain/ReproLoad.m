//
//  ReproLoad.m — AAP-21412 reproduction
//
//  Runs at image load (a C constructor), the earliest possible point, so it overlaps the
//  BrowserStackInjector's own init (SwiftPatchLoader.startMocking / cleanKeyChain) and can
//  re-enter its still-in-flight dispatch_once via getTeamIdentifier. Uses a group.* App-Group
//  access-group keychain query (the path that reaches replaceTeamIdentifier -> getTeamIdentifier),
//  plus a concurrent burst to widen the window and exercise the process-global-flag race (item-4).
//

#import <Foundation/Foundation.h>
#import <Security/Security.h>

static void aap21412_hit(void) {
  NSDictionary *q = @{
    (__bridge id)kSecClass:           (__bridge id)kSecClassGenericPassword,
    (__bridge id)kSecAttrAccount:     @"aap21412",
    (__bridge id)kSecAttrAccessGroup: @"group.com.browserstack.onekeychain.repro",
    (__bridge id)kSecReturnData:      (__bridge id)kCFBooleanTrue,
    (__bridge id)kSecMatchLimit:      (__bridge id)kSecMatchLimitOne,
  };
  CFTypeRef r = NULL;
  SecItemCopyMatching((__bridge CFDictionaryRef)q, &r);
  if (r) { CFRelease(r); }
}

__attribute__((constructor))
static void aap21412_repro_load(void) {
  aap21412_hit();  // synchronous, earliest point — overlaps the injector's init
  for (int i = 0; i < 16; i++) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
      for (int k = 0; k < 300; k++) { aap21412_hit(); }
    });
  }
}
