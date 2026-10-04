///|
/// Incremental framing for a single MRCL snapshot received in network chunks.
/// Failure poisons the reader until reset; trailing bytes are never ignored.
pub struct FrameReader {
  limits : DecodeLimits
  bytes : Array[Byte]
  mut expected : Int?
  mut failed : Bool
  mut finished : Bool
}

///|
pub fn FrameReader::new(limits : DecodeLimits) -> FrameReader {
  { limits, bytes: [], expected: None, failed: false, finished: false, }
}

///|
pub fn FrameReader::buffered_bytes(self : FrameReader) -> Int {
  self.bytes.length()
}

///|
pub fn FrameReader::reset(self : FrameReader) -> Unit {
  self.bytes.clear()
  self.expected = None
  self.failed = false
  self.finished = false
}

///|
pub fn FrameReader::feed(
  self : FrameReader,
  chunk : Bytes,
) -> Snapshot? raise ReconcileError {
  if self.failed || self.finished {
    raise InvalidFrame("reader requires reset")
  }
  try {
    let maximum = 68 + self.limits.max_width * 60
    if chunk.length() > maximum - self.bytes.length() {
      raise LimitExceeded("stream frame size")
    }
    for byte in chunk {
      self.bytes.push(byte)
      // Validate length declarations as soon as the first 16 bytes arrive.
      if self.bytes.length() == 16 {
        let header = Bytes::from_array(self.bytes)
        if header[0] != 77 ||
          header[1] != 82 ||
          header[2] != 67 ||
          header[3] != 76 ||
          header[4] != 1 ||
          header[5] != 0 ||
          header[6] != 0 ||
          header[7] != 0 {
          raise InvalidFrame("invalid stream header")
        }
        let width = get_u32(header, 8)
        if width == 0U || width > self.limits.max_width.reinterpret_as_uint() {
          raise LimitExceeded("stream width")
        }
        if get_u32(header, 12) > self.limits.max_members.reinterpret_as_uint() {
          raise LimitExceeded("stream members")
        }
        self.expected = Some(68 + width.reinterpret_as_int() * 60)
      }
      if self.expected is Some(size) && self.bytes.length() > size {
        raise InvalidFrame("trailing stream bytes")
      }
    }
    if self.expected is Some(size) && self.bytes.length() == size {
      let snapshot = Snapshot::decode(
        Bytes::from_array(self.bytes),
        self.limits,
      )
      self.finished = true
      Some(snapshot)
    } else {
      None
    }
  } catch {
    (error : ReconcileError) => {
      self.failed = true
      self.bytes.clear()
      raise error
    }
  }
}

///|
/// Signal transport EOF; truncated input is an error, never an empty set.
pub fn FrameReader::finish(self : FrameReader) -> Unit raise ReconcileError {
  if !self.finished || self.failed {
    self.failed = true
    self.bytes.clear()
    raise InvalidFrame("incomplete stream")
  }
}
