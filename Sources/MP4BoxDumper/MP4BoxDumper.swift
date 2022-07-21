import Foundation
import UIKit

public class MP4BoxDumper {
    private let url: URL?
    public var mediaData: Data?
    public var structureDescription: String = ""
    public var avcC: Data?
    public var trun: Data?
    public var timestamp: UInt64?
    public var sampleDuration: UInt64 = 3600 // read from trun box
    
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
    
    private func dumpBox(stream: InputStream, indent: Int, offsetAfterRead: Int = 0) {
        var offsetToApply = offsetAfterRead
        var indent = indent
        while stream.hasBytesAvailable {
            var headerSize = 8
            offsetToApply += 4
            let (size, _) = stream.read(maxLength: 4)
            var boxSize: UInt64 = UInt64(size.uint32Value)
            
            if boxSize == 1 {
                offsetToApply += 8
                headerSize += 8
                let (size, _) = stream.read(maxLength: 8)
                boxSize = size.uint64Value
            }
            
            if boxSize == 0 {
                offsetToApply += 4
                let (_, _) = stream.read(maxLength: 4) // read type which is to be ignored
                continue
            }
            
            guard boxSize > 8 else { continue }
            
            offsetToApply += 4
            guard let typeString = stream.readAsciiString(length: 4) else { return }
            let indentString = (0..<indent).map({ _ in " "}).reduce("", +)
            let boxDescription = "\(indentString)\(typeString)(start:\(offsetAfterRead)\tsize:\(boxSize))\n"
            structureDescription.append(contentsOf: boxDescription)

            let (data, _) = stream.read(maxLength: Int(boxSize) - headerSize)
                        
            switch typeString {
            case "mdat":
                mediaData = Data(data)
            case "ftyp":
                dumpftyp(data: Data(data))
            case "avc1":
                dumpAVC1(data: Data(data))
            case "moov", "trak", "mdia", "minf", "stbl", "edts",
                "mp4v", "s263",
                "mp4a",
                "esds",
                "stsd",
                "moof", "traf":
                indent += 1
                let nextInputStream = InputStream(data: Data(data))
                nextInputStream.open()
                dumpBox(stream: nextInputStream, indent: indent, offsetAfterRead: offsetToApply )
                indent -= 1
                nextInputStream.close()
            case "tfdt":
                timestamp = dumptfdt(data: Data(data))
            default: break
            }
            offsetToApply += (Int(boxSize) - headerSize)
        }
    }
    
    private func dumpAVC1(data: Data) {
        // (▀̿Ĺ̯▀̿ ̿) mp4 box killer
        for (index, _) in data.enumerated() {
            if data.indices.contains(index + 3),
               Array(data[index...index + 3]) == [97, 118, 99, 67], // avcC
               data.indices.contains(index - 4){
                let boxSize = Array(data[index - 4...index]).uint32Value
                let startIndex = index+4
                let endIndex = startIndex + Int(boxSize) - 8
                guard data.indices.contains(startIndex),
                      data.indices.contains(endIndex) else { return }
                
                avcC = Data(data[startIndex...endIndex])
            }
        }
    }
    
