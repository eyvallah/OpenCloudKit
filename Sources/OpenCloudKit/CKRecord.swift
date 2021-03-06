//
//  CKRecord.swift
//  OpenCloudKit
//
//  Created by Benjamin Johnson on 6/07/2016.
//
//

import Foundation

public let CKRecordTypeUserRecord: String = "Users"
public protocol CKRecordFieldProvider {
    var recordFieldDictionary: [String: Any] { get }
}
/*
extension CKRecordFieldProvider where Self: CustomDictionaryConvertible {
    public var recordFieldDictionary: [String: Any] {
        return ["value": self.dictionary]
    }
}
*/

public class CKRecord: NSObject, NSSecureCoding {

    var values: [String: CKRecordValue] = [:]

    public let recordType: String

    public let recordID: CKRecordID

    public var recordChangeTag: String?

    /* This is a User Record recordID, identifying the user that created this record. */
    public var creatorUserRecordID: CKRecordID?

    public var creationDate = Date()

    /* This is a User Record recordID, identifying the user that last modified this record. */
    public var lastModifiedUserRecordID: CKRecordID?

    public var modificationDate: Date?

    private var changedKeysSet = NSMutableSet()

    public var parent: CKReference?

    public convenience init(recordType: String) {
        let UUID = NSUUID().uuidString
        self.init(recordType: recordType, recordID: CKRecordID(recordName: UUID))
    }

    public init(recordType: String, recordID: CKRecordID) {
        self.recordID = recordID
        self.recordType = recordType
    }

    public func object(forKey key: String) -> CKRecordValue? {
        return values[key]
    }

    public func setObject(_ object: CKRecordValue?, forKey key: String) {

        let containsKey = changedKeysSet.contains(key)


        if !containsKey {
            changedKeysSet.add(key)
        }

        switch object {
        case let asset as CKAsset:
            asset.recordID = self.recordID
        default:
            break
        }

        values[key] = object
    }

    public func allKeys() -> [String] {
       return Array(values.keys)
    }

    public subscript(key: String) -> CKRecordValue? {
        get {
            return object(forKey: key)
        }
        set(newValue) {
            setObject(newValue, forKey: key)
        }
    }

    public func changedKeys() -> [String] {
        return changedKeysSet.compactMap { $0 as? String }
    }


    override public var description: String {
        return "<\(type(of: self)): ; recordType = \(recordType);recordID = \(recordID); values = \(values)>"
    }

    public override var debugDescription: String {
        return"<\(type(of: self)); recordType = \(recordType);recordID = \(recordID); values = \(values)>"
    }

    init?(recordDictionary: [String: Any], recordID: CKRecordID? = nil) {

        guard let recordName = recordDictionary[CKRecordDictionary.recordName] as? String,
            let recordType = recordDictionary[CKRecordDictionary.recordType] as? String
            else {
                return nil
        }

        // Parse ZoneID Dictionary into CKRecordZoneID
        let zoneID: CKRecordZoneID
        if let zoneIDDictionary = recordDictionary[CKRecordDictionary.zoneID] as? [String: Any] {
            zoneID = CKRecordZoneID(dictionary: zoneIDDictionary)!
        } else {
            zoneID = CKRecordZoneID(zoneName: CKRecordZoneDefaultName, ownerName: "_defaultOwner")
        }

        if let recordID = recordID {
            self.recordID = recordID
        } else {
            let recordID = CKRecordID(recordName: recordName, zoneID: zoneID)
            self.recordID = recordID
        }

        self.recordType = recordType

        // Parse Record Change Tag
        if let changeTag = recordDictionary[CKRecordDictionary.recordChangeTag] as? String {
            recordChangeTag = changeTag
        }

        // Parse Created Dictionary
        if let createdDictionary = recordDictionary[CKRecordDictionary.created] as? [String: Any], let created = CKRecordLog(dictionary: createdDictionary) {
            self.creatorUserRecordID = CKRecordID(recordName: created.userRecordName)
            self.creationDate = Date(timeIntervalSince1970: Double(created.timestamp) / 1000)
        }

        // Parse Modified Dictionary
        if let modifiedDictionary = recordDictionary[CKRecordDictionary.modified] as? [String: Any], let modified = CKRecordLog(dictionary: modifiedDictionary) {
            self.lastModifiedUserRecordID = CKRecordID(recordName: modified.userRecordName)
            self.modificationDate = Date(timeIntervalSince1970: Double(modified.timestamp) / 1000)
        }

        // Enumerate Fields
        if let fields = recordDictionary[CKRecordDictionary.fields] as? [String: [String: Any]] {
            for (key, fieldValue) in fields  {
                let value = CKRecord.getValue(forRecordField: fieldValue)
                values[key] = value
            }
        }

        if let parentReferenceDictionary = recordDictionary["parent"] as? [String: Any], let recordName = parentReferenceDictionary["parent"] as? String {

            let recordID = CKRecordID(recordName: recordName, zoneID: zoneID)
            let reference = CKReference(recordID: recordID, action: .none)
            parent = reference
        }
    }

