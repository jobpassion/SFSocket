import Foundation
import XSocket
/// The request containing information to connect to remote.
public final class ConnectRequest {
    /// The requested host.
    ///
    /// This is the host received in the request. May be a domain, a real IP or a fake IP.
    public let requestedHost: String
    
    /// The real host for this request.
    ///
    /// If the request is initailized with a host domain, then `host == requestedHost`.
    /// Otherwise, the requested IP address is looked up in the DNS server to see if it corresponds to a domain if `fakeIPEnabled` is `true`.
    /// Unless there is a good reason not to, any socket shoule connect based on this directly.
    public var host: String
    
    /// The requested port.
    public let port: Int
    
    /// The rule to use to connect to remote.
    public var matchedRule: Rule?
    
    /// Whether If the `requestedHost` is an IP address.
    public let fakeIPEnabled: Bool
    
    /// The resolved IP address.
    ///
    /// - note: This will always be real IP address.
    public lazy var ipAddress: String = {
        [unowned self] in
        if self.isIP() {
            return self.host
        } else {
            let ip = Utils.DNS.resolve(self.host)
            
            guard self.fakeIPEnabled else {
                return ip
            }
            
//            guard let dnsServer = DNSServer.currentServer else {
//                return ip
//            }
            
            guard let address = IPv4Address(fromString: ip) else {
                return ip
            }
            
//            guard dnsServer.isFakeIP(address) else {
//                return ip
//            }
//            
//            guard let session = dnsServer.lookupFakeIP(address) else {
//                return ip
//            }
            return ""
            //return session.realIP?.presentation ?? ""
        }
        }()
    
    /// The location of the host.
    public lazy var country: String = {
        [unowned self] in
        guard let c = Utils.GeoIPLookup.Lookup(self.ipAddress) else {
            return "--"
        }
        return c
        }()
    
    public init?(host: String, port: Int, fakeIPEnabled: Bool = true) {
        self.requestedHost = host
        self.port = port
        
        self.fakeIPEnabled = fakeIPEnabled
        
        self.host = host
        /* disable
        if fakeIPEnabled {
            guard lookupRealIP() else {
                return nil
            }
        }
         */
    }
    
    public convenience init?(ipAddress: IPv4Address, port: XPort, fakeIPEnabled: Bool = true) {
        self.init(host: ipAddress.presentation, port: Int(port.value), fakeIPEnabled: fakeIPEnabled)
    }
    /*
    fileprivate func lookupRealIP() -> Bool {
        /// If custom DNS server is set up.
        guard let dnsServer = DNSServer.currentServer else {
            return true
        }
        
        // Only IPv4 is supported as of now.
        guard isIPv4() else {
            return true
        }
        
        let address = IPv4Address(fromString: requestedHost)!
        guard dnsServer.isFakeIP(address) else {
            return true
        }
        
        // Look up fake IP reversely should never fail.
        guard let session = dnsServer.lookupFakeIP(address) else {
            return false
        }
        
        host = session.requestMessage.queries[0].name
        ipAddress = session.realIP?.presentation ?? ""
        matchedRule = session.matchedRule
        
        if session.countryCode != nil {
            country = session.countryCode!
        }
        return true
    }
    */
    public func isIPv4() -> Bool {
        return Utils.IP.isIPv4(host)
    }
    
    public func isIPv6() -> Bool {
        return Utils.IP.isIPv6(host)
    }
    
    public func isIP() -> Bool {
        return isIPv4() || isIPv6()
    }
}

extension ConnectRequest: CustomStringConvertible {
    public var description: String {
        if requestedHost != host {
            return "<\(type(of: self)) host:\(host) port:\(port) requestedHost:\(requestedHost)>"
        } else {
            return "<\(type(of: self)) host:\(host) port:\(port)>"
        }
    }
}
