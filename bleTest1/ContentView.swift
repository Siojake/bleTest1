//
//  ContentView.swift
//  bleTest1
//
//  Created by jake on 2024/02/06.
//
import SwiftUI
import CoreBluetooth
import Foundation


class ImuData: Codable {
    /*
     @State var no: UInt32
     @State var usec: UInt32
     @State var val: [Float] = [0,0,0, 0,0,0, 0,0,0]
     */
    var no: UInt32
    var usec: UInt32
    var val: [Float] = [0,0,0, 0,0,0, 0,0,0]
    
    init(){
        self.no = 0
        self.usec = 0
    }
    
    init(data: Data){
        self.no = Data(data[0...3]).withUnsafeBytes { $0.load( as: UInt32.self) }
        self.usec = Data(data[4...7]).withUnsafeBytes { $0.load( as: UInt32 .self) }
        for i in  0 ..< 9 {
            self.val[i] = Data(data[i*4+8...i*4+11]).withUnsafeBytes{ $0.load( as: Float.self) }
        }
    }
}



struct SpdData {
    @State var no: UInt32
    @State var speed: Float
    @State var trigger: UInt32
    @State var rear:  UInt32
    @State var front: UInt32
    @State var trigC: UInt32
    @State var rearC: UInt32
    @State var frntC: UInt32
    @State var endC: UInt32
    @State var bulkCount: UInt32

    init(data: Data) {
        self.no = Data(data[0...3]).withUnsafeBytes { $0.load( as: UInt32.self) }
        self.speed = Data(data[4...7]).withUnsafeBytes { $0.load( as: Float.self) }
        self.trigger   = Data(data[8...11]).withUnsafeBytes { $0.load( as: UInt32.self) }
        self.rear   = Data(data[12...15]).withUnsafeBytes { $0.load( as: UInt32.self) }
        self.front  = Data(data[16...19]).withUnsafeBytes { $0.load( as: UInt32.self) }
        self.trigC  = Data(data[20...23]).withUnsafeBytes { $0.load( as: UInt32.self) }
        self.rearC  = Data(data[24...27]).withUnsafeBytes { $0.load( as: UInt32.self) }
        self.frntC  = Data(data[28...31]).withUnsafeBytes { $0.load( as: UInt32.self) }
        self.endC = 0
        self.bulkCount = 32
        //        self.endC   = Data(data[32...25]).withUnsafeBytes { $0.load( as: UInt32.self) }
        //dy   = Data(data[36...39]).withUnsafeBytes { $0.load( as: Float.self) }
        //dz   = Data(data[40...43]).withUnsafeBytes { $0.load( as: Float.self) }
    }
}


class OneShot: Codable , Identifiable {
    
    var date:  String
    var speed: Float
    var front: UInt32
    var rear:  UInt32
    var place: String
    var target: String

    var imudatas: [ImuData]
    
    init() {
        self.date = ""
        self.speed = 0.0
        self.place = ""
        self.target = ""
        self.rear = 0
        self.front = 0
        var shots = [ImuData]()
        self.imudatas = shots
        /*for i in 0 ..< 512 {
         var imud = ImuData()
         self.imudatas.append(imud)
         }
         */
    }
}





let ServerName = String("BulletVelocityMeter")
let serviceUUID: CBUUID = CBUUID(string:"9e03a9fc-9690-11ee-b9d1-0242ac120002")
let CharSpdUUIDStr = String("be7ddf90-9690-11ee-b9d1-0242ac120002")
let CharIMUUUIDStr = String("cb01e90a-9690-11ee-b9d1-0242ac120002")
let CharSpdUUID: CBUUID = CBUUID(string:CharSpdUUIDStr)
let CharImuUUID: CBUUID = CBUUID(string:CharIMUUUIDStr)

class BluetoothViewModel: NSObject, ObservableObject {
    private var centralManager: CBCentralManager?
    private var peripherals: [CBPeripheral] = []
    @Published var peripheralNames: [String] = []
    @Published var speeds: String = ""
    @State     var connected: Bool = false
    //@State     var reonnect: String = ""
    @Published var connectState: String = "not Connected"
    //@Published var dates: [String] = []
    @Published var shot: OneShot = OneShot()
    @Published var shots: [OneShot] = [OneShot]()
    //var myShot : OneShot = OneShot()
    
