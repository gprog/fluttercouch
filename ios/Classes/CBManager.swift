//
//  CBManager.swift
//  Runner
//
//  Created by Luca Christille on 14/08/18.
//  Copyright © 2018 The Chromium Authors. All rights reserved.
//

import Foundation
import CouchbaseLiteSwift

class CBManager {
    static let instance = CBManager();
    private var mDatabase : Dictionary<String, Database> = Dictionary();
    private var mReplConfig : ReplicatorConfiguration! = nil;
    private var mReplicator : Replicator! = nil;
    private var defaultDatabase = "defaultDatabase";
    
    private init() {}
    
    func getDatabase() -> Database? {
        if let result = mDatabase[defaultDatabase] {
            return result;
        } else {
            return nil;
        }
    }
    
    func getDatabase(name : String) -> Database? {
        if let result = mDatabase[name] {
            return result;
        } else {
            return nil;
        }
    }
    
    func saveDocument(map: Dictionary<String, Any>) throws -> String? {
        let mutableDocument: MutableDocument = MutableDocument(data: map);
        try mDatabase[defaultDatabase]?.saveDocument(mutableDocument)
        return mutableDocument.id;
    }
    
    func saveDocumentWithId(id : String, map: Dictionary<String, Any>) throws -> String? {
        let mutableDocument: MutableDocument = MutableDocument(id: id, data: map)
        try mDatabase[defaultDatabase]?.saveDocument(mutableDocument)
        return mutableDocument.id
    }
    
    func getDocumentWithId(id : String) -> NSDictionary? {
        let resultMap: NSMutableDictionary = NSMutableDictionary.init()
        if let defaultDb: Database = getDatabase() {
            if let document: Document = defaultDb.document(withID: id) {
                let retrievedDocument: NSDictionary = NSDictionary.init(dictionary: document.toDictionary())
                // It is a repetition due to implementation of Document Dart Class
                resultMap["id"] = id
                resultMap["doc"] = retrievedDocument
            } else {
                resultMap["id"] = id
                resultMap["doc"] = NSDictionary.init()
            }
        }
        return NSDictionary.init(dictionary: resultMap)
    }

    func getDocumentsWith(key : String, value: String) -> NSDictionary? {
        let resultMap: NSMutableDictionary = NSMutableDictionary();
        if let defaultDb: Database = getDatabase() {
            let query = QueryBuilder
                .select(SelectResult.all(), SelectResult.expression(Meta.id))
                .from(DataSource.database(defaultDb))
                .where(Expression.property(key).equalTo(Expression.string(value)))
            do {
                let result = try query.execute()
                let docs = result.allResults().map{(result)->NSDictionary in
                    let ret = NSMutableDictionary();
                    if let doc = result.dictionary(forKey: defaultDb.name ?? defaultDatabase) {
                        ret["doc"] = doc.toDictionary();
                        let id = result.string(forKey: "id");
                        ret["id"] = id
                    }
                    return ret;
                    };
                resultMap["docs"] = docs;
            } catch {
                resultMap["docs"] = nil;
            }
        }
        return resultMap;
    }


    func getAllDocuments() -> NSDictionary {
        let resultMap: NSMutableDictionary = NSMutableDictionary();
        if let defaultDb: Database = getDatabase() {
            let query = QueryBuilder
                .select(SelectResult.all(), SelectResult.expression(Meta.id))
                .from(DataSource.database(defaultDb))
            do {
                let result = try query.execute()
                let docs = result.allResults().map{(result)->NSDictionary in
                    let ret = NSMutableDictionary();
                    if let doc = result.dictionary(forKey: defaultDb.name ?? defaultDatabase) {
                        ret["doc"] = doc.toDictionary();
                        let id = result.string(forKey: "id");
                        ret["id"] = id
                    }
                    return ret;
                    };
                resultMap["docs"] = docs;
            } catch {
                resultMap["docs"] = nil;
            }
        }
        return resultMap;
    }
    
    func purgeDocument(docId: String) -> Bool {
        if let defaultDb: Database = getDatabase() {
            if let doc: Document = defaultDb.document(withID: docId) {
                try! defaultDb.purgeDocument(doc);
                return true;
            }
        }
        return false;
    }

    func initDatabaseWithName(name: String){
        if mDatabase.keys.contains(name) {
            defaultDatabase = name
        } else {
            do {
                let newDatabase = try Database(name: name)
                // Database.setLogLevel(level: LogLevel.verbose, domain: LogDomain.replicator)
                mDatabase[name] = newDatabase
                defaultDatabase = name
            } catch {
                print("Error initializing new database")
            }
        }
    }
    
    func setReplicatorEndpoint(endpoint: String) {
        let targetEndpoint = URLEndpoint(url: URL(string: endpoint)!)
        mReplConfig = ReplicatorConfiguration(database: getDatabase()!, target: targetEndpoint)
    }
    
    func setReplicatorType(type: String) -> String {
        var settedType: ReplicatorType = ReplicatorType.pull
        if (type == "PUSH") {
            settedType = .push
        } else if (type == "PULL") {
            settedType = .pull
        } else if (type == "PUSH_AND_PULL") {
            settedType = .pushAndPull
        }
        mReplConfig?.replicatorType = settedType
        switch(mReplConfig?.replicatorType.rawValue) {
        case (0):
            return "PUSH_AND_PULL"
        case (1):
            return "PUSH"
        case(2):
            return "PULL"
        default:
            return ""
        }
    }
    
    func setReplicatorAuthentication(auth: [String:String]) -> String {
        if let username = auth["username"], let password = auth["password"] {
            mReplConfig?.authenticator = BasicAuthenticator(username: username, password: password)
        }
        return mReplConfig.authenticator.debugDescription
    }
    
    func setReplicatorSessionAuthentication(sessionID: String?) {
        if ((sessionID) != nil) {
            if ((mReplConfig) != nil) {
            mReplConfig.authenticator = SessionAuthenticator(sessionID: sessionID!)
            }
        }
    }
    
    func setReplicatorContinuous(isContinuous: Bool) -> Bool {
        if ((mReplConfig) != nil) {
            mReplConfig?.continuous = isContinuous
            return mReplConfig!.continuous
        }
        return false
    }
    
    func initReplicator() {
        mReplicator = Replicator(config: mReplConfig)
    }
    
    func startReplication() {
        if ((mReplicator) != nil) {
            mReplicator.start()
        }
    }
    
    func stopReplication() {
        if ((mReplicator) != nil) {
            mReplicator.stop()
            mReplicator = nil
        }
    }
    
    func getReplicator() -> Replicator {
        return mReplicator
    }
}
