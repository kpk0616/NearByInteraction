//
//  Character+CoreDataProperties.swift
//  NearByInteractionTest
//
//  Created by 박의서 on 2023/05/07.
//
//

import Foundation
import CoreData


extension Buddy {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Buddy> {
        return NSFetchRequest<Buddy>(entityName: "Buddy")
    }

    @NSManaged public var characterName: String?

}

extension Buddy : Identifiable {

}
