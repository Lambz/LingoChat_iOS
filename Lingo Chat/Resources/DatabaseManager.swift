//
//  DatabaseManager.swift
//  Lingo Chat
//
//  Created by Chetan on 2020-08-11.
//  Copyright © 2020 Chetan. All rights reserved.
//

import Foundation
import FirebaseDatabase
import FirebaseAuth

struct ChatListData {
    let name: String
    let id: String
    let image: String
    let email: String
    let language: String
}


final class DatabaseManager {
    static let shared = DatabaseManager()
    private let database = Database.database().reference()
    public static let dateformatter: DateFormatter = {
        let dateformatter = DateFormatter()
        dateformatter.dateStyle = .medium
        dateformatter.timeStyle = .long
        dateformatter.locale = .current
        return dateformatter
    }()
}

//MARK: Transcation menthods for user details (login/logut/user data) implemented

extension DatabaseManager {
    
//    verification methods for account creation
    
///   verifies weather user account with same email exists
    public func userAccountExists(with email: String, completion: @escaping ((Bool) -> Void)) {
        guard let userID = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        database.child("Users").queryOrdered(byChild: userID).observeSingleEvent(of: .childAdded) { (snapshot) in
            guard snapshot.value as? String != nil else {
                print("user does not exists")
                completion(false)
                return
            }
            print(snapshot.value ?? "no value")
            print("user exists")
            completion(true)
        }
    }
    
    
//    insert methods
    
/// insert new user account user
    public func insertUser(with user: UserAccount) {
        guard let userID = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        database.child("Users").child(userID).setValue([
            "first_name": user.firstName,
            "last_name": user.lastName,
            "email": user.email,
            "image": user.image,
            "lang": user.language
            ])
     }
    
    
    

    
//    update methods
    
    
    public func insertPreferences(image: String, language: String) {
        guard let userID = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        database.child("Users").child(userID).updateChildValues(["image": image])
        
        database.child("Users").child(userID).updateChildValues(["lang": language])
    }
    
    
    public func updateProfile(firstName: String, lastName: String) {
        guard let userID = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        database.child("Users").child(userID).updateChildValues(["first_name": firstName])
        
        database.child("Users").child(userID).updateChildValues(["last_name": lastName])
    }
    
    public func updateLanguage(language: String) {
        guard let userID = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        database.child("Users").child(userID).updateChildValues(["lang": language])
    }
    
    public func updateImageUrl(image: String) {
        guard let userID = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        database.child("Users").child(userID).updateChildValues(["image": image])
    }
    
//    deletion methods
    
    
    
    
//    query methods
    
    public func getUserDetails(completion: @escaping (Result<[String], Error>) -> Void) {
        guard let userID = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        database.child("Users").child(userID).observeSingleEvent(of: .value) { (snapshot) in
            guard let value = snapshot.value as? [String: String] else {
                completion(.failure(DatabaseErrors.failedToFetchData))
                return
            }
            var returnArray: [String] = []
            returnArray.append(value["first_name"] ?? "")
            returnArray.append(value["last_name"] ?? "")
            returnArray.append(value["image"] ?? "")
            returnArray.append(value["lang"] ?? "")
            returnArray.append(userID)
            completion(.success(returnArray))
        }
    }
    
    public func fetchAllUsers(completion: @escaping (Result<[UserAccount], Error>) -> Void) {
        let userEmail = FirebaseAuth.Auth.auth().currentUser?.email?.lowercased()
        database.child("Users").observeSingleEvent(of: .value) { (snapshot) in
            var users = [UserAccount]()
            for case let child as DataSnapshot in snapshot.children {
                guard let item = child.value as? [String:String] else {
                    print("Error")
                    completion(.failure(DatabaseErrors.failedToFetchData))
                    return
                }
                if item["email"]!.lowercased() == userEmail {
                    continue
                }
                let user = UserAccount(firstName: item["first_name"]!, lastName: item["last_name"]!, email: item["email"]!, image: item["image"]!, language: item["lang"]!)
                users.append(user)
            }
            completion(.success(users))
        }
    }
    
}

//MARK: Message methods implemeted
extension DatabaseManager {
    
