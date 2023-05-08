//
//  NISessionManager.swift
//  NearByInteractionTest
//
//  Created by 박의서 on 2023/05/06.
//

import Foundation
import NearbyInteraction
import MultipeerConnectivity
import UIKit

class TranData: NSObject, NSCoding {
    let token : NIDiscoveryToken
    let isBumped : Bool
    let kalories : [Int]
    let nickname : String
    let isDone: Bool
    
    init(token : NIDiscoveryToken, isBumped : Bool = false, kalories: [Int] = [], nickname : String = "", isDone: Bool = false) {
        self.token = token
        self.isBumped = isBumped
        self.kalories = kalories
        self.nickname = nickname
        self.isDone = isDone
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(self.token, forKey: "token")
        coder.encode(self.isBumped, forKey: "isMatched")
        coder.encode(self.kalories, forKey: "kalories")
        coder.encode(self.nickname, forKey: "nickname")
        coder.encode(self.isDone, forKey: "isdone")
    }
    
    required init?(coder: NSCoder) {
        self.token = coder.decodeObject(forKey: "token") as! NIDiscoveryToken
        self.isBumped = coder.decodeBool(forKey: "isMatched")
        self.nickname = coder.decodeObject(forKey: "nickname") as! String
        self.kalories = coder.decodeObject(forKey: "kalories") as! [Int]
        self.isDone = (coder.decodeObject(forKey: "isdone") != nil)
    }
}

class NISessionManager: NSObject, ObservableObject {

    @Published var connectedPeers = [MCPeerID]()
    @Published var matchedObject: TranData? // 매치된 오브젝트
    @Published var peersCnt: Int = 0
    @Published var findingPartnerState : FindingPartnerState = .ready
    @Published var isBumped: Bool = false
    @Published var isPermissionDenied = false
    
    var mpc: MPCSession?
    var sessions = [MCPeerID:NISession]()
    var peerTokensMapping = [NIDiscoveryToken:MCPeerID]()
    
    let nearbyDistanceThreshold: Float = 0.08 // 범프 한계 거리
    
    // 나의 정보
    @Published var myNickname : String = ""
    @Published var myKeywords : [Int] = []
    @Published var myPicture : UIImage?
    
    // 범프된 상대 정보
    @Published var bumpedName = ""
    @Published var bumpedKalories = [0]
    @Published var bumpedisDone = false
    
    override init() {
        super.init()
    }

    deinit {
        sessions.removeAll()
        mpc?.invalidate()
    }
    
    func start() {
        startup()
        
        myNickname = "웨스트"
      myKeywords = [1]
      myPicture = UIImage(named: "")
      myNickname = CoreDataManager.coreDM.readAllUser()[0].userName ?? "예시닉네임"
//      myCharacterName = CoreDataManager.coreDM.readAllBuddy()[0].characterName ?? "버디이름"

//        myNickname = CoreDataManager.coreDM.readAllProfile()[0].nickname ?? ""
//        myKeywords = CoreDataManager.coreDM.readKeyword()[0].favorite
//        myPicture = CoreDataManager.coreDM.readAllPicture()[0].content
    }
    
    func stop() {
        for (_, session) in sessions {
            session.invalidate()
        }
        connectedPeers.removeAll()
        sessions.removeAll()
        peerTokensMapping.removeAll()
        matchedObject = nil
        peersCnt = 0
//        hapticManager.endHaptic()
        if(!isBumped) {
            mpc?.invalidate()
            mpc = nil
        }
    }

    func startup() {
        // mpc 재실행
        mpc?.invalidate()
        mpc = nil
        connectedPeers.removeAll()

        // 1. MPC 작동
        startupMPC()
    }

    // MARK: - MPC를 사용하여 디스커버리 토큰 공유

    func startupMPC() {
        if mpc == nil {
            // Prevent Simulator from finding devices.
            #if targetEnvironment(simulator)
          mpc = MPCSession(service: "nearcatch", identity: "com.2pm.NearCatch")
            #else
            mpc = MPCSession(service: "nearcatch", identity: "com.2pm.NearCatch")
            #endif
            mpc?.delegate = self
            mpc?.peerConnectedHandler = connectedToPeer
            mpc?.peerDataHandler = dataReceivedHandler
            mpc?.peerDisconnectedHandler = disconnectedFromPeer
        }
        mpc?.invalidate()
        mpc?.start()
    }
    