    @State var count: Int = 0
    var map = [UInt](repeating: 0, count: 512)
    var vTimer:Timer = Timer()
    private var target: CBPeripheral?
    private var charSpd : CBCharacteristic?
    private var charIMU : CBCharacteristic?
    var semT = DispatchSemaphore(value: 1)
    var checkf : Bool = true // need check default
    @Published var place : String = ""
    var bulkCount :UInt32 = 32
    
    
    
    override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: .main)
        printFiles()
    }
    
    func printFiles() {
        let fileManager = FileManager.default
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil, options: [])
                for fileURL in fileURLs {
                    print(fileURL.path)
                }
            } catch {
                print("エラー: \(error)")
            }
        }
       
    }
    
    
}// class BluetoothViewModel

extension BluetoothViewModel: CBCentralManagerDelegate,CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            self.centralManager?.scanForPeripherals(withServices: nil)
            //self.centralManager!.scanForPeripherals(withServices: [serviceUUID] , options: nil)
        }
    }
    
    func reconnect(){
        print("recconect")
        if (self.connected){
            self.centralManager!.cancelPeripheralConnection(target!)
            self.connected = false
            self.centralManager!.connect(target! , options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        
        if !peripherals.contains(peripheral) {
            self.peripherals.append(peripheral)
            //print("per:"+peripheral.name!)
            if peripheral.name == ServerName {
                self.peripheralNames.append(peripheral.name!)
                self.target=peripheral
                self.centralManager?.stopScan()
                self.centralManager!.connect(target! , options: nil)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral){
        target?.delegate = self
        
        self.connectState = ServerName
        self.connected = true
        // 指定のサービスを探す
        target!.discoverServices([serviceUUID])
        
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnect peripheral: CBPeripheral){
        target?.delegate = self
        self.connected = false
        self.connectState = "Disconnected "
        
        
        
        
    }// service discover
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        for service in target!.services! {
            print(service.uuid)
            if(service.uuid == serviceUUID) {
                print("found service")
                target?.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characreristic in service.characteristics!{
            print(characreristic.uuid)
            if characreristic.uuid == CharSpdUUID {
                print("CharSpdUUIDStr ")
                charSpd = characreristic
                peripheral.setNotifyValue(true, for: charSpd!)
                
            }
            
            if characreristic.uuid == CharImuUUID {
                print("CharIMUUUIDStr ")
                charIMU = characreristic
                peripheral.setNotifyValue(true, for: charIMU!)
            }
        }
    }
    
    //func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
    //error: Error?) {
    //  log.append("ペリフェラルから値を取得しました。\n")
    
    //  log.append("キャラクタリスティックの値：\(characteristic.value)\n")
    //}
    
    func checkMap(block:UInt32) -> Int {
        
        var ret:Int = 0
        var n:Int = 0
        struct reqBlk {
            var id: UInt32 = 0x2000 // AckMark
            var count: UInt16 = 0
            var no = [UInt16](repeating: 0, count: 32)
        }
        var req = reqBlk()
        let blockNo :UInt = UInt(block & 0x3ff)
        
        // check semaphore
        defer {
            semT.signal()
        }
        semT.wait()
        
        if (self.checkf) {
            for i:UInt in 0 ..< 32 {
                if (self.map[Int(i+blockNo)] == 0) {
                    req.no[n] = UInt16(blockNo + i)
                    n += 1
                }
            }
            if (n > 1) {
                ret = 0
                req.count = UInt16(n)
                var data = Data(bytes: &req.id, count: MemoryLayout.size(ofValue: req.id))
                data.append(Data(bytes: &req.count, count: MemoryLayout.size(ofValue: req.count)))
                for i in 0 ..< 18 {
                    data.append(Data(bytes: &req.no[i], count: MemoryLayout.size(ofValue: req.no[i])))
                }
                
                target?.writeValue(data, for: charIMU!, type: .withoutResponse)
            }
            self.checkf = false // nop need check
        }
        return ret
    }
    
    //func peripheral(_ peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic,
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    
                    error: Error?)
    {
        //print("データ更新！ characteristic UUID: \(characteristic.uuid), value: \(String(describing: characteristic.value))")
        
        if let error = error {
            print("データ更新通知エラー: \(error)")
            return
        }
        
        if characteristic.uuid == CharSpdUUID {
            print("SppedChara")
            
            speeds = String(decoding: characteristic.value!,  as:  UTF8.self)
            print(speeds)
            self.shot = OneShot()
            
        }
        
        if characteristic.uuid == CharImuUUID{
            //print("imuChar")
            
            
            var imud:ImuData = ImuData(data: characteristic.value!)
            //print(imud.no)
            if (imud.no & 0xf000) == 0x4000 {
                // infomark
                
                
                var spdd:SpdData = SpdData(data: characteristic.value!)
                print("trig:\(spdd.trigger) read:\(spdd.rear) front:\(spdd.front)")
                
                let df = DateFormatter()
                //df.dateFormat = "yyMMdd-HHmmss"
                df.dateFormat = "yyMMdd\nHHmmss"
                //var date:Date = Date()
                self.shot = OneShot()
                
                self.shot.date = df.string(from: Date())
                self.shot.speed = spdd.speed
                self.shot.place = self.place
                self.shot.front = spdd.front
                self.shot.rear  = spdd.rear
                self.bulkCount  = spdd.bulkCount
            
                self.map = [UInt](repeating: 0, count: 512)
                
                
                
                
                //self.dates.append(datestr)
                
                
                //for i in 0..<512 {
                //    self.map[i] = 0
                //    print("rst: \(self.map[i]) \n")
                //}
            }
            if (imud.no & 0xf000) == 0x8000 {
                //imu Data
                var dived: Int = 0
                dived = Int((imud.no+1) % self.bulkCount) // checking every 32 data
                imud.no = imud.no % 1000
                //print("bef imud \(imud.no) dived \(dived) self.map[dived] \(self.map[dived])")
                //if imud.no == 0 {
                //    self.shot.imudatas = [ImuData]()
                //}
                self.map[dived] = 1
                // print("aft: \(self.map[dived]) \n")
                var myTimer: Timer = Timer()
                if ( dived == 0 ){ // first block data
                    // start timer
                    DispatchQueue.global().async {
                        myTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
                            var n=self.checkMap(block: imud.no)
                            if n > 0 {
                                print("checkMap resend \(n)")
                            }
                        }
                    }
                }
                if (dived == 31) {
                    // disable timer
                    myTimer.invalidate()
                    // block receive done
                    var n=self.checkMap(block: imud.no)
                    if n > 0  {
                        print("checkMap resend \(n)")
                    }
                }
                
                self.map[dived] = 1
                self.shot.imudatas.append(imud)
                self.count += 1
                if imud.no == 511 {
                    var date=Date()
                    
                    let df = DateFormatter()
                    df.dateFormat = "yyMMdd_HHmmss"
                    
                    let path = NSHomeDirectory() + "/Documents/"+df.string(from: date)+".json"
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    
                    do {
                        var data = try encoder.encode(self.shot)
                        var save = self.shot
                        var jsonstr:String = String(data: data, encoding: .utf8 )!
                        // テキストの書き込みを実行
                        try jsonstr.write(toFile: path, atomically: true, encoding: .utf8)
                        print("open", path)
                        print("indraw0 \(self.shot.imudatas.count)")
                        self.shot = save
                        print("indraw00 \(self.shot.imudatas.count)")
                        //for i in 0 ..< self.shots.count {
                        //    print( "b\(i): \(self.shots[i].speed) \(self.shots[i].imudatas.count)")
                        
                        //}
                        // var imusave : [ImuData] = self.shot.imudatas
                        
                        self.shots.append( self.shot )
                        //self.shots[self.shots.count-1].imudatas = imusave
                        
                        //for i in 0 ..< self.shot.imudatas.count {
                        //    for v in 0 ..< 9 {
                        //        self.shots[self.shots.count-1].imudatas.append.val( self.shot.imudatas.val[v])
                        //    }
                        //}
                        //
                        
                        //for i in 0 ..< self.shots.count{
                        //    print( "a\(i): \(self.shots[i].speed) \( self.shots[i].imudatas)")
                        //}
                        //if let selectedShot = self.shots.last {
                        //print("Selected shot: \(selectedShot)")
                        
                        // imudatasが正しく設定されているか確認
                        //print("Imudatas of selected shot before update: \(selectedShot.imudatas.count)")
                        /*
                         // imudatasを更新した後の要素数を出力
                         selectedShot.imudatas = sht.imudatas
                         print("Imudatas of selected shot after update: \(selectedShot.imudatas)")
                         
                         print("button \(selectedShot.imudatas.count)")
                         */
                        // }
                    } catch {
                        //　テストの書き込みに失敗
                        print("失敗:", error )
                    }
                    imud.no = 0
                    //self.shot.imudatas = []
                    print("ok")
                }
            }
        }
    }
    
    
    
}// extension BluetoothView




struct ContentView: View {
    //@ObservedObject private var bluetoothViewModel = BluetoothViewModel()
    @StateObject var bluetoothViewModel = BluetoothViewModel()
    //@State var connectState: String = "not connected"
    var bounds = UIScreen.main.bounds
    
    func elipsepath (in rect: CGRect) -> Path {
        let path = Path () { path in
            path.addPath(Ellipse().path(in: rect))
        }
        return path;
    }
    var body: some View {
        
        VStack {
            HStack {
                
                Text(bluetoothViewModel.connectState)
                
                Button("Reconnect"){
                    bluetoothViewModel.reconnect()
                }
                .background(bluetoothViewModel.connected ? Color.red: Color.black)
                .foregroundColor(bluetoothViewModel.connected ? Color.red: Color.black)
                .disabled(bluetoothViewModel.connected)
                
            }
            
            HStack {
                List(bluetoothViewModel.shots.reversed()) { sht in
                    Button {
                        bluetoothViewModel.shot = sht
                        print("button \(sht.imudatas.count)")
                        print("button \(sht.date)")
                        //if let selectedShot = bluetoothViewModel.shots.last {
                        //    print("button \(selectedShot.imudatas.count)")
                        //}
                        //if let selectedShot = bluetoothViewModel.shots.last {
                        //    print("Selected shot: \(selectedShot)")
                        //
                        //    // imudatasが正しく設定されているか確認
                        //    print("Imudatas of selected shot before update: \(selectedShot.imudatas)")
                        //
                        //    // imudatasを更新した後の要素数を出力
                        //    selectedShot.imudatas = sht.imudatas
                        //    print("Imudatas of selected shot after update: \(selectedShot.imudatas)")
                        //
                        //   print("button \(selectedShot.imudatas.count)")
                        //}
                    }
                label: {
                    Text(sht.date)
                        .frame(maxWidth:85)
                    //   }
                    //List(0..<bluetoothViewModel.dates.count) {
                    //    Text(bluetoothViewModel.dates[$0])
                    //        .frame(width:85)
                    
                }
                .border(Color.gray,width:1)
                .frame(width:95)
                .listRowSeparator(.hidden)
                }.frame(width:90)
                VStack{
                    Text(bluetoothViewModel.speeds)
                    
                    // plate target
                    Canvas(
                        opaque: true,
                        colorMode: .linear,
                        rendersAsynchronously: false
                    ) { context, size in
                        context.opacity = 0.3
                        /*
                         var targetWidth:CGFloat  = size.width / 5
                        var targetHeight:CGFloat  = size.height / 3
                        var ox = targetWidth / 2
                        var oy = targetHeight / 2

                        for var y in 0 ..< 3 {
                            var tx:CGFloat = targetWidth / 2
                            var ty:CGFloat = targetHeight / 2
                            if y == 0 {
                                tx = tx * 0.8
                                ty = ty * 0.8
                            }
                            for var x in 0 ..< 5 {
                                Ellipse()
                            }
                        }
                        */
                        VStack {
                            HStack{
                                Canvas(
                                    opaque: true,
                                    colorMode: .linear,
                                    rendersAsynchronously: false
                                ) { context, size in
                                    context.opacity = 0.3
                                }
                                Canvas(
                                    opaque: true,
                                    colorMode: .linear,
                                    rendersAsynchronously: false
                                ) { context, size in
                                    context.opacity = 0.3
                                }
                                Canvas(
                                    opaque: true,
                                    colorMode: .linear,
                                    rendersAsynchronously: false
                                ) { context, size in
                                    context.opacity = 0.3
                                }
                                Canvas(
                                    opaque: true,
                                    colorMode: .linear,
                                    rendersAsynchronously: false
                                ) { context, size in
                                    context.opacity = 0.3
                                }
                                
                            }
                        }
                        
                    } .border(Color.cyan)
                    // gyro output
                    Canvas(
                        opaque: true,
                        colorMode: .linear,
                        rendersAsynchronously: false
                        
                    ) { context, size in
                        print("size \(size)")
                        
                        let p1 = Path{path in
                            path.move(to: CGPoint(x: 0,y: size.height/2))
                            path.addLine(to: CGPoint(x: size.width, y: size.height/2 ))
                        }
                        context.stroke(p1, with: .color(.cyan))
                        // ruler draw
                        for i in 0 ..< 10 {
                            var sx:CGFloat = size.width/10
                            let p2 = Path {path in
                                path.move(to: CGPoint(x: CGFloat( sx*CGFloat(i) ), y: size.height/2-5  ))
                                path.addLine(to: CGPoint(x: CGFloat( sx*CGFloat(i) ) , y: size.height/2+5 ) )
                            }
                            context.stroke(p2, with: .color(.cyan))
                        }
                        // get pathes
                        print("indraw1 \(bluetoothViewModel.shot.imudatas.count)")
                        print("indraw2 \(bluetoothViewModel.shot.imudatas.count)")
                        if (bluetoothViewModel.shot.imudatas.count == 512 ){
                            
                            var paths:[Path] = drawLines(view:self , shot: bluetoothViewModel.shot, size: size)
                            
                            // {TFT_RED,TFT_BLUE,TFT_GREEN,TFT_OLIVE,TFT_CYAN,TFT_YELLOW};
                            var colors: [Color] = [Color.red,Color.blue,Color.green,Color.brown,Color.brown,Color.yellow]
                            for i in 0 ..< 6 {
                                context.stroke(paths[i], with: GraphicsContext.Shading.color(colors[i]), lineWidth   : 1)
                            }
                        }
                        print("indraw3 \(bluetoothViewModel.shot.imudatas.count)")
                        //context.opacity = 0.3
                        //for i in 0..<bluetoothViewModel.drawPaths?.count  {
                        
                        //}
                        //bluetoothViewModel.paths.forEach {
                        //var epath = Path()
                        
                        /*
                         let path1 = Path {path in
                         path.move(to: CGPoint(x: 50, y: 10))
                         path.addLine(to: CGPoint(x: 100, y: 30))
                         */
                        
                        
                        
                        //let rect = CGRect(origin: .zero, size: size)
                        
                        //var path = Circle().path(in: rect)
                        //context.fill(path, with: .color(.red))
                        
                        //let newRect = rect.applying(.init(scaleX: 0.5, y: 0.5))
                        //path = Circle().path(in: newRect)
                        //context.fill(path, with: .color(.red))
                    } .border(Color.cyan)
                    
                    
                    // speed history
                    Canvas(
                        opaque: true,
                        colorMode: .linear,
                        rendersAsynchronously: false
                    ) { context, size in
                        context.opacity = 0.3
                        
                        
                    } .border(Color.cyan)
                    
                }
            }
            HStack {
                /*
                 Button("Reconnect"){
                 bluetoothViewModel.reconnect()
                 }.background(bluetoothViewModel.connected ? Color.red: Color.black)
                 .foregroundColor(bluetoothViewModel.connected ? Color.red: Color.black)
                 .disabled(!bluetoothViewModel.connected)
                 
                 */
                /*
                 if (bluetoothViewModel.connected){
                 Button("Reconnect"){
                 bluetoothViewModel.reconnect()
                 }
                 .background(bluetoothViewModel.connected ? Color.red: Color.black)
                 .foregroundColor(bluetoothViewModel.connected ? Color.red: Color.black)
                 .disabled(!bluetoothViewModel.connected)
                 }
                 */
                TextField("PLACE", text: $bluetoothViewModel.place)
                
                //print(bluetoothViewModel.place)
                /*Button("Bulls"){}
                 
                 .background(.blue)
                 .foregroundColor(.white)
                 Button("Plate"){}
                 
                 .background(.blue)
                 .foregroundColor(.white)
                 Button("Shilouette"){}
                 
                 .background(.blue)
                 .foregroundColor(.white)
                 */
            }
        }
    }
}

func drawLines(view: ContentView, shot: OneShot ,size:CGSize) -> [Path] {
    // 描画パス
    var myPath:[Path]  = [Path(),Path(),Path(),Path(),Path(),Path(),Path(),Path(),Path()]
    // 初期位置セット（キャンパスにペンを置く感じ）
    var count = shot.imudatas.count
    
    for p in 0 ..< 9 {
        myPath[p].move(to: CGPoint(x: 0, y: 0))
        // 配列にセットされたデータで描画
        for i in 0 ..< shot.imudatas.count {
            var x : CGFloat = CGFloat(i) * (size.width / 512)
            var y : CGFloat = size.height/2 - CGFloat(shot.imudatas[i].val[p])/100 * size.height/2
            // データ毎にペンを移動させて描く
            
            myPath[p].addLine(to: CGPoint( x:x, y:y))
            
        }
    }
    // 描画パスを返す
    return myPath
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

