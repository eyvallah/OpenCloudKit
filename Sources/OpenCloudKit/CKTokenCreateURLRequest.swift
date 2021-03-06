//
//  CKTokenCreateURLRequest.swift
//  OpenCloudKit
//
//  Created by Benjamin Johnson on 19/1/17.
//
//

import Foundation

class CKTokenCreateURLRequest: CKURLRequest {
    let apnsEnvironment: CKEnvironment

    override var serverType: CKServerType {
        return .device
    }

    init(apnsEnvironment: CKEnvironment) {
        self.apnsEnvironment = apnsEnvironment

        super.init()
        self.operationType = .tokens
        path = "create"
        // self.serverType = .device
    }
}

public struct CKPushTokenInfo {
    public let apnsToken: Data
    public let apnsEnvironment: CKEnvironment
    public let webcourierURL: URL

    init?(dictionaryRepresentation dictionary: [String: Any]) {
        guard
            let apnsEnvironmentString = dictionary["apnsEnvironment"] as? String,
            let apnsToken = dictionary["apnsToken"] as? String,
            let webcourierURLString = dictionary["webcourierURL"] as? String,
            let environment = CKEnvironment(rawValue: apnsEnvironmentString),
            let url = URL(string: webcourierURLString),
            let data = Data(base64Encoded: apnsToken) else {
            return nil
        }

        self.apnsToken = data
        self.apnsEnvironment = environment
        self.webcourierURL = url
    }

}

class CKTokenCreateOperation: CKOperation {
    let apnsEnvironment: CKEnvironment

    init(apnsEnvironment: CKEnvironment) {
        self.apnsEnvironment = apnsEnvironment
    }

    var createTokenCompletionBlock: ((CKPushTokenInfo?, Error?) -> ())?
    var info : CKPushTokenInfo?

    var bodyDictionaryRepresentation: [String: Any] {
        return ["apnsEnvironment": "\(apnsEnvironment)"]
    }

    override func finishOnCallbackQueue(error: Error?) {
        createTokenCompletionBlock?(info, error)

        super.finishOnCallbackQueue(error: error)
    }

    override func performCKOperation() {
        let request = CKTokenCreateURLRequest(apnsEnvironment: apnsEnvironment)
        request.accountInfoProvider = CloudKit.shared.account(forContainer: operationContainer)
        request.requestProperties = bodyDictionaryRepresentation

        request.completionBlock = { [weak self] result in
            guard let strongSelf = self else { return }

            var returnError: Error?

            defer {
                strongSelf.finish(error: returnError)
            }

            guard !strongSelf.isCancelled else { return }

            switch result {
            case .success(let dictionary):
                strongSelf.info = CKPushTokenInfo(dictionaryRepresentation: dictionary)!
            case .error(let error):
                returnError = error.error
            }
        }
        request.performRequest()
    }
}