    // fragment display time - timestamp
    private func dumptfdt(data: Data) -> UInt64 {
        var result: UInt64 = 0
        let stream = InputStream(data: data)
        stream.open()
        let (size, _) = stream.read(maxLength: 4)
        if size.uint32Value == 0x1000000 {
            let (timestamp, _) = stream.read(maxLength: 8)
            result = timestamp.uint64Value
        } else {
            let (timestamp, _) = stream.read(maxLength: 4)
            result = timestamp.uint64Value
        }
        
        stream.close()
        return result
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

// MARK: - avcC

public struct AVCDecoderConfigurationRecord {
    /*
     Option1: https://gpac.github.io/mp4box.js/test/filereader.html
     type    avcC
     size    72
     start    511
     configurationVersion    1
     AVCProfileIndication    77
     profile_compatibility    64
     AVCLevelIndication    40
     lengthSizeMinusOne    3
     nb_SPS_nalus    1
     SPS    [object Object]
     nb_PPS_nalus    1
     PPS    [object Object]
     Option2: https://gist.github.com/uupaa/8493378ec15f644a3d2b
     00 00 00 2e    BoxSize    'avcC' の Box サイズ
     61 76 63 43    BoxType    'avcC'
     01    configurationVersion    通常は1です
     42    AVCProfileIndication    0x42(66), AVCのプロファィル(profile_idc)です
     66はBaseline profileです
     c0    profile_compatibility    SPS の互換性情報です
     1e    AVCLevelIndication    30, Level です。30 は 3.0 になります
     ff    lengthSizeMinusOne    111111 + 11, NALUnit の長さ部分のバイト数は通常4ですが、
     1,2,4 byte にも変更できます。3は不正な値です。
     実際のbyte数から1引いた値になります
     e1    numOfSequenceParameterSets    111 + 00001, SPS のパラメタセット数です
     00 16    sequenceParameterSetLength    0x0016(22). SPS NALU のバイト数です
     67 42 .. 8b 92    sequenceParameterSetNALUnit    22byte の SPS NALU です
     01    numOfPictureParameterSets    0x01. PPS NALU のパラメタセット数です
     00 05    pictureParameterSetLength    0x05. PPS NALU のバイト数です
     68 cb 83 cb 20    pictureParameterSetNALUnit    5byte の PPS NALU です
     unsigned int(8) configurationVersion = 1;
     unsigned int(8) AVCProfileIndication;
     unsigned int(8) profile_compatibility;
     unsigned int(8) AVCLevelIndication;
     bit(6) reserved = ‘111111’b;
     unsigned int(2) lengthSizeMinusOne;
     bit(3) reserved = ‘111’b;
     unsigned int(5) numOfSequenceParameterSets;
     for (i=0; i< numOfSequenceParameterSets; i++) {
     unsigned int(16) sequenceParameterSetLength ;
     bit(8*sequenceParameterSetLength) sequenceParameterSetNALUnit;
     }
     unsigned int(8) numOfPictureParameterSets;
     for (i=0; i< numOfPictureParameterSets; i++) {
     unsigned int(16) pictureParameterSetLength;
     bit(8*pictureParameterSetLength) pictureParameterSetNALUnit;
     }
     
     Option3: https://github.com/mozilla/mp4parse-rust/issues/159
     Option4: https://www.zzsin.com/article/19_Avcc_Box.html
     Option5: https://chromium.googlesource.com/chromium/src/+/bcae749c7aaec4bc26e22a3acb6183dabdce2c96/media/formats/mp4/box_definitions.cc#545
     */
    let configurationVersion: UInt8
    let AVCProfileIndication: UInt8
    let profile_compatibility: UInt8
    let AVCLevelIndication: UInt8
    let lengthSizeMinusOne: UInt8 // & 0x03
    let numOfSequenceParameterSets: UInt8
    let sequenceParameterSetLengths: [UInt16]
    public let sequenceParameterSetNALUnits: [[UInt8]]
    let numOfPictureParameterSets: UInt8
    let pictureParameterSetLengths: [UInt16]
    public let pictureParameterSetNALUnits: [[UInt8]]
}

public extension MP4BoxDumper {
    var avcDecoderConfigurationRecord: AVCDecoderConfigurationRecord? {
        guard let avcC = avcC else { return nil }
        let stream = InputStream(data: avcC)
        stream.open()
        
        let (configurationVersion, _) = stream.read(maxLength: 1)
        let (AVCProfileIndication, _) = stream.read(maxLength: 1)
        let (profile_compatibility, _) = stream.read(maxLength: 1)
        let (AVCLevelIndication, _) = stream.read(maxLength: 1)
        let (rawLengthSizeMinusOne, _) = stream.read(maxLength: 1)
        
        guard let configurationVersion = configurationVersion.first,
              let AVCProfileIndication = AVCProfileIndication.first,
              let profile_compatibility = profile_compatibility.first,
              let AVCLevelIndication = AVCLevelIndication.first,
              let rawLengthSizeMinusOne = rawLengthSizeMinusOne.first
        else { return nil }
        
        let lengthSizeMinusOne = rawLengthSizeMinusOne & 0x03
        
        // SPS
        let (rawNumOfSequenceParameterSets, _) = stream.read(maxLength: 1)
        
        guard let rawNumOfSequenceParameterSets = rawNumOfSequenceParameterSets.first else { return nil }
        let numOfSequenceParameterSets = rawNumOfSequenceParameterSets & 0x0F
        
        var sequenceParameterSetLengths: [UInt16] = []
        var sequenceParameterSetNALUnits: [[UInt8]] = []
        
        for _ in 0..<numOfSequenceParameterSets {
            let (rawSequenceParameterSetLength, _) = stream.read(maxLength: 2)
            guard rawSequenceParameterSetLength.count == 2 else { return nil }
            let sequenceParameterSetLength = UInt16(rawSequenceParameterSetLength[0])*256 + UInt16(rawSequenceParameterSetLength[1])
            sequenceParameterSetLengths.append(sequenceParameterSetLength)
            
            let (sequenceParameterSetNALUnit, _) = stream.read(maxLength: Int(sequenceParameterSetLength))
            sequenceParameterSetNALUnits.append(sequenceParameterSetNALUnit)
        }
        
        // PPS
        let (rawNumOfPictureParameterSets, _) = stream.read(maxLength: 1)
        
        guard let rawNumOfPictureParameterSets = rawNumOfPictureParameterSets.first else { return nil }
        let numOfPictureParameterSets = rawNumOfPictureParameterSets & 0x0F
        
        var pictureParameterSetLengths: [UInt16] = []
        var pictureParameterSetNALUnits: [[UInt8]] = []
        
        for _ in 0..<numOfPictureParameterSets {
            let (rawPictureParameterSetLength, _) = stream.read(maxLength: 2)
            guard rawPictureParameterSetLength.count == 2 else { return nil }
            let pictureParameterSetLength = UInt16(rawPictureParameterSetLength[0])*256 + UInt16(rawPictureParameterSetLength[1])
            pictureParameterSetLengths.append(pictureParameterSetLength)
            
            let (pictureParameterSetNALUnit, _) = stream.read(maxLength: Int(pictureParameterSetLength))
            pictureParameterSetNALUnits.append(pictureParameterSetNALUnit)
        }
        
        stream.close()
        
        return AVCDecoderConfigurationRecord(
            configurationVersion: configurationVersion,
            AVCProfileIndication: AVCProfileIndication,
            profile_compatibility: profile_compatibility,
            AVCLevelIndication: AVCLevelIndication,
            lengthSizeMinusOne: lengthSizeMinusOne,
            numOfSequenceParameterSets: numOfSequenceParameterSets,
            sequenceParameterSetLengths: sequenceParameterSetLengths,
            sequenceParameterSetNALUnits: sequenceParameterSetNALUnits,
            numOfPictureParameterSets: numOfPictureParameterSets,
            pictureParameterSetLengths: pictureParameterSetLengths,
            pictureParameterSetNALUnits: pictureParameterSetNALUnits)
    }
}
