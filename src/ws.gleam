import gleam/bit_array
import gleam/bytes_builder
import gleam/crypto
import gleam/erlang/process
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import glisten/socket
import glisten/tcp

pub fn main() {
  let _ =
    tcp.listen(3000, [])
    |> result.then(accept)
    |> result.map_error(io.debug)

  process.sleep_forever()
}

pub fn accept(socket) {
  let _ =
    tcp.accept(socket)
    |> result.then(handle_conn)
    |> result.map_error(io.debug)

  accept(socket)
}

pub fn handle_conn(socket) -> Result(socket.Socket, socket.SocketReason) {
  let _ =
    tcp.receive(socket, 0)
    |> result.map(bit_array.to_string)
    |> result.unwrap(Error(Nil))
    |> result.then(parse_key)
    |> result.map(switch_protocol(socket, _))
    |> result.map_error(fn(_) { not_found(socket) })
    |> result.map(fn(_) { ws(socket) })

  Ok(socket)
}

pub fn ws(socket) {
  let _ =
    tcp.receive(socket, 2)
    |> io.debug

  ws(socket)
}

pub fn not_found(socket) {
  let msg = bytes_builder.from_string("HTTP/1.1 404 Not Found\r\n\r\n")
  let _ = tcp.send(socket, msg)
  let _ = tcp.close(socket)
}

pub fn switch_protocol(socket, key) {
  let _ =
    tcp.send(
      socket,
      bytes_builder.from_string(
        "HTTP/1.1 101 Switching Protocols\r\n"
        <> "Upgrade: websocket\r\n"
        <> "Connection: Upgrade\r\n"
        <> "Sec-WebSocket-Accept: "
        <> generate_hash(key)
        <> "\r\n\r\n",
      ),
    )
}

pub fn parse_key(req) {
  string.split(req, on: "\r\n")
  |> list.find(string.starts_with(_, "Sec-WebSocket-Key:"))
  |> result.map(string.split(_, ":"))
  |> result.then(list.last)
  |> result.map(string.trim)
}

pub fn generate_hash(key: String) -> String {
  let bkey = bit_array.from_string(key)
  let magic = bit_array.from_string("258EAFA5-E914-47DA-95CA-C5AB0DC85B11")

  bit_array.concat([bkey, magic])
  |> crypto.hash(crypto.Sha1, _)
  |> bit_array.base64_encode(True)
}
