import AppKit
import CoreGraphics
let width=1920,height=1440
let c=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
for i in 1...12 {
 let url=URL(fileURLWithPath:String(format:"output/frames/scene-%02d.png",i))
 let src=CGImageSourceCreateWithURL(url as CFURL,nil)!
 let im=CGImageSourceCreateImageAtIndex(src,0,nil)!
 c.draw(im,in:CGRect(x:((i-1)%3)*640,y:(3-(i-1)/3)*360,width:640,height:360))
}
let rep=NSBitmapImageRep(cgImage:c.makeImage()!)
try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"output/contact-sheet.png"))