    // MPC peerConnectedHandeler에 의해 피어 연결
    // 2. 피어 연결 (NI 디스커버리 토큰을 공유)
    func connectedToPeer(peer: MCPeerID) {
        guard sessions[peer] == nil else { return }
        
        // 해당 피어의 NI Session 생성
        sessions[peer] = NISession()
        sessions[peer]?.delegate = self
        
        guard let myToken = sessions[peer]?.discoveryToken else {
            //            fatalError("Unexpectedly failed to initialize nearby interaction session.")
            return
        }
        
        // 3. 연결된 피어 추가
        if !connectedPeers.contains(peer) {
            // 4. 나의 NI 디스커버리 토큰 공유
            DispatchQueue.global(qos: .userInitiated).async {
                self.shareMyDiscoveryToken(token: myToken, peer: peer)
            }
            connectedPeers.append(peer)
        }
    }

    // MPC peerDisconnectedHander에 의해 피어 연결 해제
    func disconnectedFromPeer(peer: MCPeerID) {
        // 연결 해제시 연결된 피어 제거
        if connectedPeers.contains(peer) {
            connectedPeers = connectedPeers.filter { $0 != peer }
            sessions[peer]?.invalidate()
            sessions[peer] = nil
        }
        
        // 매칭된 상대가 해제 될 경우 제거
        guard let matchedToken = matchedObject?.token else { return }
        if peerTokensMapping[matchedToken] == peer {
            matchedObject = nil
//            hapticManager.endHaptic()
            if !isBumped {
                findingPartnerState = .finding
            }
        }
    }
    
    // MPC peerDataHandler에 의해 데이터 리시빙
    // 5. 상대 데이터 수신
    func dataReceivedHandler(data: Data, peer: MCPeerID) {
        guard let receivedData = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? TranData else {
            //            fatalError("Unexpectedly failed to decode discovery token.")
            return
        }
        
        //  범프된 상태일 경우
        if receivedData.isBumped {
            if !self.isBumped {
                self.isBumped = true
                bumpedName = receivedData.nickname
                bumpedKalories = receivedData.kalories
                DispatchQueue.global(qos: .userInitiated).async {
                    self.shareMyData(token: receivedData.token, peer: peer)
                }
            }
            stop()
            findingPartnerState = .ready
        } else { // 일반 전송
            let discoveryToken = receivedData.token
            
            peerDidShareDiscoveryToken(peer: peer, token: discoveryToken)
            
            // 3개 이상일 때만 매치
            if calMatchingKeywords(myKeywords, receivedData.kalories) >= 0 {
                DispatchQueue.global(qos: .userInitiated).async {
                    self.compareForCheckMatchedObject(receivedData)
                }
//                hapticManager.startHaptic()
            }
        }
    }

    func shareMyDiscoveryToken(token: NIDiscoveryToken, peer: MCPeerID) {
        let tranData = TranData(token: token)
        
        guard let encodedData = try? NSKeyedArchiver.archivedData(withRootObject: tranData, requiringSecureCoding: false) else {
            //            fatalError("Unexpectedly failed to encode discovery token.")
            return
        }
        
        mpc?.sendData(data: encodedData, peers: [peer], mode: .unreliable)
    }
    
    func shareMyData(token: NIDiscoveryToken, peer: MCPeerID) {
        var resizedImage : UIImage = .add
        if let picture = myPicture {
            let size = CGSize(width: 50, height: 50)
            let renderer = UIGraphicsImageRenderer(size: size)
            resizedImage = renderer.image { context in
                picture.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            }
        }
        
        let tranData = TranData(token: token, isBumped: true, nickname: myNickname, isDone: true)
        
        guard let encodedData = try? NSKeyedArchiver.archivedData(withRootObject: tranData, requiringSecureCoding: false) else {
            //            fatalError("Unexpectedly failed to encode discovery token.")
            return
        }
        
        mpc?.sendData(data: encodedData, peers: [peer], mode: .unreliable)
    }

