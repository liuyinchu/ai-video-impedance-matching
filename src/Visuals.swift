import Foundation
import AppKit
import CoreGraphics
import CoreText

private struct Ink {
    static let bg = color(0x0B1220)
    static let panel = color(0x121F31)
    static let edge = color(0x253950)
    static let text = color(0xF2F5FA)
    static let muted = color(0xA5B6CC)
    static let blue = color(0x63DFEF)
    static let orange = color(0xFFA571)
    static let green = color(0x93E6AA)
}
private func color(_ hex: Int, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 255)/255, green: CGFloat((hex >> 8) & 255)/255, blue: CGFloat(hex & 255)/255, alpha: alpha)
}
private func rect(_ c: CGContext,_ x: Double,_ y: Double,_ w: Double,_ h: Double,_ fill: CGColor,_ radius: Double = 0) {
    c.setFillColor(fill)
    let r=CGRect(x:x,y:y,width:w,height:h)
    if radius > 0 { c.addPath(CGPath(roundedRect:r,cornerWidth:radius,cornerHeight:radius,transform:nil)); c.fillPath() }
    else { c.fill(r) }
}
private func line(_ c: CGContext,_ pts: [CGPoint],_ col: CGColor,_ width: Double = 2) {
    guard let p=pts.first else{return}
    c.beginPath(); c.move(to:p)
    for p in pts.dropFirst(){c.addLine(to:p)}
    c.setStrokeColor(col);c.setLineWidth(width);c.setLineCap(.round);c.setLineJoin(.round);c.strokePath()
}
private func ln(_ c: CGContext,_ x1:Double,_ y1:Double,_ x2:Double,_ y2:Double,_ col:CGColor = Ink.edge,_ width:Double=2) {
    line(c,[CGPoint(x:x1,y:y1),CGPoint(x:x2,y:y2)],col,width)
}
private func circle(_ c:CGContext,_ x:Double,_ y:Double,_ r:Double,_ col:CGColor) {
    c.setFillColor(col);c.fillEllipse(in:CGRect(x:x-r,y:y-r,width:r*2,height:r*2))
}
private var textFrameCache = [String: CTFrame]()
private func txt(_ c:CGContext,_ s:String,_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ size:Double=24,_ col:CGColor=Ink.text,_ bold:Bool=false,_ center:Bool=false) {
    let key="\(s)|\(w)|\(h)|\(size)|\(col)|\(bold)|\(center)"
    let frame: CTFrame
    if let cached=textFrameCache[key] { frame=cached }
    else {
        let p=NSMutableParagraphStyle();p.alignment=center ? .center : .left;p.lineSpacing=3
        let path=CGPath(rect:CGRect(x:0,y:0,width:w,height:h),transform:nil)
        var fitted: CTFrame?
        var pointSize=size
        while true {
            let f=CTFontCreateWithName((bold ? "PingFangSC-Semibold":"PingFangSC-Regular") as CFString,CGFloat(pointSize),nil)
            let a=NSAttributedString(string:s,attributes:[
                NSAttributedString.Key(kCTFontAttributeName as String):f,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String):col,
                .paragraphStyle:p
            ])
            let fs=CTFramesetterCreateWithAttributedString(a)
            let candidate=CTFramesetterCreateFrame(fs,CFRange(location:0,length:a.length),path,nil)
            fitted=candidate
            if CTFrameGetVisibleStringRange(candidate).length >= a.length || pointSize <= 12 { break }
            pointSize -= 0.5
        }
        frame=fitted!
        textFrameCache[key]=frame
    }
    c.saveGState();c.translateBy(x:x,y:y+h);c.scaleBy(x:1,y:-1);c.textMatrix = .identity
    CTFrameDraw(frame,c);c.restoreGState()
}
private func arrow(_ c:CGContext,_ x1:Double,_ y:Double,_ x2:Double,_ col:CGColor=Ink.blue) {
    ln(c,x1,y,x2,y,col,3)
    let d:Double=x2>x1 ? -1:1
    line(c,[CGPoint(x:x2+d*9,y:y-5),CGPoint(x:x2,y:y),CGPoint(x:x2+d*9,y:y+5)],col,3)
}
private func panel(_ c:CGContext,_ x:Double,_ y:Double,_ w:Double,_ h:Double) {
    rect(c,x,y,w,h,Ink.panel,18)
}
private func badge(_ c:CGContext,_ s:String,_ x:Double,_ y:Double,_ w:Double,_ col:CGColor=Ink.blue) {
    rect(c,x,y,w,34,Ink.panel,8);txt(c,s,x,y+4,w,28,16,col,true,true)
}
private func wave(_ c:CGContext,_ x0:Double,_ x1:Double,_ y:Double,_ a:Double,_ pos:Double,_ col:CGColor) {
    var pts=[CGPoint]()
    for k in 0...220 {
        let u=Double(k)/220
        let v=exp(-pow((u-pos)/0.055,2))
        pts.append(CGPoint(x:x0+(x1-x0)*u,y:y-a*v))
    }
    line(c,pts,col,3.6)
}
private func waveLine(_ c:CGContext,_ y:Double,_ gamma:Double,_ load:String,_ t:Double,_ compact:Bool=false) {
    let x0=160.0,x1=1000.0
    ln(c,x0,y,x1,y,Ink.edge,3)
    let cyc=t.truncatingRemainder(dividingBy:7.5)
    if cyc<3.0 { wave(c,x0,x1,y,compact ? 31:55,cyc/3,Ink.blue) }
    else if cyc<6.0 && abs(gamma)>0.001 { wave(c,x0,x1,y,(compact ? 31:55)*gamma,1-(cyc-3)/3,Ink.orange) }
    rect(c,1006,y-30,144,60,Ink.panel,12)
    txt(c,load,1006,y-18,144,45,compact ? 22:26,abs(gamma)<0.001 ? Ink.green:Ink.orange,true,true)
    circle(c,x0,y,5,Ink.blue)
    if !compact {
        txt(c,"入射电压波",160,y-112,240,35,19,Ink.blue)
        txt(c,"返回电压波",160,y+65,240,35,19,Ink.orange)
        arrow(c,370,y-95,470,Ink.blue);arrow(c,470,y+82,370,Ink.orange)
    }
}
private func drawScene(_ c:CGContext,_ s:Scene,_ t:Double,_ duration:Double) {
    switch s.id {
    case 1:
        badge(c,"一个接头，也会改变信号的去向",64,200,350)
        waveLine(c,370,1.0/3,"100 Ω",t)
        txt(c,"50 Ω 传输线",470,475,330,45,27,Ink.text,true,true)
        txt(c,"先看反射，再谈功率",64,550,1152,36,21,Ink.muted,false,true)
    case 2:
        let labels=[("R","电阻","把电能转成热"),("L","电感","用磁场暂存能量"),("C","电容","用电场暂存能量")]
        for (i,v) in labels.enumerated() {
            let x=64.0+Double(i)*391
            panel(c,x,208,370,172)
            txt(c,v.0,x+22,225,70,62,44,i==0 ? Ink.orange:Ink.blue,true)
            txt(c,v.1,x+106,234,200,40,26,Ink.text,true)
            txt(c,v.2,x+22,319,330,35,20,Ink.muted)
        }
        panel(c,64,406,540,168)
        txt(c,"Z = R + jX",84,423,500,60,38,Ink.blue,true,true)
        txt(c,"R：耗能     X：储能与相位",84,505,500,45,22,Ink.muted,false,true)
        var a=[CGPoint](),b=[CGPoint]()
        for i in 0...220 {
            let u=Double(i)/220,ph=u*Double.pi*4-t*1.4
            a.append(CGPoint(x:660+u*500,y:480-32*sin(ph)))
            b.append(CGPoint(x:660+u*500,y:480-32*sin(ph-0.85)))
        }
        ln(c,660,480,1160,480);line(c,a,Ink.blue,3);line(c,b,Ink.orange,3)
        txt(c,"电压",690,535,120,34,18,Ink.blue);txt(c,"电流（示意）",910,535,240,34,18,Ink.orange)
    case 3:
        panel(c,64,205,1152,365)
        txt(c,"线缆内部：分布电感 + 分布电容",94,224,1080,40,23,Ink.muted)
        let y=346.0
        var wireEnd=124.0
        for i in 0..<6 {
            let coilX=185.0+Double(i)*162
            ln(c,wireEnd,y,coilX-6.5,y,Ink.blue,3)
            wireEnd=coilX+45.5
        }
        ln(c,wireEnd,y,1100,y,Ink.blue,3)

        ln(c,124,460,1100,460,Ink.edge,3)
        for i in 0..<6 {
            let x=185.0+Double(i)*162
            for j in 0..<4 {
                c.setStrokeColor(Ink.blue);c.setLineWidth(3)
                c.addArc(center:CGPoint(x:x+Double(j)*13,y:y),radius:6.5,startAngle:Double.pi,endAngle:0,clockwise:false);c.strokePath()
            }
            let cx=x+72
            ln(c,cx,y,cx,390,Ink.blue);ln(c,cx-16,390,cx+16,390,Ink.blue,3)
            ln(c,cx-16,401,cx+16,401,Ink.blue,3);ln(c,cx,401,cx,460,Ink.blue)
            circle(c,cx,y,4,Ink.blue)
            let dot=124+(t*100+Double(i)*160).truncatingRemainder(dividingBy:970)
            circle(c,dot,y,3.5,Ink.green)
        }
        txt(c,"Z₀ = V⁺ / I⁺",104,488,470,60,32,Ink.blue,true)
        txt(c,"50 Ω  ≠  线的直流电阻",644,496,510,52,27,Ink.orange,true,true)
    case 4:
        waveLine(c,370,1.0/3,"100 Ω",t)
        badge(c,"Z₀ = 50 Ω",470,224,240)
        txt(c,"接口处，电压与电流必须同时满足负载关系",64,520,1152,40,25,Ink.text,false,true)
        txt(c,"示意：只展示一次末端反射",64,563,1152,24,15,Ink.muted,false,true)
    case 5:
        panel(c,64,208,1152,100)
        txt(c,"Γ = (100 − 50) / (100 + 50) = +1/3",84,231,1112,60,33,Ink.blue,true,true)
        let vals=[("电压幅度比","33.3%","Γ = +1/3",1.0/3,Ink.orange),("反射功率比","11.1%","|Γ|² = 1/9",1.0/9,Ink.orange),("负载吸收比","88.9%","1 − |Γ|² = 8/9",8.0/9,Ink.green)]
        for (i,v) in vals.enumerated() {
            let x=64+Double(i)*391
            panel(c,x,332,370,224)
            txt(c,v.0,x+24,350,322,34,21,Ink.muted)
            txt(c,v.1,x+24,393,322,62,45,v.4,true)
            rect(c,x+24,470,322,8,Ink.edge,4)
            rect(c,x+24,470,322*v.3*min(1,t/2.0),8,v.4,4)
            txt(c,v.2,x+24,503,322,35,23,Ink.text)
        }
        txt(c,"条件：无损线、实数 Z₀；功率均相对入射波",64,569,1152,25,15,Ink.muted,false,true)
    case 6:
        let values=[(-1.0/3,"25 Ω","Γ = −1/3","电压反相"),(0.0,"50 Ω","Γ = 0","无末端反射"),(1.0/3,"100 Ω","Γ = +1/3","电压同相")]
        for (i,v) in values.enumerated() {
            let y=267+Double(i)*125
            panel(c,64,y-43,1152,105)
            waveLine(c,y,v.0,v.1,t,true)
            txt(c,v.2,80,y-32,190,32,19,abs(v.0)<0.01 ? Ink.green:Ink.orange,true)
            txt(c,v.3,790,y+22,198,29,16,Ink.muted,false,true)
        }
        txt(c,"同一条 50 Ω 线 · ±1/3 的反射电压，对应相同的 1/9 反射功率",64,579,1152,28,17,Ink.muted,false,true)
    case 7:
        panel(c,64,208,1152,148)
        txt(c,"1 m 线路",94,227,220,36,24,Ink.text,true)
        ln(c,350,276,1100,276,Ink.edge,4)
        circle(c,350+(t.truncatingRemainder(dividingBy:3)/3)*750,276,9,Ink.blue)
        txt(c,"传播速度假设：2 × 10⁸ m/s  →  单程延时 5 ns",350,304,800,35,22,Ink.blue)
        panel(c,64,380,557,185);panel(c,645,380,571,185)
        txt(c,"慢变化：1 ms",90,400,500,42,28,Ink.text,true)
        txt(c,"5 ns 相比之下很短",90,459,500,40,23,Ink.muted)
        txt(c,"常可近似集中参数电路",90,510,500,34,20,Ink.muted)
        txt(c,"快边沿：1 ns",671,400,510,42,28,Ink.orange,true)
        txt(c,"5 ns 已不可忽略",671,459,510,40,23,Ink.orange)
        txt(c,"需要分析传播与反射",671,510,510,34,20,Ink.text)
    case 8:
        badge(c,"Vs = 10 V（直流） · Rs = 50 Ω",64,204,450)
        let x0=116.0,y0=528.0,pw=722.0,ph=238.0
        for j in 0...5 {
            let y=y0-Double(j)*ph/5
            ln(c,x0,y,x0+pw,y,Ink.edge,1)
        }
        ln(c,x0,y0,x0+pw+15,y0,Ink.muted,2)
        ln(c,x0,y0,x0,y0-ph-14,Ink.muted,2)
        var pts=[CGPoint]()
        for k in 0...400 {
            let r=Double(k)/2
            let p=100*r/pow(50+r,2)
            pts.append(CGPoint(x:x0+r/200*pw,y:y0-p/0.55*ph))
        }
        line(c,pts,Ink.blue,4)
        let hx=x0+50/200*pw,hy=y0-0.5/0.55*ph
        circle(c,hx,hy,7+1.5*sin(t*2),Ink.orange)
        ln(c,hx,hy,hx,y0,Ink.orange,1)
        txt(c,"50 Ω",hx-42,y0+10,100,32,18,Ink.orange,true,true)
        txt(c,"0",96,540,40,26,16,Ink.muted)
        txt(c,"200 Ω",782,540,100,26,16,Ink.muted)
        txt(c,"负载功率 PL（W）",108,246,650,34,19,Ink.muted)
        panel(c,903,255,313,308)
        txt(c,"最大负载功率",926,278,268,36,21,Ink.muted)
        txt(c,"0.50 W",926,321,268,65,43,Ink.blue,true)
        txt(c,"此时模型效率",926,420,268,34,20,Ink.muted)
        txt(c,"50%",926,463,268,65,43,Ink.orange,true)
        txt(c,"PL = Vs² RL / (Rs + RL)²",110,580,770,26,17,Ink.muted)
    case 9:
        panel(c,64,214,557,342);panel(c,645,214,571,342)
        txt(c,"线路末端：少反射",92,239,500,45,28,Ink.blue,true)
        txt(c,"ZL = Z₀",92,314,500,64,43,Ink.blue,true,true)
        txt(c,"50 Ω 线路 → 50 Ω 负载",92,416,500,50,25,Ink.text,false,true)
        txt(c,"匹配对象：负载与传输线",92,501,500,32,18,Ink.muted,false,true)
        txt(c,"固定源：最大平均功率",673,239,515,45,27,Ink.orange,true)
        txt(c,"ZL = ZS*",673,314,515,64,43,Ink.orange,true,true)
        txt(c,"源：50 + j20 Ω",673,408,515,44,25,Ink.text,false,true)
        txt(c,"负载：50 − j20 Ω",673,450,515,44,25,Ink.text,false,true)
        txt(c,"* 表示复共轭；指定频率、线性源模型",673,511,515,28,16,Ink.muted,false,true)
        txt(c,"两个条件，两个问题",64,574,1152,30,20,Ink.text,true,true)
    case 10:
        panel(c,64,208,1152,355)
        txt(c,"线侧看到",94,231,270,36,22,Ink.muted,true)
        txt(c,"50 Ω",94,278,270,65,44,Ink.blue,true)
        txt(c,"固定负载",932,231,248,36,22,Ink.muted,true)
        txt(c,"200 Ω",932,278,248,65,44,Ink.orange,true)
        arrow(c,315,350,475)
        for i in 0..<3 {
            c.setStrokeColor(Ink.blue);c.setLineWidth(4)
            c.addArc(center:CGPoint(x:534,y:320+Double(i)*20),radius:10,startAngle:-Double.pi/2,endAngle:Double.pi/2,clockwise:false);c.strokePath()
        }
        for i in 0..<6 {
            c.setStrokeColor(Ink.orange);c.setLineWidth(4)
            c.addArc(center:CGPoint(x:654,y:290+Double(i)*20),radius:10,startAngle:Double.pi/2,endAngle:Double.pi*1.5,clockwise:false);c.strokePath()
        }
        ln(c,582,275,582,417,Ink.muted,3);ln(c,595,275,595,417,Ink.muted,3)
        arrow(c,715,350,888,Ink.orange)
        txt(c,"N₁ : N₂ = 1 : 2",423,438,380,45,28,Ink.text,true,true)
        txt(c,"Zin = (1/2)² × 200 Ω = 50 Ω",110,503,1060,45,29,Ink.blue,true,true)
        txt(c,"理想模型；实际网络需要考虑工作频率、带宽与损耗",64,579,1152,28,17,Ink.muted,false,true)
    case 11:
        panel(c,64,208,1152,355)
        badge(c,"音频线电平 · 电压传递优先",94,229,390)
        panel(c,100,300,312,110);panel(c,869,300,310,110)
        txt(c,"输出阻抗",122,313,268,34,20,Ink.muted,false,true)
        txt(c,"100 Ω",122,355,268,45,30,Ink.blue,true,true)
        arrow(c,448,355,833)
        txt(c,"输入阻抗",890,313,268,34,20,Ink.muted,false,true)
        txt(c,"10 kΩ",890,355,268,45,30,Ink.green,true,true)
        txt(c,"输入电压 / 开路电压 = 10000 / 10100",100,445,1080,40,25,Ink.text,false,true)
        rect(c,110,513,910,12,Ink.edge,6)
        rect(c,110,513,910*10000/10100*min(1,t/2),12,Ink.green,6)
        txt(c,"≈ 99.0%",1040,487,155,55,30,Ink.green,true)
        txt(c,"称为阻抗桥接：Zin ≫ Zout",64,579,1152,28,20,Ink.muted,false,true)
    default:
        let rows=[("01","少反射","负载 ZL = 线路 Z₀",Ink.blue),("02","最大功率","负载 ZL = 源 ZS 的共轭",Ink.orange),("03","保住电压","常用低输出阻抗 → 高输入阻抗",Ink.green)]
        for (i,v) in rows.enumerated() {
            let y=211+Double(i)*109
            panel(c,64,y,1152,92)
            txt(c,v.0,89,y+22,82,55,31,v.3,true)
            txt(c,v.1,195,y+25,230,45,28,v.3,true)
            txt(c,v.2,469,y+29,700,44,25,Ink.text)
        }
        txt(c,"让连接服务于目标。",64,550,1152,40,27,Ink.text,true,true)
        txt(c,"技术参考：Analog Devices · Keysight · Texas Instruments",64,590,1152,24,14,Ink.muted,false,true)
    }
}

