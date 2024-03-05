//
//  ContentView.swift
//  bleTest1
//
//  Created by jake on 2024/02/06.
//
import SwiftUI
import CoreBluetooth



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
//        self.endC   = Data(data[32...25]).withUnsafeBytes { $0.load( as: UInt32.self) }
        //dy   = Data(data[36...39]).withUnsafeBytes { $0.load( as: Float.self) }
        //dz   = Data(data[40...43]).withUnsafeBytes { $0.load( as: Float.self) }
    }
}

class OneShot: Codable {
    var date:  Date
    var speed: Float
    var front: UInt32
    var rear:  UInt32
    var place: String

    var imudatas: [ImuData]
    
    init() {
        self.date = Date()
        self.speed = 0.0
        self.place = ""
        self.imudatas = []
        self.rear = 0
        self.front = 0
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
    @Published var connected: Bool = false
    @Published var connectState: String = "not Connected"
    @State var shot: OneShot = OneShot()
    @State var count: Int = 0
    @State var map: [Int] = [ 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                              0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ]
    
    var vTimer:Timer = Timer()
    private var target: CBPeripheral?
    private var charSpd : CBCharacteristic?
    private var charIMU : CBCharacteristic?
    var semT = DispatchSemaphore(value: 1)
    var checkf : Bool = true // need check default
    
    override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: .main)
    }
   
}

extension BluetoothViewModel: CBCentralManagerDelegate,CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            self.centralManager?.scanForPeripherals(withServices: nil)
            //self.centralManager!.scanForPeripherals(withServices: [serviceUUID] , options: nil)
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
        
        connectState = "Connected " + ServerName
        // 指定のサービスを探す
        
        target!.discoverServices([serviceUUID])
        
        
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnect peripheral: CBPeripheral){
        target?.delegate = self
        
        connectState = "Disconnected "
      
        
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
    
    func checkMap(block:UInt32) -> Bool {
        
        var ret:Bool = false
        var n:Int = 0
        struct reqB {
            var id: UInt32 = 2000
            var count: UInt = 0
            var no:[UInt] = [
                0,0,0,0,0,
                0,0,0,0,0,
                0,0,0,0,0,
                0,0,0,0,0
            ]
        }
        var req = reqB()
        let blockNo :UInt = UInt(block & 0xfffffe00)
         
        // check semaphore
        defer {
            semT.signal()
        }
        semT.wait()
        
        if (self.checkf) {
            for i:UInt in 0 ..< 32 {
                if (self.map[Int(i)] == 0) {
                    req.no[n] = blockNo + i
                    n += 1
                }
            }
            if (n > 1) {
                ret=true
                req.count = UInt(n)
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
            if (imud.no / 1000) == 4 {
                // newdata
                var spdd:SpdData = SpdData(data: characteristic.value!)
                print("trig:\(spdd.trigger) read:\(spdd.rear) front:\(spdd.front)")
                
                self.shot.date=Date()
                self.shot.speed = spdd.speed
                self.shot.place = ""
                self.shot.front = spdd.front
                self.shot.rear  = spdd.rear
                for i in 0..<32 {
                    self.map[i]=0
                }
            }
            if (imud.no / 1000) == 8 {
                // 
                var dived: Int = 0
                dived = Int((imud.no) % 32)
                imud.no = imud.no % 1000
                self.map[dived]=1
                var myTimer: Timer = Timer()
                if ( dived == 0 ){ // first block data
                    // start timer
                    DispatchQueue.global().async {
                        myTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
                            if self.checkMap(block: imud.no){
                                
                            }
                        }
                    }
                }
                if (dived == 31) {
                    // disable timer
                    myTimer.invalidate()
                    // block receive done
                    if self.checkMap(block: imud.no) {
                        
                    }
                }
                
                self.map[dived] = 1
                self.shot.imudatas.append(imud)
                self.count += 1
                if imud.no == 511 {
                    var date=Date()

                    let df = DateFormatter()
                    df.dateFormat = "yyyy-MM-dd_HH:mm:ss"
        
                    let path = NSHomeDirectory() + "/Documents/"+df.string(from: date)+".json"
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                 
                    do {
                        var data = try encoder.encode(self.shot)
                        var jsonstr:String = String(data: data, encoding: .utf8 )!
                        // テキストの書き込みを実行
                        try jsonstr.write(toFile: path, atomically: true, encoding: .utf8)
                        print("成功\nopen", path)

                    } catch {
                        //　テストの書き込みに失敗
                        print("失敗:", error )
                    }
                    self.shot.imudatas = []
                    print("ok")
                }
            }
        }
    }

    
    
}

struct ContentView: View {
    @ObservedObject private var bluetoothViewModel = BluetoothViewModel()
    //@State var connectState: String = "not connected"
    var body: some View {
   
        VStack {
            Text(bluetoothViewModel.connectState)
            Text(bluetoothViewModel.speeds)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

