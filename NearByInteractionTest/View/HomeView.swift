//
//  ContentView.swift
//  NearByInteractionTest
//
//  Created by 박의서 on 2023/05/06.
//

import SwiftUI

struct HomeView: View {
  @State private var nickname: String = ""
  
  let localNetAuth = LocalNetworkAuthorization() // mpc를 위한 클래스 생성
  @State var isLocalNetworkPermissionDenied = false // network 권한 여부 확인하는 부울값
  @State var isLaunched = true // 처음 실행할 때 네트워크 통신하도록 하는 부울값
  @Environment(\.scenePhase) var scenePhase // ??
  @StateObject var niObject = NISessionManager() // NIObject 생성
    var body: some View {
        VStack {
          // 이름 입력 창
          TextField("", text: $nickname)
            .background(Color.gray)
            .onSubmit {
              // 입력 완료 후 제출 시 데이터 생성
              CoreDataManager.coreDM.createUser(userName: nickname)
            }
          // 상태 나타내는 Text
          switch (niObject.findingPartnerState) {
          case .finding:
            Text("finding")
          case .found:
            Text("found")
          case .ready:
            Text("ready")
          }
          // 탭 버튼
            Button("Tap Me!") { // Button Start
              
              // 유저 정보 업데이트
              CoreDataManager.coreDM.readAllUser()[0].userName = nickname
              CoreDataManager.coreDM.updateUser()
              
              switch niObject.findingPartnerState {
              case .ready: // ready일 때는 niObject를 시작하고 상태 변경해줌
                  niObject.start()
                  niObject.findingPartnerState = .finding
                  if isLaunched { // TODO: - ?? isLaunched가 어떤 의미이지?
                      localNetAuth.requestAuthorization { auth in // requestAuthorization으로 처리한 결과를 auth로 받아와 다음 명령어 수행
                          isLocalNetworkPermissionDenied = !auth
                      }
                      isLaunched = false // TODO: - 왜 다시 false로 바꿔주지?
                  }
                print("ready")
                print(niObject.isBumped)
              case .finding: // 찾는 중일 때는 stop, gameState를 ready로 변경
                print("finding")
                print(niObject.isBumped)
                  niObject.stop() // TODO: - 왜 찾는 중일 때 stop, ready로 바꾸지?
                  niObject.findingPartnerState = .ready
                // 상대방을 확인했을 때 finding 상태로 변경된다.
                // finding일 때 찾은 peer 수를 나타낸다.
                // 찾았을 때
                
              case .found: // 찾기가 끝난 상태
                print("found")
                print(niObject.isBumped)
                  niObject.stop()
                  niObject.findingPartnerState = .ready
              }
            } // Button End
            .sheet(isPresented: $niObject.isBumped, onDismiss: {
              niObject.findingPartnerState = .ready
              niObject.stop()
            }) {
              MatchView(imageData: niObject.bumpedImage, nickName: niObject.bumpedName, keywords: niObject.bumpedKeywords)
            }
        }
        .onChange(of: scenePhase) { newValue in
            if !isLaunched { // TODO: - 왜 isLaunched에 따라서 바꿔주지..
                localNetAuth.requestAuthorization { auth in
                    isLocalNetworkPermissionDenied = !auth
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
