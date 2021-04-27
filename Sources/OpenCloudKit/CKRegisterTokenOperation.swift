//
//  CKRegisterTokenOperation.swift
//  OpenCloudKit
//
//  Created by Ben Johnson on 15/07/2016.
//
//

import Foundation

class CKRegisterTokenOperation : CKOperation {
    
    let apnsEnvironment: CKEnvironment
    
    let apnsToken: Data
    
    var tokenInfo: CKPushTokenInfo?
    
    public var registerTokenCompletionBlock: ((CKPushTokenInfo?, Error?) -> Void)?
    
    init(apnsEnvironment:CKEnvironment, apnsToken: Data) {
        
        self.apnsEnvironment = apnsEnvironment
        
        self.apnsToken = apnsToken

        super.init()
        
    }
    
    override func finishOnCallbackQueue(error: Error?) {
        registerTokenCompletionBlock?(tokenInfo, error)
        
        super.finishOnCallbackQueue(error: error)
    }
    
    override func performCKOperation() {
        let request = CKTokenRegistrationURLRequest(token: apnsToken, apnsEnvironment: "\(apnsEnvironment)")
        request.completionBlock = { [weak self] result in
            guard let strongSelf = self else { return }

            var returnError: Error?

            defer {
                strongSelf.finish(error: returnError)
            }

            guard !strongSelf.isCancelled else { return }

            switch result {
            case .success(let dictionary):
                strongSelf.tokenInfo = CKPushTokenInfo(dictionaryRepresentation: dictionary)
                CloudKit.debugPrint(dictionary)
            case .error(let error):
                returnError = error.error
            }
        }
        
        request.performRequest()
    }
}
