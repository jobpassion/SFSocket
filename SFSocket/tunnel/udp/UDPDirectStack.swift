import Foundation
import AxLogger
import XSocket
import XProxy
struct ConnectInfo: Hashable,CustomStringConvertible {
    var description: String{
        return sourceAddress.description + ":" + sourcePort.description + "||" + destinationAddress.description + ":" + destinationPort.description
    }
    
    let sourceAddress: IPv4Address
    let sourcePort: XPort
    let destinationAddress: IPv4Address
    let destinationPort: XPort
    
    var hashValue: Int {
        return sourceAddress.hashValue &+ sourcePort.hashValue &+ destinationAddress.hashValue &+ destinationPort.hashValue
    }
}

func == (left: ConnectInfo, right: ConnectInfo) -> Bool {
    return left.destinationAddress == right.destinationAddress &&
        left.destinationPort == right.destinationPort &&
        left.sourceAddress == right.sourceAddress &&
        left.sourcePort == right.sourcePort
}

/// This stack tranmits UDP packets directly.
open class UDPDirectStack: IPStackProtocol, RawSocketDelegate {
    public func didDisconnect(_ socket: RawSocketProtocol, error: Error?) {
        guard let (connectInfo, _) = findSocket(connectInfo: nil, socket: socket) else {
            return
        }
        activeSockets.removeValue(forKey: connectInfo)
        SKit.log("UDP didDisconnect", items: "", level: .Notify)
    }
    
    public func didReadData(_ data: Data, withTag: Int, from: RawSocketProtocol) {
        guard let (connectInfo, _) = findSocket(connectInfo: nil, socket: from) else {
            return
        }
        
        let packet = IPPacket()
        packet.sourceAddress = connectInfo.destinationAddress
        packet.destinationAddress = connectInfo.sourceAddress
        let udpParser = UDPProtocolParser()
        udpParser.sourcePort = connectInfo.destinationPort
        udpParser.destinationPort = connectInfo.sourcePort
        udpParser.payload = data
        packet.protocolParser = udpParser
        packet.transportProtocol = .udp
        packet.buildPacket()
        
        outputFunc([packet.packetData], [NSNumber(value: AF_INET as Int32)])
    }
    
    public func didWriteData(_ data: Data?, withTag: Int, from: RawSocketProtocol) {
        SKit.logX("UDP didWriteData ", level: .Trace)
    }
    
    public func didConnect(_ socket: RawSocketProtocol) {
       SKit.logX("udp socket connected", level: .Info)
    }
    
    public func disconnect(becauseOf error: Error?) {
        SKit.logX("disconnect", level: .Info)
    }
    
    public func forceDisconnect(becauseOf error: Error?) {
        SKit.logX("forceDisconnect", level: .Info)
    }
    
    fileprivate var activeSockets: [ConnectInfo: RawSocketProtocol] = [:]
    open var outputFunc: (([Data], [NSNumber]) -> ())!
    
    fileprivate let queue: DispatchQueue = DispatchQueue(label: "NEKit.UDPDirectStack.SocketArrayQueue", attributes: [])
    
    fileprivate let cleanUpTimer: DispatchSourceTimer
    
