//
//  CKContainerConfig.swift
//  OpenCloudKit
//
//  Created by Benjamin Johnson on 14/07/2016.
//
//

import Foundation

enum CKConfigError: Error {
    case failedInit
    case invalidJSON
}

public struct CKConfig {
    let containers: [CKContainerConfig]

    public init(containers: [CKContainerConfig]) {
        self.containers = containers
    }

    public init(container: CKContainerConfig) {
        self.containers = [container]
    }
}

public struct CKContainerConfig {
    public let containerIdentifier: String
    public let environment: CKEnvironment
    public let apnsEnvironment: CKEnvironment
    public let apiTokenAuth: String?
    public var serverToServerKeyAuth: CKServerToServerKeyAuth?

    public init(containerIdentifier: String, environment: CKEnvironment,apiTokenAuth: String, apnsEnvironment: CKEnvironment? = nil) {
        self.containerIdentifier = containerIdentifier
        self.environment = environment
        if let apnsEnvironment = apnsEnvironment {
            self.apnsEnvironment = apnsEnvironment
        } else {
            self.apnsEnvironment = environment
        }

        self.apiTokenAuth = apiTokenAuth
        self.serverToServerKeyAuth = nil
    }

    public init(containerIdentifier: String, environment: CKEnvironment, serverToServerKeyAuth: CKServerToServerKeyAuth, apnsEnvironment: CKEnvironment? = nil) {
        self.containerIdentifier = containerIdentifier
        self.environment = environment
        if let apnsEnvironment = apnsEnvironment {
            self.apnsEnvironment = apnsEnvironment
        } else {
            self.apnsEnvironment = environment
        }
        self.apiTokenAuth = nil
        self.serverToServerKeyAuth = serverToServerKeyAuth
    }
}

extension CKContainerConfig {
    var containerInfo: CKContainerInfo {
        return CKContainerInfo(containerID: containerIdentifier, environment: environment)
    }
}

public struct CKServerToServerKeyAuth {
    // A unique identifier for the key generated using CloudKit Dashboard. To create this key, read
    public let keyID: String

    //The pass phrase for the key.
    public let privateKeyPassPhrase: String?

    // DER data from the pem key
    public var privateKey: KeyData

    public init(keyID: String, privateKeyFile: String, privateKeyPassPhrase: String? = nil) throws {
        let privateKey = try KeyData(filePath: privateKeyFile)
        self.init(keyID: keyID, privateKey: privateKey, privateKeyPassPhrase: privateKeyPassPhrase)
    }

    public init(keyID: String, privateKey: KeyData, privateKeyPassPhrase: String? = nil) {
        self.keyID = keyID
        self.privateKey = privateKey
        self.privateKeyPassPhrase = privateKeyPassPhrase
    }
}
extension CKServerToServerKeyAuth:Equatable {}

public func ==(lhs: CKServerToServerKeyAuth, rhs: CKServerToServerKeyAuth) -> Bool {
    return lhs.keyID == rhs.keyID && lhs.privateKey == rhs.privateKey && lhs.privateKeyPassPhrase == rhs.privateKeyPassPhrase
}
