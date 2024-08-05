import gleam/io
import gleeunit
import ws

pub fn main() {
  gleeunit.main()
}

pub fn parse_ws_key_test() {
  let request = "GET /ws HTTP1.1\r\nSec-WebSocket-Key: supersecret"
  let key = ws.parse_key(request)
  io.debug(key)
}
