// Microsoft Edge neural speech client. Protocol/token compatibility follows
// https://github.com/rany2/edge-tts (LGPL-3.0); no Python dependency is used.
// The v2 token's numeric constants and bitwise operations are reproduced for
// interoperability with Microsoft's current online read-aloud endpoint.
import Foundation
import AVFoundation

private let trustedToken="6A5AA1D4EAFF4E9FB37E23D68491D6F4"
private let shaInitial:[UInt32]=[0x6A09E667,0xBB67AE85,0x3C6EF372,0xA54FF53A,0x510E527F,0x9B05688C,0x1F83D9AB,0x5BE0CD19]
private let tokenState:[UInt32]=[0xFD9FBEA2,0x91243CE7,0xBE499094,0xCD2E1E0A,0x6C006F49,0x04BD35AB,0xFEB0A7E4,0x03EFFBD2]
private let shaK:[UInt32]=[
0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2]
private func rr(_ x:UInt32,_ n:UInt32)->UInt32{(x>>n)|(x<<(32-n))}
private func sigma0(_ x:UInt32)->UInt32{rr(x,7)^rr(x,18)^(x>>3)}
private func sigma1(_ x:UInt32)->UInt32{rr(x,17)^rr(x,19)^(x>>10)}
private func rol16(_ x:UInt32)->UInt32{(x<<16)|(x>>16)}
private func wordBE(_ b:[UInt8])->UInt32{b.reduce(UInt32(0)){($0<<8)|UInt32($1)}}
private func wordLE(_ b:[UInt8])->UInt32{b.enumerated().reduce(UInt32(0)){$0|(UInt32($1.element)<<UInt32($1.offset*8))}}
private func expand(_ w:inout [UInt32],_ start:Int=16){
 for i in start..<64{w.append(sigma1(w[i-2]) &+ w[i-7] &+ sigma0(w[i-15]) &+ w[i-16])}
}
private func rounds(_ state:[UInt32],_ w:[UInt32],_ start:Int=0)->[UInt32]{
 var a=state[0],b=state[1],c=state[2],d=state[3],e=state[4],f=state[5],g=state[6],h=state[7]
 for i in start..<64{
  let k:UInt32=(start==14 && i==14) ? 0xC9DC06A7:shaK[i]
  let t1=h &+ (rr(e,6)^rr(e,11)^rr(e,25)) &+ ((e&f)^((~e)&g)) &+ k &+ w[i]
  let t2=(rr(a,2)^rr(a,13)^rr(a,22)) &+ ((a&b)^(a&c)^(b&c))
  h=g;g=f;f=e;e=d &+ t1;d=c;c=b;b=a;a=t1 &+ t2
 }
 return[a,b,c,d,e,f,g,h]
}
private func tokenSHA(_ data:[UInt8])->[UInt8]{
 let terms:[UInt32]=[0xEB24BF9E,0x1558691F,0xA0C09EE2,0x0CFA32BA,0xA622EE8C,0xD1DD9491,0xC0DD25A0,0xF9E70AB6,0xF0C31573,0x7058CE4E,0x7188E606,0x00E5AB33,0xD258B060,0x72766564]
 var w=[UInt32](repeating:0,count:14)
 w.append(wordBE(Array(data[0..<3])));w.append(wordBE(Array(data[3..<7])))
 for i in 16..<30 {
  var value=terms[i-16]
  if i-2>=14{value = value &+ (i==16 ? sigma1(w[i-2])^0x000B92C0:sigma1(w[i-2]))}
  if i-7>=14{value = value &+ w[i-7]}
  if i-15>=14{value = value &+ (i==29 ? sigma0(w[i-15])^0x059C0B80:sigma0(w[i-15]))}
  w.append(value)
 }
 w.append(sigma1(w[28]) &+ w[23] &+ sigma0(w[15]) &+ w[14] &+ 0xC9DC06A7 &- shaK[14])
 expand(&w,31)
 var state=zip(shaInitial,rounds(tokenState,w,14)).map{$0 &+ $1}
 let length=57+data.count
 var padded=Array(data.dropFirst(7))+[0x80]
 padded += [UInt8](repeating:0,count:((55-length)%64+64)%64)
 let bits=UInt64(length*8)
 for shift in stride(from:56,through:0,by:-8){padded.append(UInt8((bits>>UInt64(shift))&255))}
 for offset in stride(from:0,to:padded.count,by:64){
  var block=(0..<16).map{wordBE(Array(padded[(offset+$0*4)..<(offset+$0*4+4)]))}
  expand(&block)
  state=zip(state,rounds(state,block)).map{$0 &+ $1}
 }
 return state.flatMap{x in [UInt8((x>>24)&255),UInt8((x>>16)&255),UInt8((x>>8)&255),UInt8(x&255)]}
}
private func tokenCS(_ data:[UInt8],_ digest:[UInt8])->[UInt8]{
 let ka=wordLE(Array(digest[0..<4]))|1,kb=wordLE(Array(digest[4..<8]))|1
 let factors=[ka &* 0x82893933,kb &* 0x82893933]
 let coeff:[(UInt32,UInt32)]=[(0xE82E91B1,0xB32700D0),(0x44DE24C6,0x88DFF51D),(0x3BEB65BC,0x29514038),(0xC89C5933,0xB328CBDF),(0x8D1EC211,0xD405B4D5),(0x314EF5D5,0x26E55F3C),(0xE92491B1,0x607801C6),(0xF0A5B9D5,0x82B2C1FB),(0x06064CF3,0xFA51A3DA),(0xDA79FA60,0x207CC464),(0xBED20560,0x3C3C74F3),(0x89F9C9F8,0xD2D14B61),(0x35FA38C6,0xBB04A2C1),(0xCB49E3C6,0xC5626167)]
 var terms=coeff.enumerated().map{$0.element.0 &* factors[$0.offset%2]}
 var offsets=coeff.map{$0.1}
 var b=[UInt8(0)]+data
 while b.count%8 != 0 {b.append(0)}
 for i in 0..<(b.count/4) {
  let word=wordLE(Array(b[(i*4)..<(i*4+4)]))
  var term=word &* (i%2==0 ? ka:kb)
  var offset=rol16(word) &* (i%2==0 ? 0xEF0569FB:0xC31713DB)
  if i==0{term = term &+ (0xF2F90B1A &* factors[0]);offset = offset &+ 0x0B1A0000}
  terms.append(term);offsets.append(offset)
 }
 var swapAcc:UInt32=0,swapLast:UInt32=0,state:UInt32=0,acc:UInt32=0
 for i in stride(from:0,to:terms.count,by:2){
  let x=terms[i],y=terms[i+1]
  var t=rol16(offsets[i] &+ x)
  var q=t &* 0x76F50F34
  swapAcc = swapAcc &+ (rol16(q) &* 0xC3EFEA97 &+ q)
  t=rol16(offsets[i+1] &+ y);q=t &* 0x1881CE3C
  swapLast=rol16(q) &* 0x35BD1EC9 &+ q
  swapAcc = swapAcc &+ swapLast
  state=state &* ka &+ x
  state=rol16(state) &* 0xCF98B111
  state=rol16(state) &* 0x87085B9F
  state=rol16(state) &* 0x12CEB96D
  state=rol16(state) &* 0x257E1D83
  acc = acc &+ state
  t=state &* kb &+ y
  t=rol16(t) &* 0xA27416F5;t=rol16(t) &* 0xD38396FF
  state=rol16(rol16(t) &* 0x7C932B89) &* 0xBFA49F69
  acc = acc &+ state
 }
 let result:[UInt32]=[swapLast ^ state,swapAcc ^ acc]
 var bytes=[UInt8]()
 for word in result {
  bytes.append(UInt8(truncatingIfNeeded:word))
  bytes.append(UInt8(truncatingIfNeeded:word>>8))
  bytes.append(UInt8(truncatingIfNeeded:word>>16))
  bytes.append(UInt8(truncatingIfNeeded:word>>24))
 }
 return bytes
}
private func hex(_ bytes:[UInt8])->String{bytes.map{String(format:"%02X",$0)}.joined()}
private func gec(_ now:TimeInterval)->String{
 let seconds=floor((now+11644473600)/300)*300
 let data=Array((String(format:"%.0f",seconds*10000000)+trustedToken).utf8)
 let digest=tokenSHA(data)
 return hex(tokenCS(data,digest))+"-"+hex(digest)
}
private func stamp()->String{
 let f=DateFormatter();f.locale=Locale(identifier:"en_US_POSIX");f.timeZone=TimeZone(secondsFromGMT:0)
 f.dateFormat="EEE MMM dd yyyy HH:mm:ss 'GMT+0000 (Coordinated Universal Time)'"
 return f.string(from:Date())
}
private func xml(_ text:String)->String{
 text.replacingOccurrences(of:"&",with:"&amp;").replacingOccurrences(of:"<",with:"&lt;").replacingOccurrences(of:">",with:"&gt;").replacingOccurrences(of:"'",with:"&apos;").replacingOccurrences(of:"\"",with:"&quot;")
}
private struct SpeechError:LocalizedError{
 let message:String
 var errorDescription:String?{message}
}
private func synthesize(text:String,output:String,voice:String,rate:String,clock:TimeInterval) async throws {
 let id=UUID().uuidString.replacingOccurrences(of:"-",with:"").lowercased()
 let token=gec(clock)
 let url=URL(string:"wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=\(trustedToken)&ConnectionId=\(id)&Sec-MS-GEC=\(token)&Sec-MS-GEC-Version=2-143.0.3650.75")!
 var request=URLRequest(url:url);request.timeoutInterval=40
 request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0",forHTTPHeaderField:"User-Agent")
 request.setValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold",forHTTPHeaderField:"Origin")
 request.setValue("no-cache",forHTTPHeaderField:"Pragma");request.setValue("no-cache",forHTTPHeaderField:"Cache-Control")
 request.setValue("en-US,en;q=0.9",forHTTPHeaderField:"Accept-Language")
 request.setValue("muid=\(UUID().uuidString.replacingOccurrences(of:"-",with:""));",forHTTPHeaderField:"Cookie")
 let configuration=URLSessionConfiguration.ephemeral
 configuration.timeoutIntervalForRequest=40;configuration.timeoutIntervalForResource=70
 let session=URLSession(configuration:configuration)
 let socket=session.webSocketTask(with:request)
 defer{socket.cancel(with:.normalClosure,reason:nil);session.invalidateAndCancel()}
 socket.resume()
 let timeout=DispatchWorkItem{socket.cancel(with:.goingAway,reason:Data("timeout".utf8))}
 DispatchQueue.global().asyncAfter(deadline:.now()+65,execute:timeout)
 defer{timeout.cancel()}
 do {
  let config="X-Timestamp:\(stamp())\r\nContent-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n{\"context\":{\"synthesis\":{\"audio\":{\"metadataoptions\":{\"sentenceBoundaryEnabled\":\"false\",\"wordBoundaryEnabled\":\"false\"},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}\r\n"
  try await socket.send(.string(config))
  let ssml="<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='zh-CN'><voice name='\(xml(voice))'><prosody pitch='+0Hz' rate='\(xml(rate))' volume='+0%'>\(xml(text))</prosody></voice></speak>"
  try await socket.send(.string("X-RequestId:\(id)\r\nContent-Type:application/ssml+xml\r\nX-Timestamp:\(stamp())Z\r\nPath:ssml\r\n\r\n\(ssml)"))
  var audio=Data()
  receive: while true{
   switch try await socket.receive(){
   case .string(let s):
    if s.contains("Path:turn.end"){break receive}
    if s.contains("Path:response"),s.contains("error"){throw SpeechError(message:s)}
   case .data(let d):
    guard d.count>=2 else{continue}
    let len=Int(d[d.startIndex])*256+Int(d[d.startIndex+1])
    guard len+2<=d.count else{throw SpeechError(message:"Invalid binary speech frame")}
    let header=String(data:d.subdata(in:2..<(len+2)),encoding:.utf8) ?? ""
    if header.contains("Path:audio"),header.contains("Content-Type:audio/mpeg"){audio.append(d.subdata(in:(len+2)..<d.count))}
   @unknown default:break
   }
  }
  guard audio.count>1000 else{throw SpeechError(message:"Microsoft returned no usable MP3 audio")}
  let assetURL=URL(fileURLWithPath:output)
  try audio.write(to:assetURL,options:.atomic)
  let asset=AVURLAsset(url:assetURL)
  let duration=CMTimeGetSeconds(asset.duration)
  guard duration.isFinite,duration>0 else{throw SpeechError(message:"AVFoundation could not read synthesized MP3")}
  print("Microsoft \(voice), rate \(rate): \(audio.count) bytes / \(String(format:"%.3f",duration)) seconds -> \(output)")
 } catch {
  let status=(socket.response as? HTTPURLResponse)?.statusCode
  throw SpeechError(message:"Microsoft speech request failed (HTTP \(status.map(String.init) ?? "unknown")): \(error.localizedDescription)")
 }
}
@main struct MicrosoftSpeech {
 static func main() async{
  do{
   let args=Array(CommandLine.arguments.dropFirst())
   if args.first=="--token"{
    print(gec(args.count>1 ? Double(args[1])!:Date().timeIntervalSince1970));return
   }
   guard args.count>=2 else{throw SpeechError(message:"Usage: microsoft-tts TEXT_FILE OUTPUT_MP3 [VOICE=zh-CN-YunxiNeural] [RATE=-8%]")}
   let text=try String(contentsOfFile:args[0],encoding:.utf8).trimmingCharacters(in:.whitespacesAndNewlines)
   guard !text.isEmpty,text.utf8.count<=4096 else{throw SpeechError(message:"Text must contain 1..4096 UTF-8 bytes")}
   let voice=args.count>2 ? args[2]:"zh-CN-YunxiNeural"
   let rate=args.count>3 ? args[3]:"-8%"
   try await synthesize(text:text,output:args[1],voice:voice,rate:rate,clock:Date().timeIntervalSince1970)
  }catch{fputs("Error: \(error.localizedDescription)\n",stderr);exit(1)}
 }
}
