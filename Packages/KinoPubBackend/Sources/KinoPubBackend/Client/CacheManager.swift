//
//  CacheManager.swift
//  KinoPubBackend
//
//  Created by AI Assistant on 01.07.2025.
//

import Foundation

// MARK: - Cache Manager Protocol
public protocol CacheManaging {
  func get<T: Codable>(for key: String, type: T.Type) -> T?
  func set<T: Codable>(_ object: T, for key: String, ttl: TimeInterval?)
  func remove(for key: String)
  func clear()
}

// MARK: - Cache Entry
private struct CacheEntry<T: Codable>: Codable {
  let value: T
  let timestamp: Date
  let ttl: TimeInterval?
  
  var isExpired: Bool {
    guard let ttl = ttl else { return false }
    return Date().timeIntervalSince(timestamp) > ttl
  }
}

// MARK: - Memory Cache Manager
public final class MemoryCacheManager: CacheManaging {
  private var cache: [String: Any] = [:]
  private let queue = DispatchQueue(label: "com.kinopub.cache", attributes: .concurrent)
  
  public init() {}
  
  public func get<T: Codable>(for key: String, type: T.Type) -> T? {
    return queue.sync {
      guard let entry = cache[key] as? CacheEntry<T> else { return nil }
      
      if entry.isExpired {
        cache.removeValue(forKey: key)
        return nil
      }
      
      return entry.value
    }
  }
  
  public func set<T: Codable>(_ object: T, for key: String, ttl: TimeInterval? = nil) {
    queue.async(flags: .barrier) {
      let entry = CacheEntry(value: object, timestamp: Date(), ttl: ttl)
      self.cache[key] = entry
    }
  }
  
  public func remove(for key: String) {
    queue.async(flags: .barrier) {
      self.cache.removeValue(forKey: key)
    }
  }
  
  public func clear() {
    queue.async(flags: .barrier) {
      self.cache.removeAll()
    }
  }
}

// MARK: - Cache Policy
public enum CachePolicy {
  case noCache
  case memoryOnly(ttl: TimeInterval)
  case networkFirst
  case cacheFirst
  
  var ttl: TimeInterval? {
    switch self {
    case .memoryOnly(let ttl):
      return ttl
    default:
      return nil
    }
  }
}

// MARK: - Cacheable Request
public protocol CacheableRequest {
  var cacheKey: String { get }
  var cachePolicy: CachePolicy { get }
}

// MARK: - Default Implementation
public extension CacheableRequest where Self: Endpoint {
  var cacheKey: String {
    let parametersString = parameters?.description ?? "nil"
    return "\(path)_\(method)_\(parametersString)"
  }
  
  var cachePolicy: CachePolicy {
    switch method {
    case "GET":
      return .memoryOnly(ttl: 300) // 5 minutes
    default:
      return .noCache
    }
  }
} 