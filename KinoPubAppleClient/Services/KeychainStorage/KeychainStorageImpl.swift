//
//  KeychainStorageImpl.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 27.07.2023.
//

import Foundation
import KeychainAccess
import KinoPubLogging
import OSLog

final class KeychainStorageImpl: KeychainStorage {

  private lazy var keychain: Keychain = {
    return Keychain(service: "com.kunst.kinopub")
      .accessibility(.whenUnlockedThisDeviceOnly) // Enhanced security
  }()

  public func object<Value>(for key: Key<Value>) -> Value? where Value: Decodable, Value: Encodable {
    do {
      guard let data = try keychain.getData(key.rawValue) else { 
        Logger.app.debug("No data found for key: \(key.rawValue)")
        return nil 
      }
      return try JSONDecoder().decode(Value.self, from: data)
    } catch {
      Logger.app.error("Failed to retrieve object from keychain: \(error.localizedDescription)")
      return nil
    }
  }

  public func setObject<Value>(_ object: Value?, for key: Key<Value>) where Value: Decodable, Value: Encodable {
    guard let object = object else {
      removeObject(for: key)
      return
    }
    
    do {
      let data = try JSONEncoder().encode(object)
      try keychain.set(data, key: key.rawValue)
      Logger.app.debug("Successfully stored object for key: \(key.rawValue)")
    } catch {
      Logger.app.error("Failed to store object in keychain: \(error.localizedDescription)")
    }
  }
  
  private func removeObject<Value>(for key: Key<Value>) {
    do {
      try keychain.remove(key.rawValue)
      Logger.app.debug("Successfully removed object for key: \(key.rawValue)")
    } catch {
      Logger.app.error("Failed to remove object from keychain: \(error.localizedDescription)")
    }
  }
  
  func clear() {
    do {
      try keychain.removeAll()
      Logger.app.info("Successfully cleared all keychain data")
    } catch {
      Logger.app.error("Failed to clear keychain: \(error.localizedDescription)")
    }
  }
}
