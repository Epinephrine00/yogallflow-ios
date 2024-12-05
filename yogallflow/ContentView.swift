//
//  ContentView.swift
//  yogallflow
//
//  Created by 이두현 on 11/25/24.
//

// Notice
// 저는 iOS 앱 개발이 처음입니다.
// 연습? 예제? 그딴거 없이 그냥 바로 실전 시작했습니다.
// Swift6과 SwiftUI에 대한 이해가 거의 없다시피합니다.
// 코드가 매우 더러울 것 같습니다.
// 하지만 GPT와 협동해서 열심히 짜보았습니다.
// 시발 그냥 도와준단사람 있을때 도와달라 할껄


import SwiftUI
import UniformTypeIdentifiers
import CoreBluetooth
import Foundation

struct ContentView: View {
    var body: some View {
        NavigationView {
            FirstView()
                .navigationBarTitle("First View", displayMode: .inline)
        }
    }
}
func delayExample() async {
    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1밀리초 = 1,000,000 나노초
}

class BLEViewModel: ObservableObject {
    @Published var devices: [BLEDevice] = []
    @Published var showDeviceDialog = false
    var sessionManager: FlowSessionManager?
    
    init() {
        sessionManager = FlowSessionManager()
        sessionManager?.onDeviceDiscovered = { [weak self] peripheral in
            DispatchQueue.main.async {
                let address = peripheral.identifier.uuidString
                if let name = peripheral.name {
                    self?.devices.append(BLEDevice(name: name, address:address, peripheral: peripheral))
                }
            }
        }
    }
    
    func startScan() {
        devices = [] // Clear the list before scanning
        sessionManager?.startScan()
        showDeviceDialog = true
    }
    
    func write(str:String){
        sessionManager?.writeData(to: sessionManager!.writableCharacteristic!,
                                                 peripheral: sessionManager!.discoveredPeripheral!,
                                                 d: str)
    }
}

struct FirstView: View {
    
    @State private var toSecondView = false
    @State private var loadedData: [LEDSequence] = [] // 데이터를 저장할 상태 변수
    @State private var errorMessage: String? = nil // 에러 메시지를 위한 상태 변수
    @State private var showingDocumentPicker = false // 문서 선택기 표시 상태
    @State private var connectionStatus:String? = nil
    @State private var isSending = false
    @StateObject var viewModel = BLEViewModel()
    
    @State private var LEDSets:[[[[Int]]]] = [[[[Int]]]]()
    