func drawFrame(context c:CGContext,width:Int,height:Int,scene:Scene,elapsed:Double,duration:Double,caption:String,globalTime:Double,totalDuration:Double) {
    c.saveGState()
    c.translateBy(x:0,y:CGFloat(height));c.scaleBy(x:CGFloat(width)/1280,y:-CGFloat(height)/720)
    rect(c,0,0,1280,720,Ink.bg)
    for x in stride(from:0,through:1280,by:40){ln(c,Double(x),0,Double(x),607,color(0x17263A,0.4),0.5)}
    for y in stride(from:0,through:600,by:40){ln(c,0,Double(y),1280,Double(y),color(0x17263A,0.4),0.5)}
    rect(c,64,41,5,21,Ink.blue,2)
    txt(c,scene.kicker,82,37,800,35,17,Ink.blue,true)
    txt(c,"IMPEDANCE MATCHING",910,39,305,28,14,Ink.muted,false,false)
    txt(c,scene.title,64,82,1152,60,38,Ink.text,true)
    txt(c,scene.subtitle,64,149,1152,39,20,Ink.muted)
    drawScene(c,scene,elapsed,duration)
    rect(c,0,612,1280,108,color(0x080E18))
    ln(c,64,612,1216,612,Ink.edge,1)
    if !caption.isEmpty { txt(c,caption,86,625,1108,76,25,Ink.text,false,true) }
    rect(c,0,716,1280,4,Ink.edge)
    rect(c,0,716,1280*min(1,max(0,globalTime/max(1,totalDuration))),4,Ink.blue)
    c.restoreGState()
}