    public required init?(coder: NSCoder) {
        recordType = coder.decodeObject(of: NSString.self, forKey: "RecordType")! as String
        recordID = coder.decodeObject(of: CKRecordID.self, forKey: "RecordID")!
        recordChangeTag = coder.decodeObject(of: NSString.self, forKey: "ETag") as String?
        creatorUserRecordID = coder.decodeObject(of: CKRecordID.self, forKey: "CreatorUserRecordID")
        creationDate = coder.decodeObject(of: NSDate.self, forKey: "RecordCtime")! as Date
        lastModifiedUserRecordID = coder.decodeObject(of: CKRecordID.self, forKey: "LastModifiedUserRecordID")
        modificationDate = coder.decodeObject(of: NSDate.self, forKey: "RecordMtime") as Date?
        parent = coder.decodeObject(of: CKReference.self, forKey: "ParentReference")
        // TODO: changed keys set
    }

    public func encode(with coder: NSCoder) {
        coder.encode(recordType, forKey: "RecordType")
        coder.encode(recordID, forKey: "RecordID")
        coder.encode(recordChangeTag, forKey: "ETag")
        coder.encode(creatorUserRecordID, forKey: "CreatorUserRecordID")
        coder.encode(creationDate, forKey: "RecordCtime")
        coder.encode(lastModifiedUserRecordID, forKey: "LastModifiedUserRecordID")
        coder.encode(modificationDate, forKey: "RecordMtime")
        coder.encode(parent, forKey: "ParentReference")
        // TODO: changed keys set
    }

    public static var supportsSecureCoding: Bool {
        return true
    }

    public func encodeSystemFields(with coder: NSCoder) {
        encode(with: coder)
    }
}

struct CKRecordDictionary {
    static let recordName = "recordName"
    static let recordType = "recordType"
    static let recordChangeTag = "recordChangeTag"
    static let fields = "fields"
    static let zoneID = "zoneID"
    static let modified = "modified"
    static let created = "created"
}

struct CKRecordFieldDictionary {
    static let value = "value"
    static let type = "type"
}

struct CKValueType {
    static let string = "STRING"
    static let data = "BYTES"
}

struct CKRecordLog {
    let timestamp: UInt64 // milliseconds
    let userRecordName: String
    let deviceID: String

    init?(dictionary: [String: Any]) {
        guard let timestamp = (dictionary["timestamp"] as? NSNumber)?.uint64Value, let userRecordName = dictionary["userRecordName"] as? String, let deviceID =  dictionary["deviceID"] as? String else {
            return nil
        }

        self.timestamp = timestamp
        self.userRecordName = userRecordName
        self.deviceID = deviceID
    }
}

extension CKRecord {

    func fieldsDictionary(forKeys keys: [String]) -> [String: Any] {

        var fieldsDictionary: [String: Any] = [:]

        for key in keys {
            if let value = object(forKey: key) {
                fieldsDictionary[key] = value.recordFieldDictionary
            }
        }

        CloudKit.debugPrint(fieldsDictionary)


        return fieldsDictionary

    }

    var dictionary: [String: Any] {

        // Add Fields
        var fieldsDictionary: [String: Any] = [:]
        for (key, value) in values {
            fieldsDictionary[key] = value.recordFieldDictionary
        }

        var recordDictionary: [String: Any] = [
        "fields": fieldsDictionary,
        "recordType": recordType,
        "recordName": recordID.recordName
        ]

        if let parent = parent {
            recordDictionary["createShortGUID"] = NSNumber(value: 1)
            recordDictionary["parent"] = ["recordName": parent.recordID.recordName]
        }

        return recordDictionary
    }

