//
//  CoreDataManager.swift
//  NearByInteractionTest
//
//  Created by 박의서 on 2023/05/07.
//

import Foundation
import CoreData
import UIKit

class CoreDataManager {
    
    static let coreDM = CoreDataManager()

    let persistentContainer: NSPersistentContainer

    init() {
        persistentContainer = NSPersistentContainer(name:"UserDataModel")
        persistentContainer.loadPersistentStores {(description, error) in
            if let error = error {
                fatalError("Core Data Store failed \(error.localizedDescription)")
            }
        }
    }


    func createUser(userName: String) {

      let user = User(context: persistentContainer.viewContext)
      user.userName = userName
      //        let profile = Profile(context: persistentContainer.viewContext)
      //        profile.nickname = userName


        do {
            try persistentContainer.viewContext.save()
        } catch {
            print("Failed to save profile \(error)")
        }
    }
    
    func createBuddy(characterName: String) {

      let buddy = Buddy(context: persistentContainer.viewContext)
      buddy.characterName = characterName

        do {
            try persistentContainer.viewContext.save()
        } catch {
            print("Failed to save profile \(error)")
        }
    }
    
//    func createKeyword(favorite: [Int]){
//
//        let keyword = Keyword(context: persistentContainer.viewContext)
//        keyword.favorite = favorite
//
//        do{
//            try persistentContainer.viewContext.save()
//        } catch {
//            print("Failed to save profile \(error)")
//        }
//
//    }
    

    func readAllUser() -> [User] {

        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()

        do{
            return try persistentContainer.viewContext.fetch(fetchRequest)
        } catch {
            return []
        }

    }
    func readAllBuddy() -> [Buddy] {
        
        let fetchRequest: NSFetchRequest<Buddy> = Buddy.fetchRequest()

        do{
            return try persistentContainer.viewContext.fetch(fetchRequest)
        } catch {
            return []
        }

    }
    
    func updateUser() {

        do{
            try persistentContainer.viewContext.save()
        } catch {
            persistentContainer.viewContext.rollback()
        }
    }

    func deleteUser(user: User) {

        persistentContainer.viewContext.delete(user)

        do{
            try persistentContainer.viewContext.save()
        } catch {
            persistentContainer.viewContext.rollback()
            print("Failed to save context \(error)")
        }
    }
}

