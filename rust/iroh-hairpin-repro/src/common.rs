use std::net::{IpAddr, SocketAddr};

pub const ALPN: &[u8] = b"iroh-hairpin-repro/1";

/// Address on a private/link-local/loopback range — reachable on the LAN,
/// as opposed to a NAT-reflexive public mapping learned through a relay.
pub fn is_lan(addr: &SocketAddr) -> bool {
    match addr.ip() {
        IpAddr::V4(v4) => v4.is_private() || v4.is_link_local() || v4.is_loopback(),
        IpAddr::V6(v6) => {
            let seg = v6.segments();
            v6.is_loopback() || (seg[0] & 0xffc0) == 0xfe80 || (seg[0] & 0xfe00) == 0xfc00
        }
    }
}

pub fn stamp() -> String {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default();
    let s = now.as_secs() % 86_400;
    format!("{:02}:{:02}:{:02}.{:03}", s / 3600, (s / 60) % 60, s % 60, now.subsec_millis())
}