    func peerDidShareDiscoveryToken(peer: MCPeerID, token: NIDiscoveryToken) {
        // 기존에 토큰을 가지고 있는 상대인데 재연결로 다시 수신받은 경우 session 종료 후 다시 시작
        if let ownedPeer = peerTokensMapping[token] {
            self.sessions[ownedPeer]?.invalidate()
            self.sessions[ownedPeer] = nil
            // 그 피어가 매치 상대일 경우 매치 상대 초기화
            if matchedObject?.token == token {
                matchedObject = nil
//                hapticManager.endHaptic()
                if !isBumped {
                    findingPartnerState = .finding
                }
            }
        }
        
        peerTokensMapping[token] = peer
        
        // 6. 피어토큰으로 NI 세션 설정
        let config = NINearbyPeerConfiguration(peerToken: token)
        
        // Run the session.
        // 7. NI 세션 시작
        DispatchQueue.global(qos: .userInitiated).async {
            self.sessions[peer]?.run(config)
        }
    }
}

// MARK: - `NISessionDelegate`.
extension NISessionManager: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        // Find the right peer.
        let peerObj = nearbyObjects.first { (obj) -> Bool in
            return peerTokensMapping[obj.discoveryToken] != nil
        }
        
        guard let nearbyObjectUpdate = peerObj else { return }
        
        // 범프
        if isNearby(nearbyObjectUpdate.distance ?? 10) {
            guard let peerId = peerTokensMapping[nearbyObjectUpdate.discoveryToken] else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                self.shareMyData(token: nearbyObjectUpdate.discoveryToken, peer: peerId)
            }
        }
        
        // 매칭된 사람일 경우 진동 변화
//        guard let matchedToken = matchedObject?.token else { return }
//        if nearbyObjectUpdate.discoveryToken == matchedToken {
//            hapticManager.updateHaptic(dist: nearbyObjectUpdate.distance ?? 10,
//                                       matchingPercent: calMatchingKeywords(matchedObject?.keywords ?? [], myKeywords))
//        }
    }
    
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        // Find the right peer.
        let peerObj = nearbyObjects.first { (obj) -> Bool in
            return peerTokensMapping[obj.discoveryToken] != nil
        }
        
        if peerObj == nil {
            return
        }
        
        switch reason {
        case .peerEnded:
            guard let curMPCid = peerTokensMapping[peerObj!.discoveryToken] else { return }
            
            peerTokensMapping[peerObj!.discoveryToken] = nil
            
            // The peer stopped communicating, so invalidate the session because
            // it's finished.
            sessions[curMPCid]?.invalidate()
            sessions[curMPCid] = nil
            
            // Restart the sequence to see if the peer comes back.
            startup()
        case .timeout:
            // The peer timed out, but the session is valid.
            // If the configuration is valid, run the session again.
            if let config = session.configuration {
                DispatchQueue.global(qos: .userInitiated).async {
                    session.run(config)
                }
            }
        default:
            //            fatalError("Unknown and unhandled NINearbyObject.RemovalReason")
            return
        }
    }

    func sessionWasSuspended(_ session: NISession) {
    }

    func sessionSuspensionEnded(_ session: NISession) {
        // Session suspension ends. You can run the session again.
        startup()
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        // If the app lacks user approval for Nearby Interaction, present
        // an option to go to Settings where the user can update the access.
        if case NIError.userDidNotAllow = error {
            isPermissionDenied = true
        }
        // Recreate a valid session in other failure cases.
        startup()
    }
}

// MARK: - `MultipeerConnectivityManagerDelegate`.
extension NISessionManager: MultipeerConnectivityManagerDelegate {
    func connectedDevicesChanged(devices: [String]) {
        peersCnt = devices.count
    }
}

// MARK: - 거리에 따라 반응 로직

extension NISessionManager {
    
    // 범프
    func isNearby(_ distance: Float) -> Bool {
        return distance < nearbyDistanceThreshold
    }
    
    // 매칭 상대 업데이트
    private func compareForCheckMatchedObject(_ data: TranData) {
        
        guard self.matchedObject != data else { return }
        
        if let nowTranData = self.matchedObject {
            
            let withCurCnt : Int = calMatchingKeywords(myKeywords, nowTranData.kalories)
            let withNewCnt : Int = calMatchingKeywords(myKeywords, data.kalories)
            
            if withCurCnt < withNewCnt {
                self.matchedObject = data
            }
            
        } else {
            self.matchedObject = data
            if !isBumped {
                findingPartnerState = .found
            }
        }
        
    }
    
    private func calMatchingKeywords(_ first: [Int], _ second: [Int]) -> Int {
        let cnt = Set(first).intersection(second).count
        return cnt
    }
}