    static func recordValue(forValue value: Any) -> CKRecordValue {
        switch value {
        case let number as NSNumber:
           return number

        default:
            fatalError("Not Supported")
        }
    }

    static func process(number: NSNumber, type: String) -> CKRecordValue {
        switch(type) {
        case "TIMESTAMP":
            return NSDate(timeIntervalSince1970: number.doubleValue / 1000)
        default:
            return number
        }
    }

    static func getValue(forRecordField field: [String: Any]) -> CKRecordValue? {
        if  let value = field[CKRecordFieldDictionary.value],
            let type = field[CKRecordFieldDictionary.type] as? String {

            switch value {
            case let number as NSNumber:
                return process(number: number, type: type)

            case let intValue as Int:
                let number = NSNumber(value: intValue)
                return process(number: number, type: type)

            case let doubleValue as Double:
                let number = NSNumber(value: doubleValue)
                return process(number: number, type: type)

            case let dictionary as [String: Any]:
                switch type {

                case "LOCATION":
                    return CKLocation(dictionary: dictionary)
                case "ASSETID":
                    // size
                    // downloadURL
                    // fileChecksum
                    return CKAsset(dictionary: dictionary)
                case "REFERENCE":
                    return CKReference(dictionary: dictionary)
                default:
                    fatalError("Type not supported")
                }

            case let boolean as Bool:
                return NSNumber(booleanLiteral: boolean)

            case let string as String:
                switch type {
                case CKValueType.string:
                    return string
                case CKValueType.data:
                    return NSData(base64Encoded: string, options: [])
                default:
                    return string
                }

            case let array as [Any]:
                switch type {
                case "INT64_LIST":
                    return array as! [Int64]
                case "DOUBLE_LIST":
                    return array as! [Double]
                case "STRING_LIST":
                    return array as! [String]
                case "TIMESTAMP_LIST":
                    return (array as! [Double]).map { item -> Date in
                        return Date(timeIntervalSince1970: item / 1000)
                    }
                case "LOCATION_LIST":
                    return (array as! [[String: Any]]).map { item -> CKLocation in
                        return CKLocation(dictionary: item)
                    }
                case "REFERENCE_LIST":
                    return (array as! [[String: Any]]).map { item -> CKReference in
                        return CKReference(dictionary: item)!
                    }
                case "ASSETID_LIST":
                    return (array as! [[String: Any]]).map { item -> CKAsset in
                        return CKAsset(dictionary: item)!
                    }
                default:
                    fatalError("List type of \(type) not supported")
                }

            default:
                return nil
            }
        } else {
            return nil
        }
    }
}

public protocol CKRecordValue : CKRecordFieldProvider {
    static var typeName: String? { get }
    var dictionaryValue: Any { get }
}

extension CKRecordValue {
    public var recordFieldDictionary: [String : Any] {
        if let type = Self.typeName {
            return ["value": dictionaryValue, "type": type]
        }
        return ["value": dictionaryValue]
    }
}

private protocol CKRecordValueType: CKRecordValue {
    associatedtype MappedType
    associatedtype TransformedType

    var valueProvider: MappedType { get }
    func transform(_ value: MappedType) -> TransformedType
}

extension CKRecordValueType {
    public var dictionaryValue: Any {
        return transform(valueProvider)
    }
}

private protocol CKRecordValueString: CKRecordValueType where MappedType == String, TransformedType == String {}

extension CKRecordValueString {
    public static var typeName: String? { return "STRING" }

    public func transform(_ value: MappedType) -> TransformedType {
        return value
    }
}

private protocol CKRecordValueInt64: CKRecordValueType where MappedType == Int64, TransformedType == Int64 {}

extension CKRecordValueInt64 {
    public static var typeName: String? { return "INT64" }

    public func transform(_ value: MappedType) -> TransformedType {
        return value
    }
}

private protocol CKRecordValueDouble: CKRecordValueType where MappedType == Double, TransformedType == Double {}

extension CKRecordValueDouble {
    public static var typeName: String? { return "DOUBLE" }

    public func transform(_ value: MappedType) -> TransformedType {
        return value
    }
}

