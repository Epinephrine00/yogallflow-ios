//
//  FreflowSessionManager.swift
//  yogallflow
//
//  Created by 이두현 on 12/4/24.
//

import Foundation
import AccessorySetupKit
import CoreBluetooth
import SwiftUI


class FlowSessionManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager: CBCentralManager!
    var onDeviceDiscovered: ((CBPeripheral) -> Void)?
    var discoveredPeripheral: CBPeripheral?
    var writableCharacteristic: CBCharacteristic?
    let targetDeviceName = "mpy-uart"
    
    
    override init() {
        super.init()
        // 중앙 관리자 초기화
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - CBCentralManagerDelegate Methods

    // Bluetooth 상태 업데이트
//    func centralManagerDidUpdateState(_ central: CBCentralManager) {
//        switch central.state {
//        case .poweredOn:
//            print("Bluetooth is powered on. Starting scan...")
//            // 주변 BLE 장치 스캔 시작
//            centralManager.scanForPeripherals(withServices: nil, options: nil)
//        case .poweredOff:
//            print("Bluetooth is powered off.")
//        case .unsupported:
//            print("Bluetooth is not supported on this device.")
//        default:
//            print("Bluetooth state is: \(central.state.rawValue)")
//        }
//    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("Bluetooth is powered on.")
        } else {
            print("Bluetooth state: \(central.state.rawValue)")
        }
    }
    func startScan() {
        guard centralManager.state == .poweredOn else {
            print("Bluetooth is not powered on.")
            return
        }
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }
    func stopScan() {
        centralManager.stopScan()
    }
    
    
    // 주변 장치 발견 시 호출
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // 장치 이름 확인
        if let peripheralName = peripheral.name {
            print("Discovered device: \(peripheralName)")
            
            // 이름이 목표 장치와 일치하는지 확인
            if peripheralName == targetDeviceName {
                print("Found target device: \(peripheralName)")
                
                // 스캔 중지 및 연결
//                discoveredPeripheral = peripheral
//                centralManager.stopScan()
//                print("Connecting to \(peripheralName)...")
//                centralManager.connect(peripheral, options: nil)
                onDeviceDiscovered?(peripheral)
            }
        } else {
            print("Discovered device with no name.")
        }
    }
    
    // 주변 장치 연결 성공 시 호출
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown Device")")
        discoveredPeripheral = peripheral
        // 주변 장치와 상호작용 시작
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }
    
    // 주변 장치 연결 실패 시 호출
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to \(peripheral.name ?? "Unknown Device"): \(error?.localizedDescription ?? "Unknown error")")
        cleanup()
    }
    
    // MARK: - CBPeripheralDelegate Methods
    
    // 서비스 발견 시 호출
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            cleanup()
            return
        }
        
        guard let services = peripheral.services else { return }
        for service in services {
            print("Discovered service: \(service.uuid)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    // 특성 발견 시 호출
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
            if let error = error {
                print("Error discovering characteristics: \(error.localizedDescription)")
                cleanup()
                return
            }
            
            guard let characteristics = service.characteristics else { return }
            for characteristic in characteristics {
                print("Discovered characteristic: \(characteristic.uuid)")
                
                // 특정 UUID를 가진 특성을 데이터 쓰기에 사용
                if characteristic.properties.contains(.write) {
                    writableCharacteristic = characteristic
                    print("Found writable characteristic: \(characteristic.uuid)")
                    
                    writeData(to: characteristic, peripheral: peripheral, d:"Hello")
                }
            }
        }
    
    // MARK: - 데이터 쓰기

        func writeData(to characteristic: CBCharacteristic, peripheral: CBPeripheral, d:String) {
           let dataToWrite = d.data(using: .utf8)! // 예제 데이터
           peripheral.writeValue(dataToWrite, for: characteristic, type: .withoutResponse)
           print("Data written: \(String(data: dataToWrite, encoding: .utf8) ?? "Invalid Data")")
       }
       
       // 쓰기 응답 처리
       func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
           if let error = error {
               print("Error writing value: \(error.localizedDescription)")
           } else {
               //print("Successfully wrote value to \(characteristic.uuid)")
           }
       }
       
       // MARK: - Cleanup

       private func cleanup() {
           if let peripheral = discoveredPeripheral {
               centralManager.cancelPeripheralConnection(peripheral)
           }
           discoveredPeripheral = nil
       }
}