    public init() {
        cleanUpTimer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(rawValue: 0), queue: queue)
        cleanUpTimer.schedule(deadline: DispatchTime.distantFuture, repeating: DispatchTimeInterval.seconds(Opt.UDPSocketActiveCheckInterval), leeway: DispatchTimeInterval.seconds(Opt.UDPSocketActiveCheckInterval))
        cleanUpTimer.setEventHandler {
            [weak self] in
            self?.cleanUpTimeoutSocket()
        }
        cleanUpTimer.resume()
    }
    
    /**
     Input a packet into the stack.
     
     - note: Only process IPv4 UDP packet as of now.
     
     - parameter packet:  The IP packet.
     - parameter version: The version of the IP packet, i.e., AF_INET, AF_INET6.
     
     - returns: If the stack accepts in this packet. If the packet is accepted, then it won't be processed by other IP stacks.
     */
    open func inputPacket(_ packet: Data, version: NSNumber?) -> Bool {
        if let version = version {
            // we do not process IPv6 packets now
            if version.int32Value == AF_INET6 {
                return false
            }
        }
        if IPPacket.peekProtocol(packet) == .udp {
            input(packet)
            SKit.log("udp packet input ok", level: .Debug)
            return true
        }
        return false
    }
    
    open func stop() {
        queue.async {
            for socket in self.activeSockets.values {
                socket.disconnect(becauseOf: nil)
            }
            self.activeSockets = [:]
        }
    }
    
    fileprivate func input(_ packetData: Data) {
        guard let packet = IPPacket(packetData: packetData) else {
            SKit.log("IPPacket creat error", level: .Debug)
            return
        }
        
        guard let (_, socket) = findOrCreateSocketForPacket(packet) else {
            
            return
        }
        
        // swiftlint:disable:next force_cast
        let payload = (packet.protocolParser as! UDPProtocolParser).payload
        socket.writeData(payload!, withTag: 0)
    }
    
    fileprivate func findSocket(connectInfo: ConnectInfo?, socket: RawSocketProtocol?) -> (ConnectInfo, RawSocketProtocol)? {
        var result: (ConnectInfo, RawSocketProtocol)?
        
        queue.sync {
            if connectInfo != nil {
                guard let sock = self.activeSockets[connectInfo!] else {
                    result = nil
                    return
                }
                result = (connectInfo!, sock)
                return
            }
            
            guard let socket = socket else {
                result = nil
                return
            }
            //MARK :fixme
            //RawSocketProtocol no == able
            guard let index = self.activeSockets.firstIndex(where: { (arg) -> Bool in

                let (_, sock) = arg
                let ss = sock as! NSObject
                let st = socket as! NSObject
                
                return  ss == st
               
            }) else {
                result = nil
                return
            }
            
            result = self.activeSockets[index]
        }
        return result
    }
    
    fileprivate func findOrCreateSocketForPacket(_ packet: IPPacket) -> (ConnectInfo,RawSocketProtocol )? {
        // swiftlint:disable:next force_cast
        let udpParser = packet.protocolParser as! UDPProtocolParser
        let connectInfo = ConnectInfo(sourceAddress: packet.sourceAddress, sourcePort: udpParser.sourcePort, destinationAddress: packet.destinationAddress, destinationPort: udpParser.destinationPort)
        
        if let (_, socket) = findSocket(connectInfo: connectInfo, socket: nil) {
            return (connectInfo, socket)
        }
        
        guard  let request = ConnectRequest(ipAddress: connectInfo.destinationAddress, port: connectInfo.destinationPort)  else {
            return nil
        }
        
       var udpSocket = RawSocketFactory.getRawSocket(type: .GCD, tcp: false)
        udpSocket.queue = DispatchQueue.main
        udpSocket.delegate = self
        do {
            try udpSocket.connectTo(request.host, port: UInt16(request.port), enableTLS: false, tlsSettings: nil)
            
        }catch let e {
            SKit.logX(request.host + "\(request.port) connect error :\(e.localizedDescription)", level: .Error)
        }

        queue.sync {
            self.activeSockets[connectInfo] = udpSocket
        }
        return (connectInfo, udpSocket)
    }
    
    // This shoule be called by the timer, so is already on `queue`.
    fileprivate func cleanUpTimeoutSocket() {
       
        for (connectInfo, socket) in activeSockets {
            if socket.lastActive.addingTimeInterval(TimeInterval(Opt.UDPSocketActiveTimeout)).compare(Date()) == .orderedAscending {
                var s = socket
                SKit.logX("remove \(connectInfo.description) closeing", level: .Notify)
                s.delegate = nil
                s.forceDisconnect(becauseOf: nil)
                activeSockets.removeValue(forKey: connectInfo)
            }
        }
    }
    func write(info:ConnectInfo)  {
        let req = SFRequestInfo.init(rID:UInt(info.sourcePort.value))
        req.url = info.destinationAddress.description + ":" + String(info.destinationPort.value)
        req.mode = .UDP
        //MARK: GRDB issue
        //RequestHelper.shared.saveReqInfo(req)
    }
 
}
