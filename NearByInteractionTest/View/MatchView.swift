//
//  MatchView.swift
//  NearByInteractionTest
//
//  Created by 박의서 on 2023/05/06.
//

import SwiftUI

struct MatchView: View {
    // let imageData: UIImage?
    // let keywords: [Int]
    @State var nickName: String
    @State var isDone: Bool
    
    
    // @State var myKeywords : [Int] = []
    // @State var commonKeywords : [Int] = []
    
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                VStack(spacing: 15) {
                    Text(nickName)
                    Text(String(isDone))
                }
            }
        }
        .padding()
        .onAppear {
            //      nickName = CoreDataManager.coreDM.readAllUser()[0].userName ?? ""
            //      myKeywords = CoreDataManager.coreDM.readKeyword()[0].favorite
            //commonKeywords = Array(Set(myKeywords).intersection(keywords))
        }
    }
}

struct MatchView_Previews: PreviewProvider {
    static var previews: some View {
        MatchView(nickName: "Luna", isDone: false)
            .preferredColorScheme(.dark)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
    }
}
