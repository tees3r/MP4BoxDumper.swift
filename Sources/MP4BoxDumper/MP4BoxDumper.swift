import Foundation

public class MP4BoxDumper {
  private let url: URL?
    public var mediaData: Data = Data()
    public var structureDescription: String = ""
  
  public init(url: URL) {
    self.url = url
  }
    
    public init(data: Data) {
        url = nil
        let stream = InputStream(data: data)
        stream.open()
        dumpBox(stream: stream, indent: 0)
        stream.close()
    }
  
  public func dumpBox() {
      guard let url = url else { return }
    let stream = InputStream(url: url)!
    stream.open()
    dumpBox(stream: stream, indent: 0)
    stream.close()
  }
  
  private func dumpBox(stream: InputStream, indent: Int) {
      var offsetAfterRead = 0
    var indent = indent
    while stream.hasBytesAvailable {
        offsetAfterRead += 4
      let (size, _) = stream.read(maxLength: offsetAfterRead)
      let boxSize = size.uint32Value
      guard boxSize > 8 else { continue }
        offsetAfterRead += 4
      guard let typeString = stream.readAsciiString(length: offsetAfterRead) else { return }
      let indentString = (0..<indent).map({ _ in " "}).reduce("", +)
//      print("\(indentString)\(typeString)(\(boxSize))")
        let boxDescription = "\(indentString)\(typeString)(o:\(offsetAfterRead)\ts:\(boxSize))\n"
        structureDescription.append(contentsOf: boxDescription)
      let (data, _) = stream.read(maxLength: Int(boxSize - 8))
        if typeString == "mdat" {
            mediaData.append(contentsOf: data)
        }
      switch typeString {
      case "ftyp":
        dumpftyp(data: Data(bytes: data))
      case "moov", "trak", "mdia", "minf", "stbl", "edts",
           "mp4v", "s263", "avc1",
           "mp4a",
           "esds":
        indent += 1
        let nextInputStream = InputStream(data: Data(bytes: data))
        nextInputStream.open()
        dumpBox(stream: nextInputStream, indent: indent)
        indent -= 1
        nextInputStream.close()
      default: break
      }
    }
  }
  
  private func dumpftyp(data: Data) {
    let stream = InputStream(data: data)
    stream.open()
    if let major = stream.readAsciiString(length: 4) {
        structureDescription.append(contentsOf: " Major Brand: \(major)\n")
//      print(" Major Brand: \(major)")
    }
    stream.skip(length: 4)
    while stream.hasBytesAvailable {
      if let comp = stream.readAsciiString(length: 4) {
          structureDescription.append(contentsOf: " Compatible Brand: \(comp)\n")
//        print(" Compatible Brand: \(comp)")
      }
    }
    stream.close()
  }
}