private protocol CKRecordValueDate: CKRecordValueType where MappedType == Date, TransformedType == Int64 {}

extension CKRecordValueDate {
    public static var typeName: String? { return "TIMESTAMP" }

    public func transform(_ value: MappedType) -> TransformedType {
        return Int64(value.timeIntervalSince1970 * 1000)
    }
}

private protocol CKRecordValueData: CKRecordValueType where MappedType == Data, TransformedType == String {}

extension CKRecordValueData {
    public static var typeName: String? { return "BYTES" }

    public func transform(_ value: MappedType) -> TransformedType {
        return value.base64EncodedString()
    }
}

private protocol CKRecordValueAsset: CKRecordValueType where MappedType == [String: Any], TransformedType == [String: Any] {}

extension CKRecordValueAsset {
    public static var typeName: String? { return "ASSETID" }

    public func transform(_ value: MappedType) -> TransformedType {
        return value
    }
}

private protocol CKRecordValueReference: CKRecordValueType where MappedType == [String: Any], TransformedType == [String: Any] {}

extension CKRecordValueReference {
    public static var typeName: String? { return "REFERENCE" }

    public func transform(_ value: MappedType) -> TransformedType {
        return value
    }
}

private protocol CKRecordValueLocation: CKRecordValueType where MappedType == CKLocation, TransformedType == [String: Any] {}

extension CKRecordValueLocation {
    public static var typeName: String? { return "LOCATION" }

    public func transform(_ value: MappedType) -> TransformedType {
        return value.dictionary
    }
}

extension NSString: CKRecordValueString {
    public var valueProvider: String { return self as String }
}

extension String: CKRecordValueString {
    public var valueProvider: String { self }
}

extension Int64: CKRecordValueInt64 {
    public var valueProvider: Int64 { return Int64(self) }
}
extension Int32: CKRecordValueInt64 {
    public var valueProvider: Int64 { return Int64(self) }
}

extension Int16: CKRecordValueInt64 {
    public var valueProvider: Int64 { return Int64(self) }
}

extension Int8: CKRecordValueInt64 {
    public var valueProvider: Int64 { return Int64(self) }
}

extension Int: CKRecordValueInt64 {
    public var valueProvider: Int64 { return Int64(self) }
}

extension UInt64: CKRecordValueInt64 {
    public var valueProvider: Int64 { return Int64(self) }
}

extension UInt32: CKRecordValueInt64 {
    public var valueProvider: Int64 { return Int64(self) }
}

extension UInt16: CKRecordValueInt64 {
    public var valueProvider: Int64 { return Int64(self) }
}

extension UInt8: CKRecordValueInt64 {
    public var valueProvider: Int64 { return Int64(self) }
}

extension UInt: CKRecordValueInt64 {
    public var valueProvider: Int64 { return Int64(self) }
}

extension Bool: CKRecordValueInt64 {
    public var valueProvider: Int64 { return self ? 1 : 0 }
}

extension Double: CKRecordValueDouble {
    public var valueProvider: Double { return Double(self) }
}

extension Float: CKRecordValueDouble {
    public var valueProvider: Double { return Double(self) }
}

extension NSDate: CKRecordValueDate {
    public var valueProvider: Date { return self as Date }
}

extension Date: CKRecordValueDate {
    public var valueProvider: Date { return self }
}

extension NSData : CKRecordValueData {
    public var valueProvider: Data { return self as Data }
}

extension Data : CKRecordValueData {
    public var valueProvider: Data { return self }
}

extension CKAsset: CKRecordValueAsset {
    public var valueProvider: [String : Any] {
        return dictionary
    }
}

extension CKReference: CKRecordValueReference {
    public var valueProvider: [String : Any] {
        return dictionary
    }
}

extension CKLocation: CKRecordValueLocation {
    public var valueProvider: CKLocation {
        return self
    }
}

extension NSNumber: CKRecordValue {
    public static var typeName: String? { return nil }
    public var dictionaryValue: Any { return self }
}

extension Array: CKRecordFieldProvider, CKRecordValue where Element: CKRecordValue {
    public static var typeName: String? {
        if let firstItemTypeName = Element.typeName {
            return "\(firstItemTypeName)_LIST"
        }
        return nil
    }

    public var dictionaryValue: Any {
        return map { $0.dictionaryValue }
    }
}