    var body: some View {
        VStack {
            if(connectionStatus==nil){
                Text("기기에 연결되지 않았습니다.")
            }
            else{
                Text("\(connectionStatus!)에 연결되었습니다. ")
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(0..<loadedData.count, id: \.self) { index in
                        LEDRowView(ledList: loadedData[index].ledList[0], name:loadedData[index].name) {
                            print("설정 버튼이 눌렸습니다. Index: \(index)")
                            let sendString = "hello from setting \(index)"
                            print(sendString)
                            viewModel.write(str:sendString)
                            
                            
                            if(viewModel.sessionManager?.writableCharacteristic == nil){
                                print("writableCharacteristic is nil")
                                return
                            }
                            else if(viewModel.sessionManager?.discoveredPeripheral==nil){
                                print("discoveredPeripheral is nil")
                                return
                            }
                            else if(viewModel.sessionManager==nil){
                                print("sessionManager is nil")
                                return
                            }
                            else{
                                if(!isSending){
                                    Task{
                                        await writeWithDelay(index:index)
                                    }
                                }
//                                viewModel.write(str:"entry")
//                                
//                                for i in 0..<loadedData[index].ledList.count{
//                                    
//                                    viewModel.write(str:"start")
//                                    let du = "d:\(loadedData[index].duration[i])"
//                                    viewModel.write(str:du)
//                                    
//                                    for j in 0..<12{
//                                        let formattedR = String(format: "%02x", loadedData[index].ledList[i][j][0])
//                                        let formattedG = String(format: "%02x", loadedData[index].ledList[i][j][1])
//                                        let formattedB = String(format: "%02x", loadedData[index].ledList[i][j][2])
//                                        let value = "v:\(j):\(formattedG)\(formattedR)\(formattedB)"
//                                        viewModel.write(str:value)
//                                    }
//                                    
//                                    viewModel.write(str:"end")
//                                }
//                                
//                                viewModel.write(str:"eof")
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .onAppear {
                loadData()
            }
            .frame(maxWidth: .infinity)
            
//            NavigationLink(destination: SecondView(), isActive: $toSecondView){ // pass
//            }
            
            Button("데이터 파일 불러오기") {
                showingDocumentPicker = true
            }
            .buttonStyle(.bordered)
            Button("비활성화된 기능") {//LED 시퀀스 만들기
                //toSecondView = true
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            
            Button("장치에 연결하기") {
                viewModel.startScan()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            
            // Show dialog when devices are discovered
            if viewModel.showDeviceDialog {
                List(viewModel.devices) { device in
                    Text(device.address)
                        .onTapGesture {
                            print("Selected device: \(device.name)")
                            viewModel.sessionManager?.stopScan()
                            viewModel.showDeviceDialog = false
                            viewModel.sessionManager?.centralManager.connect(device.peripheral)
                            connectionStatus = device.address
                        }
                }
                .frame(maxHeight: 300)
                .padding()
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker { result in
                switch result {
                case .success(let url):
                    loadJsonFile(from: url)
                case .failure(let error):
                    errorMessage = "파일을 불러오는 데 실패했습니다: \(error.localizedDescription)"
                }
            }
        }
        //.navigationTitle("Second View")
    }
    
    func writeWithDelay(index: Int) async {
        isSending = true
        await viewModel.write(str: "entry")
        
        for i in 0..<loadedData[index].ledList.count {
            await viewModel.write(str: "start")
            try? await Task.sleep(nanoseconds: 5_000_000)
            
            let du = "d:\(loadedData[index].duration[i])"
            await viewModel.write(str: du)
            try? await Task.sleep(nanoseconds: 5_000_000)
            
            for j in 0..<12 {
                let formattedR = String(format: "%02x", loadedData[index].ledList[i][j][0])
                let formattedG = String(format: "%02x", loadedData[index].ledList[i][j][1])
                let formattedB = String(format: "%02x", loadedData[index].ledList[i][j][2])
                let value = "v:\(j):\(formattedG)\(formattedR)\(formattedB)"
                await viewModel.write(str: value)
                
                // 1밀리초 대기
                try? await Task.sleep(nanoseconds: 5_000_000)
            }
            
            await viewModel.write(str: "end")
            try? await Task.sleep(nanoseconds: 5_000_000) // 각 "end" 후에도 1밀리초 대기
        }
        
        await viewModel.write(str: "eof")
        try? await Task.sleep(nanoseconds: 5_000_000) // 마지막 "eof" 후에도 1밀리초 대기
        isSending = false
    }

    
    func loadJsonFile(from url: URL) {
        do {
            print("trying to load json file... url:\(url.absoluteString)")
            
            // Start accessing the scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "파일에 대한 접근 권한을 얻지 못했습니다."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() } // 반드시 접근 종료
            
            let data = try Data(contentsOf: url)
            print("successfully got Data")
            let decoder = JSONDecoder()
            let decodedData = try decoder.decode([LEDSequence].self, from: data)
            print("successfully got decodedData")
            loadedData = decodedData
            print(loadedData.count)
            for i in loadedData{
                print(i.name)
            }
            errorMessage = nil
            print("ErrorMessage : ",errorMessage)
            saveData()
        } catch {
            errorMessage = "JSON 파일을 읽거나 디코딩하는 데 실패했습니다: \(error.localizedDescription)"
            print("ErrorMessage : ",errorMessage)
        }
    }
    
    func loadData() {
        if let savedData = UserDefaults.standard.data(forKey: "loadedData") {
            do {
                let decodedData = try JSONDecoder().decode([LEDSequence].self, from: savedData)
                loadedData = decodedData
            } catch {
                print("Failed to load data: \(error.localizedDescription)")
            }
        } else {
            loadedData = []
        }
    }

    func saveData() {
        do {
            let encodedData = try JSONEncoder().encode(loadedData)
            UserDefaults.standard.set(encodedData, forKey: "loadedData")
            print("Data saved successfully!")
        } catch {
            print("Failed to save data: \(error.localizedDescription)")
        }
    }
}

struct LEDSequence: Codable {
    let duration: [Int]
    let ledList: [[[Int]]]
    let name: String
}


struct BLEDevice: Identifiable {
    let id = UUID()
    let name: String
    let address : String
    let peripheral: CBPeripheral
}



struct DocumentPicker: UIViewControllerRepresentable {
    var onCompletion: (Result<URL, Error>) -> Void
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(onCompletion: onCompletion)
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.json])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onCompletion: (Result<URL, Error>) -> Void
        
        init(onCompletion: @escaping (Result<URL, Error>) -> Void) {
            self.onCompletion = onCompletion
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onCompletion(.failure(NSError(domain: "NoFileSelected", code: -1, userInfo: nil)))
                return
            }
            onCompletion(.success(url))
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCompletion(.failure(NSError(domain: "UserCancelled", code: -1, userInfo: nil)))
        }
    }
}



// CircularButtonView: 12개의 버튼을 원형으로 배치하는 뷰
struct CircularButtonView: View {
    let colors: [[Int]] // RGB 값 배열
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 3
            
            ZStack {
                ForEach(0..<colors.count, id: \.self) { index in
                    if colors[index].count == 3 {
                        let angle = Angle(degrees: Double(index) / Double(colors.count) * 360.0)
                        let xOffset = radius * cos(CGFloat(angle.radians))
                        let yOffset = radius * sin(CGFloat(angle.radians))
                        
                        Button(action: {
                            print("Button \(index) pressed")
                        }) {
                            Circle()
                                .fill(Color(
                                    red: Double(colors[index][0]) / 100.0,
                                    green: Double(colors[index][1]) / 100.0,
                                    blue: Double(colors[index][2]) / 100.0
                                ))
                                .frame(width: 10, height: 10)
                        }
                        .position(x: center.x + xOffset, y: center.y + yOffset)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 100) // 적당한 높이를 설정
    }
}

struct LEDRowView: View {
    let ledList: [[Int]]
    let name: String
    let onSettingsTap: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                ForEach(0..<ledList.count, id: \.self) { index in
                    Circle()
                        .fill(Color(
                            red: Double(ledList[index][0]) / 100.0,
                            green: Double(ledList[index][1]) / 100.0,
                            blue: Double(ledList[index][2]) / 100.0
                        ))
                        .frame(width: 15, height: 15)
                        .offset(x: cos(angle(for: index)) * 30, y: sin(angle(for: index)) * 30)
                }
            }
            .frame(width: 60, height: 60)
            
            Text(name)
            
            Spacer()
            .frame(maxWidth: .infinity)

            Button(action:onSettingsTap) {
                Text("설정")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
    }

    private func angle(for index: Int) -> CGFloat {
        let angleIncrement = 2 * .pi / CGFloat(ledList.count)
        return angleIncrement * CGFloat(index)
    }
}






















































struct SecondView: View {
//    @State private var redValue: Double = 0
//    @State private var greenValue: Double = 0
//    @State private var blueValue: Double = 0
    @State private var duration: String = "50"
    @State private var ledColors: [[Int]] = Array(repeating:[50, 50, 50], count:12)
    @State private var selectedLED: Int = 0
    @State private var LEDList: [[[Int]]] = []
    
    var body: some View {
        VStack {
            // 원형 버튼 배열
            ZStack {
                ForEach(0..<12) { index in
                    CircleButton(index: index, selectedLED: $selectedLED, ledColors: $ledColors)
                }
            }
            .frame(width: 135, height: 135)
            .padding()
            
            // RGB 슬라이더 섹션
            VStack {
                RGBSlider(color: "R", value: $ledColors[selectedLED][0], onValueChange: updateColor)
                RGBSlider(color: "G", value: $ledColors[selectedLED][1], onValueChange: updateColor)
                RGBSlider(color: "B", value: $ledColors[selectedLED][2], onValueChange: updateColor)
            }
            
            // 지속시간
            HStack {
                Text("지속시간 (밀리초)")
                TextField("50", text: $duration)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(width: 80)
            }
            
            // 추가 버튼
            Button("추가하기") {
                LEDList.append(ledColors)
            }
            .buttonStyle(.bordered)
            
            // 가로 ScrollView
            ScrollView(.horizontal) {
                HStack {
                }
            }
            .frame(height: 100)
            
            // 완료하기 버튼
            Button("완료하기") {
                // 동작 생략
            }
            .buttonStyle(.borderedProminent)
        }
    }
    private func updateColor() {
        let selected = selectedLED
        let r = ledColors[selected][0]
        let g = ledColors[selected][1]
        let b = ledColors[selected][2]
        let hexColor = String(format: "#%02X%02X%02X", r, g, b)
        print("LED \(selected + 1) 색상: \(hexColor)")
    }
    
}

// RGB 슬라이더 섹션 뷰
struct RGBSlider: View {
    let color: String
    @Binding var value: Int
    let onValueChange: () -> Void
    
    var body: some View {
        HStack {
            Text(color)
                .frame(width: 30)
            Slider(value: Binding(
                get: { Double(value) },
                set: { newValue in
                    value = Int(newValue)
                    onValueChange()
                }
            ), in: 0...100)
            TextField("\(value)", value: Binding(
                get: { Double(value) },
                set: { newValue in
                    value = Int(newValue)
                    onValueChange()
                }
            ), formatter: NumberFormatter())
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .frame(width: 80)
        }
        .padding()
    }
}

// 원형 버튼 구현
struct CircleButton: View {
    let index: Int
    @Binding var selectedLED: Int
    @Binding var ledColors: [[Int]]
    
    var body: some View {
        let isSelected = selectedLED == index
        let angle = Angle(degrees: Double(index) * 30)
        let backgroundColor = Color(
            red: Double(ledColors[index][0]) / 100,
            green: Double(ledColors[index][1]) / 100,
            blue: Double(ledColors[index][2]) / 100
        )
        
        return Button(action: {
            selectedLED = index
        }) {
            Text("\(index + 1)")
                .frame(width: 30, height: 30)
                .background(Circle().fill(isSelected ? backgroundColor.opacity(0.7) : backgroundColor))
                .overlay(Circle().stroke(isSelected ? Color.white : Color.clear, lineWidth: 2))
                .foregroundColor(.white)
        }
        .offset(x: 75 * cos(angle.radians), y: 75 * sin(angle.radians))
    }
}

struct CirclePreview: View {
    let index: Int
    @Binding var ledColors: [Int]
    
    var body: some View {
        let angle = Angle(degrees: Double(index) * 30)
        let backgroundColor = Color(
            red: Double(ledColors[0]) / 100,
            green: Double(ledColors[1]) / 100,
            blue: Double(ledColors[2]) / 100
        )
        
        return Button(action: {
        }) {
            Text("\(index + 1)")
                .frame(width: 10, height: 10)
                .background(Circle().fill(backgroundColor))
                .foregroundColor(.white)
        }
        .offset(x: 25 * cos(angle.radians), y: 25 * sin(angle.radians))
    }
}
