//
//  PlayWeRuinedIt.swift
//  PlayTools
//
//  Created by Venti on 16/01/2023.
//

import Foundation
import Security

// Implementation for PlayKeychain
// World's Most Advanced Keychain Replacement Solution:tm:
// This is a joke, don't take it seriously

public class PlayKeychain: NSObject {
    static let shared = PlayKeychain()
    private static let db = PlayKeychainDB.shared

    @objc public static func debugLogger(_ logContent: String) {
        if PlaySettings.shared.settingsData.playChainDebugging {
            NSLog("PC-DEBUG: \(logContent)")
        }
    }
    // Emulates SecItemAdd, SecItemUpdate, SecItemDelete and SecItemCopyMatching
    // Store the entire dictionary as a plist
    // SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result)
    @objc static public func add(_ attributes: NSDictionary, result: UnsafeMutablePointer<Unmanaged<CFTypeRef>?>?) -> OSStatus {
        let keychainDict = db.insert(attributes)
        if keychainDict == nil {
            debugLogger("Failed to write keychain file")
            // Don't return errSecIO — game crashes on non-success.
            // Fall through to still handle result construction.
        } else {
            debugLogger("Wrote keychain item to db")
        }
        // Place v_Data in the result
        guard let vData = attributes["v_Data"] as? CFTypeRef else {
            return errSecSuccess
        }

        if attributes["r_Attributes"] as? Int == 1 {
            // Create a dummy dictionary and return it
            let dummyDict = keychainDict ?? NSMutableDictionary()
            if attributes["r_Data"] as? Int != 1 {
                dummyDict.removeObject(forKey: kSecValueData)
                dummyDict.removeObject(forKey: kSecValueRef)
                dummyDict.removeObject(forKey: kSecValuePersistentRef)
            }
            result?.pointee = Unmanaged.passRetained(dummyDict)
            return errSecSuccess
        }

        // Handle r_PersistentRef: return a synthetic persistent reference (CFData)
        // that encodes the key info so it can be looked up later via v_PersistentRef
        if attributes["r_PersistentRef"] as? Int == 1 {
            if attributes["class"] as? String == "keys" {
                guard let keyData = vData as? Data else { return errSecSuccess }
                let keyType = attributes["type"] ?? kSecAttrKeyTypeRSA
                let keyClass = attributes["kcls"] ?? kSecAttrKeyClassPublic
                let persistentInfo: NSDictionary = [
                    "v_Data": keyData,
                    "type": keyType,
                    "kcls": keyClass,
                    "_playchain_persistent_ref": true
                ]
                if let persistentRef = try? PropertyListSerialization.data(
                    fromPropertyList: persistentInfo, format: .binary, options: 0) {
                    result?.pointee = Unmanaged.passRetained(persistentRef as CFData)
                }
                return errSecSuccess
            }
            // Non-key items: return v_Data as the persistent ref
            result?.pointee = Unmanaged.passRetained(vData)
            return errSecSuccess
        }

        if attributes["class"] as? String == "keys" {
            // Only reconstruct SecKeyRef if caller wants a result
            guard let result = result else { return errSecSuccess }
            guard let keyData = vData as? Data else { return errSecSuccess }
            let keyType = attributes["type"] ?? kSecAttrKeyTypeRSA
            let keyClass = attributes["kcls"] ?? kSecAttrKeyClassPublic
            let keyAttributes = [
                kSecAttrKeyType: keyType,
                kSecAttrKeyClass: keyClass
            ] as CFDictionary
            if let key = SecKeyCreateWithData(keyData as CFData, keyAttributes, nil) {
                result.pointee = Unmanaged.passRetained(key)
            }
            return errSecSuccess
        }
        result?.pointee = Unmanaged.passRetained(vData)
        return errSecSuccess
    }

    // SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributesToUpdate)
    @objc static public func update(_ query: NSDictionary, attributesToUpdate: NSDictionary) -> OSStatus {
        guard let keychainDict = db.query(query)?.first else {
            debugLogger("Keychain item not found in db")
            return errSecItemNotFound
        }
        debugLogger("Select keychain item from db")
        // Reconstruct the dictionary (subscripting won't work as assignment is not allowed)
        let newKeychainDict = NSMutableDictionary()
        for (key, value) in keychainDict {
            newKeychainDict.setValue(value, forKey: key as! String) // swiftlint:disable:this force_cast
        }
        // Update the dictionary
        for (key, value) in attributesToUpdate {
            newKeychainDict.setValue(value, forKey: key as! String) // swiftlint:disable:this force_cast
        }
        guard db.update(newKeychainDict) else {
            debugLogger("Failed to update keychain item to db")
            return errSecIO
        }

        return errSecSuccess
    }

    // SecItemDelete(CFDictionaryRef query)
    @objc static public func delete(_ query: NSDictionary) -> OSStatus {
        guard db.query(query)?.first != nil else {
            debugLogger("Failed to find keychain item")
            return errSecItemNotFound
        }
        guard db.delete(query) else {
            debugLogger("Failed to delete keychain item")
            return errSecIO
        }
        debugLogger("Deleted keychain item in db")
        return errSecSuccess
    }

    // SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result)
    @objc static public func copyMatching(_ query: NSDictionary, result: UnsafeMutablePointer<Unmanaged<CFTypeRef>?>?)
    -> OSStatus {
        // Handle v_PersistentRef lookups: the query contains a synthetic persistent ref
        // from a previous SecItemAdd with r_PersistentRef=1. Decode it directly without DB.
        if let persistentRefData = query["v_PersistentRef"] as? Data,
           let info = try? PropertyListSerialization.propertyList(from: persistentRefData, format: nil) as? NSDictionary,
           info["_playchain_persistent_ref"] != nil {
            debugLogger("Resolving synthetic persistent ref")
            if query["r_Ref"] as? Int == 1 {
                guard let keyData = info["v_Data"] as? Data else {
                    return errSecItemNotFound
                }
                let keyType = info["type"] ?? kSecAttrKeyTypeRSA
                let keyClass = info["kcls"] ?? kSecAttrKeyClassPublic
                let keyAttrs = [
                    kSecAttrKeyType: keyType,
                    kSecAttrKeyClass: keyClass
                ] as CFDictionary
                if let key = SecKeyCreateWithData(keyData as CFData, keyAttrs, nil) {
                    result?.pointee = Unmanaged.passRetained(key)
                    return errSecSuccess
                }
            }
            // r_Data: return the raw key data
            if let keyData = info["v_Data"] as? Data {
                result?.pointee = Unmanaged.passRetained(keyData as CFData)
                return errSecSuccess
            }
            return errSecItemNotFound
        }
        // If v_PersistentRef is set but not our synthetic format (e.g. a SecKeyRef from old run),
        // try to return it directly for r_Ref queries
        if query["v_PersistentRef"] != nil && query[kSecClass as String] == nil {
            debugLogger("v_PersistentRef query with no class, returning not found")
            return errSecItemNotFound
        }

        guard let keychainDicts = db.query(query),
              let keychainDict = keychainDicts.first else {
            debugLogger("Keychain item not found in db")
            return errSecItemNotFound
        }

        if query[kSecMatchLimit as String] as? String ==  kSecMatchLimitAll as String {
            result?.pointee = Unmanaged.passRetained(keychainDicts.map({
                $0.removeObject(forKey: kSecValueData)
                $0.removeObject(forKey: kSecValueRef)
                $0.removeObject(forKey: kSecValuePersistentRef)
                return $0
            }) as CFTypeRef)
            return errSecSuccess
        }
        // Check the `r_Attributes` key. If it is set to 1 in the query
        let classType = query[kSecClass as String] as? String ?? ""

        if query["r_Attributes"] as? Int == 1 {
            // Create a dummy dictionary and return it
            let dummyDict = keychainDict
            if query["r_Data"] as? Int != 1 {
                dummyDict.removeObject(forKey: kSecValueData)
                dummyDict.removeObject(forKey: kSecValueRef)
                dummyDict.removeObject(forKey: kSecValuePersistentRef)
            }
            result?.pointee = Unmanaged.passRetained(dummyDict)
            return errSecSuccess
        }

        // Check for r_Ref
        if query["r_Ref"] as? Int == 1 {
            // Return the data on v_PersistentRef or v_Data if they exist
            var key: CFTypeRef?
            if let vData = keychainDict[kSecValueData] {
                NSLog("found v_Data")
                debugLogger("Read keychain item from db")
                key = vData as CFTypeRef
            }
            if let vPersistentRef = keychainDict[kSecValuePersistentRef] {
                NSLog("found persistent ref")
                debugLogger("Read keychain item from db")
                key = vPersistentRef as CFTypeRef
            }

            if key == nil {
                debugLogger("Keychain item not found in db")
                return errSecItemNotFound
            }

            let dummyKeyAttrs = [
                kSecAttrKeyType: keychainDict[kSecAttrKeyType] ?? kSecAttrKeyTypeRSA,
                kSecAttrKeyClass: keychainDict[kSecAttrKeyClass] ?? kSecAttrKeyClassPublic
            ] as CFDictionary

            guard let keyData = key as? Data,
                  let secKey = SecKeyCreateWithData(keyData as CFData, dummyKeyAttrs, nil) else {
                return errSecItemNotFound
            }
            result?.pointee = Unmanaged.passRetained(secKey)
            return errSecSuccess
        }

        // Return v_Data if it exists
        if let vData = keychainDict[kSecValueData] {
            debugLogger("Read keychain file from db")
            // Check the class type, if it is a key we need to return the data
            // as SecKeyRef, otherwise we can return it as a CFTypeRef
            if classType == "keys" {
                let keyAttributes = [
                    kSecAttrKeyType: keychainDict[kSecAttrKeyType] ?? kSecAttrKeyTypeRSA,
                    kSecAttrKeyClass: keychainDict[kSecAttrKeyClass] ?? kSecAttrKeyClassPublic
                ] as CFDictionary
                guard let keyData = vData as? Data,
                      let key = SecKeyCreateWithData(keyData as CFData, keyAttributes, nil) else {
                    return errSecItemNotFound
                }
                result?.pointee = Unmanaged.passRetained(key)
                return errSecSuccess
            }
            result?.pointee = Unmanaged.passRetained(vData as CFTypeRef)
            return errSecSuccess
        }

        return errSecItemNotFound
    }
}