    public func sendMesage(to otherUser: String, message: Message, completion: @escaping (Bool) -> Void) {
        guard let userID = FirebaseAuth.Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        var link = "", text = ""
        switch message.kind {
        case .text(let message):
            text = message
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .audio(_):
            break
        default: break
        }
        let randomID = database.childByAutoId().key!
        database.child("Messages").child(userID).child(otherUser).child(randomID).setValue([
            "from": userID,
            "id": randomID,
            "lang": UserDefaults.standard.object(forKey: "language") as! String,
            "link": link,
            "text": text,
            "to": otherUser,
            "type": message.kind.messageKindString
            ], withCompletionBlock: { [weak self] error, _ in
                guard let strongSelf = self, error == nil else {
                    completion(false)
                    return
                }
                strongSelf.database.child("Messages").child(otherUser).child(userID).child(randomID).setValue([
                    "from": userID,
                    "id": randomID,
                    "lang": UserDefaults.standard.object(forKey: "language") as! String,
                    "link": link,
                    "text": text,
                    "to": otherUser,
                    "type": message.kind.messageKindString
                    ], withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                })
        })
    }
    
    
//    query methods
    public func getUserIdFromEmail(email: String, completion: @escaping (Result<String, Error>) -> Void) {
        database.child("Users").queryOrdered(byChild: "email").queryEqual(toValue: email).observeSingleEvent(of: .childAdded) { (snapshot) in
            completion(.success(snapshot.key))
        }
    }
    
    public func getAllConversations(completion: @escaping(Result<[ChatListData], Error>) -> Void) {
        guard let userID = FirebaseAuth.Auth.auth().currentUser?.uid else {
            completion(.failure(DatabaseErrors.failedToFetchData))
            return
        }
        var users = [String]()
        database.child("Messages").child(userID).observeSingleEvent(of: .value) { [weak self](snapshot) in
            for case let otherUser as DataSnapshot in snapshot.children {
                users.append(otherUser.key)
            }
            if !users.isEmpty {
                self?.getUserDetailsFromId(users: users, completion: { (result) in
                    switch result {
                    case .success(let list):
                        completion(.success(list))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                })
            }
            
        }
       
    }
    
    private func getUserDetailsFromId(users: [String], completion: @escaping(Result<[ChatListData], Error>) -> Void) {
        database.child("Users").observe(.value) { (snapshot) in
            var returnArray = [ChatListData]()
            for case let otherUser as DataSnapshot in snapshot.children {
                if users.contains(otherUser.key) {
                    guard let item = otherUser.value as? [String:String] else {
                        print("Error")
                        completion(.failure(DatabaseErrors.failedToFetchData))
                        return
                    }
                    
                    let name = item["first_name"]! + " " + item["last_name"]!
                    let chat = ChatListData(name: name, id: otherUser.key, image: item["image"]!, email: item["email"]!, language: item["lang"]!)
                    returnArray.append(chat)
                }
                
            }
            completion(.success(returnArray))
        }
    }
    
    public func getLastMessage(with user: String, completion: @escaping(Result<String, Error>) -> Void) {
        guard let userID = FirebaseAuth.Auth.auth().currentUser?.uid else {
            completion(.failure(DatabaseErrors.failedToFetchData))
            return
        }
        database.child("Messages").child(userID).child(user).queryLimited(toLast: 1).observe(.childAdded, with: { (msg) in
            guard let message = msg.value as? [String: String] else {
                completion(.failure(DatabaseErrors.failedToFetchData))
                return
            }
            
            switch(message["type"]) {
            case "text":
                completion(.success(message["text"]!))
                return
            case "image":
                completion(.success("Image"))
                return
            case "video":
                completion(.success("Video"))
                return
            case "location":
                completion(.success("Location shared"))
                return
            default: completion(.failure(DatabaseErrors.failedToFetchData))
            return
            }
        })
    }
    
    public func getAllMessagesForConversation(with id: String, completion: @escaping(String) -> Void) {
        
    }
    
}


public enum DatabaseErrors: Error {
    case failedToFetchData
    case referenceError
}


struct UserAccount {
    let firstName: String
    let lastName: String
    let email: String
    let image: String
    let language: String
}
