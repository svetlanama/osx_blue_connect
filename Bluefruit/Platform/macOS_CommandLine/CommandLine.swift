//
//  CommandLine.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 17/05/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation
import CoreBluetooth

@available(OSX 10.13, *)
class CommandLine: NSObject {
    // Scanning
    fileprivate var discoveredPeripheralsIdentifiers = [UUID]()
    fileprivate var scanResultsShowIndex = false

    // DFU
    fileprivate var dfuSemaphore = DispatchSemaphore(value: 0)
    fileprivate let firmwareUpdater = FirmwareUpdater()
    fileprivate let dfuUpdateProcess = DfuUpdateProcess()
    fileprivate var dfuPeripheral: BlePeripheral?
    fileprivate var macPeripheral: BlePeripheral?
    fileprivate var hexUrl: URL?
    fileprivate var iniUrl: URL?
    fileprivate var zipUrl: URL?
    fileprivate var releases: [AnyHashable: Any]?
    fileprivate var dFUIgnorePrechecks = false
    
    // MARK: - Bluetooth Status
    func checkBluetoothErrors() -> String? {
        var errorMessage: String?
        let bleManager = BleManager.sharedInstance
        if let state = bleManager.centralManager?.state {
            switch state {
            case .unsupported:
                errorMessage = "This computer doesn't support Bluetooth Low Energy"
            case .unauthorized:
                errorMessage = "The application is not authorized to use the Bluetooth Low Energy"
            case .poweredOff:
                errorMessage = "Bluetooth is currently powered off"
            default:
                errorMessage = nil
            }
        }

        return errorMessage
    }

    // MARK: - Help
    func showHelp() {
        showVersion()
        print("Usage:")
        print( "\t\(appName()) <command> [options...]")
        print("")
        print("Commands:")
        print("\tScan peripherals:   scan")
        print("\tAutomatic update:   update [--enable-beta] [--uuid <uuid>]")
        print("\tCustom firmware:    dfu --hex <filename> [--init <filename>] [--uuid <uuid>]")
        print("\tCustom firmware:    dfu --zip <filename> [--uuid <uuid>]")
        print("\tShow this screen:   --help")
        print("\tShow version:       --version")
        print("")
        print("Options:")
        print("\t--uuid <uuid>      If present the peripheral with that uuid is used. If not present a list of peripherals is displayed")
        print("\t--enable-beta      If not present only stable versions are used")
        print("\t--ignore-warnings  Ignore any warnings and continue the update process")

        print("")
        print("Short syntax:")
        print("\t-u = --uuid, -b = --enable-beta, -h = --hex, -i = --init, -v = --version, -? = --help")
        /*
        print("\t--uuid -u")
        print("\t--enable-beta -b")
        print("\t--hex -h")
        print("\t--init -i")
        print("\t--help -h")
        print("\t--version -v")
        */

        print("")

        /*
         print("\tscan                                                       Scan peripherals")
         print("\tupdate [--uuid <uuid>] [--enable-beta]                     Automatic update")
         print("\tdfu -hex <filename> [-init <filename>] [--uuid <uuid>]     Custom firmware update")
         print("\t-h --help                                                  Show this screen")
         print("\t-v --version                                               Show version")
      
         */
    }

    fileprivate func appName() -> String {
        let name = (Swift.CommandLine.arguments[0] as NSString).lastPathComponent
        return name
    }

    func showVersion() {
        let appInfo = Bundle.main.infoDictionary!
        let releaseVersionNumber = appInfo["CFBundleShortVersionString"] as! String
        let appInfoString = "\(appName()) v\(releaseVersionNumber)"
        //let buildVersionNumber =  appInfo["CFBundleVersion"] as! String
        //let appInfoString = "\(appname()) v\(releaseVersionNumber)b\(buildVersionNumber)"
        print(appInfoString)
    }

    // MARK: - Scan 
    func startScanning() {
        startScanningAndShowIndex(false)
    }

    private weak var didDiscoverPeripheralObserver: NSObjectProtocol?

    private func startScanningAndShowIndex(_ scanResultsShowIndex: Bool) {
        self.scanResultsShowIndex = scanResultsShowIndex

        // Subscribe to Ble Notifications
        didDiscoverPeripheralObserver = NotificationCenter.default.addObserver(forName: .didDiscoverPeripheral, object: nil, queue: .main, using: didDiscoverPeripheral)

        BleManager.sharedInstance.startScan()
    }

    private func stopScanning() {
        if let didDiscoverPeripheralObserver = didDiscoverPeripheralObserver {NotificationCenter.default.removeObserver(didDiscoverPeripheralObserver)}

        BleManager.sharedInstance.stopScan()
//        BleManager.sharedInstance.reset()
    }

    private func didDiscoverPeripheral(notification: Notification) {

        guard let uuid = notification.userInfo?[BleManager.NotificationUserInfoKey.uuid.rawValue] as? UUID else { return }

        if let peripheral = BleManager.sharedInstance.peripheral(with: uuid) {

            if !discoveredPeripheralsIdentifiers.contains(uuid) {
                discoveredPeripheralsIdentifiers.append(uuid)

                let name = peripheral.name != nil ? peripheral.name! : "<Unknown>"
                if scanResultsShowIndex {
                    if let index  = discoveredPeripheralsIdentifiers.index(of: uuid) {
                        print("\(index) -> \(uuid) - \(name)")
                    }
                } else {
                    print("\(uuid): \(name)")
                }
            }
        }
    }

    // MARK: - Ask user
    func askUserForPeripheral() -> UUID? {
        print("Scanning... Select a peripheral: ")
        var peripheralIdentifier: UUID? = nil

        startScanningAndShowIndex(true)
        let peripheralIndexString = readLine(strippingNewline: true)
        //DLog("selected: \(peripheralIndexString)")
        if let peripheralIndexString = peripheralIndexString, let peripheralIndex = Int(peripheralIndexString), peripheralIndex>=0 && peripheralIndex < discoveredPeripheralsIdentifiers.count {
            peripheralIdentifier = discoveredPeripheralsIdentifiers[peripheralIndex]

            //print("Selected UUID: \(peripheralUuid!)")
            stopScanning()

            print("")
            //            print("Peripheral selected")

        }

        return peripheralIdentifier
    }

    // MARK: - DFU
    private weak var didConnectToPeripheralObserver: NSObjectProtocol?

    func dfuPeripheral(uuid peripheralUUID: UUID, hexUrl: URL? = nil, iniUrl: URL? = nil, releases: [AnyHashable: Any]? = nil, ignorePreChecks: Bool) {

        self.hexUrl = hexUrl
        self.iniUrl = iniUrl
        self.dFUIgnorePrechecks = ignorePreChecks

        startDfuPeripheral(uuid: peripheralUUID, releases: releases)
    }
    
    func dfuPeripheral(uuid peripheralUUID: UUID, zipUrl: URL, releases: [AnyHashable: Any]? = nil, ignorePreChecks: Bool) {
        self.zipUrl = zipUrl
        self.dFUIgnorePrechecks = ignorePreChecks
        
        startDfuPeripheral(uuid: peripheralUUID, releases: releases)
    }
    
    private func startDfuPeripheral(uuid peripheralUUID: UUID, releases: [AnyHashable: Any]? = nil) {
        guard let centralManager = BleManager.sharedInstance.centralManager else { DLog("centralManager is nil"); return }
        if let peripheral = centralManager.retrievePeripherals(withIdentifiers: [peripheralUUID]).first {
            dfuPeripheral = BlePeripheral(peripheral: peripheral, advertisementData: nil, rssi: nil)
            self.releases = releases
            print("Connecting...")
            
            // Connect to peripheral and discover characteristics. This should not be needed but the Dfu library will fail if a previous characteristics discovery has not been done
            
            // Subscribe to didConnect notifications
            didConnectToPeripheralObserver = NotificationCenter.default.addObserver(forName: .didConnectToPeripheral, object: nil, queue: .main, using: didConnectToPeripheral)
            
            // Connect to peripheral and wait
            BleManager.sharedInstance.connect(to: dfuPeripheral!)
            let _ = dfuSemaphore.wait(timeout: .distantFuture)
            
        } else {
            print("Error. No peripheral found with UUID: \(peripheralUUID.uuidString)")
            dfuPeripheral = nil
        }
    }
    
    func macPeripheral(uuid peripheralUUID: UUID, hexUrl: URL? = nil, iniUrl: URL? = nil, releases: [AnyHashable: Any]? = nil, ignorePreChecks: Bool) {
        
        self.hexUrl = hexUrl
        self.iniUrl = iniUrl
        self.dFUIgnorePrechecks = ignorePreChecks
        
        startMacPeripheral(uuid: peripheralUUID, releases: releases)
    }
  
    func macPeripheral(uuid peripheralUUID: UUID, zipUrl: URL, releases: [AnyHashable: Any]? = nil, ignorePreChecks: Bool) {
      self.zipUrl = zipUrl
      self.dFUIgnorePrechecks = ignorePreChecks
    
      startMacPeripheral(uuid: peripheralUUID, releases: releases)
    }
  
  private func startMacPeripheral(uuid peripheralUUID: UUID, releases: [AnyHashable: Any]? = nil) {
    //TODO: Method1
    guard let centralManager = BleManager.sharedInstance.centralManager else { DLog("centralManager is nil"); return }
    if let peripheral = centralManager.retrievePeripherals(withIdentifiers: [peripheralUUID]).first {
      if peripheral.name != "FBe" { //URGENT only  FBe
        return
      }
      dfuPeripheral = BlePeripheral(peripheral: peripheral, advertisementData: nil, rssi: nil)
      self.releases = releases
      print("Connecting...")

      print("dfuPeripheral...", dfuPeripheral?.name)
        
      // Subscribe to didConnect notifications
      didConnectToPeripheralObserver = NotificationCenter.default.addObserver(forName: .didConnectToPeripheral, object: nil, queue: .main, using: didConnectToPeripheralMac)
      print("advertisements: ", dfuPeripheral?.advertisement.advertisementData)
      // Connect to peripheral and wait
      BleManager.sharedInstance.connect(to: dfuPeripheral!)
      let _ = dfuSemaphore.wait(timeout: .distantFuture)

    } else {
      print("Error. No peripheral found with UUID: \(peripheralUUID.uuidString)")
      dfuPeripheral = nil
    }
    
    
    ////////////////////
    //TODO: Method2
    /*guard let centralManager = BleManager.sharedInstance.centralManager else { DLog("centralManager is nil"); return }
    
    //var blePeripheral: BlePeripheral?
    if let peripheral = BleManager.sharedInstance.peripherals().filter({ $0.identifier == peripheralUUID && $0.name == "FBe"}).first {
      //print("advertisements: ", peripheral.advertisement.advertisementData)
      //var advertisement = peripheral.advertisement.advertisementData
      //Advertisement(advertisementData: advertisementData)

      for (key, value) in peripheral.advertisement.advertisementData {
         print("key: ", key)
         print("value: ", value)
      }
      
      macPeripheral = peripheral
      didConnectToPeripheralObserver = NotificationCenter.default.addObserver(forName: .didConnectToPeripheral, object: nil, queue: .main, using: didConnectToPeripheralMac)
      
      BleManager.sharedInstance.connect(to: peripheral)
      
      //advertisement["kCBAdvDataManufacturerData"] = "ffff0000 01e2ffff 00000100 00000000 0000"
    }
    */
  }

  private func didConnectToPeripheralMac(notification: Notification) {
    //TODO: CONNECTED FOR Method1 & Method2
 
    // Unsubscribe from didConnect notifications
    if let didConnectToPeripheralObserver = didConnectToPeripheralObserver { NotificationCenter.default.removeObserver(didConnectToPeripheralObserver) }
    
    // Check connected
    // TODO: restore
    //    guard let _macPeripheral = macPeripheral else {
    //      DLog("dfuDidConnectToPeripheral MAC dfuPeripheral is nil")
    //      //dfuFinished() //TODO:
    //      return
    //    }

     //TODO: try to get advertisment data like in Method2
     //TODO: see Method2
     // print("advertisements: ", peripheral.advertisement.advertisementData)
     // Read services / characteristics
    
     //dfuPeripheral?.advertisement.advertisementData["kCBAdvDataManufacturerData"] = "ffff0000 01e2ffff 00000100 00000000 0000"
     print("MAAAC___ didConnectToPeripheralMac dfuPeripheral Reading services and characteristics...", dfuPeripheral?.advertisement.advertisementData)
    
//    var data: [UInt16] =  [UInt16]()
//    data[0] = 0xFF
//    data[1] = 0x00
//    data[2] = 0xFF
//    let data = Data(bytes: [0x71, 0x3d, 0x0a, 0xd7, 0xa3, 0x10, 0x45, 0x40])
//    let str = String(bytes: data, encoding: String.Encoding.utf8)
//    print("new data___: ", str)
    
    //_macPeripheral.write(data: data, for: CBAdvertisementDataManufacturerDataKey, type: CBCharacteristicWriteType.withResponse)
    //firmwareUpdater.
    //https://stackoverflow.com/a/24199063/2999739
    
    //..macPeripheral!.advertisement.advertisementData["kCBAdvDataManufacturerData"] = "ffff0000 01e2ffff 00000100 00000000 0000"
    //guard let centralManager = BleManager.sharedInstance.centralManager else { DLog("centralManager is nil"); return }
    
    /*var advertisement = _macPeripheral.advertisement.advertisementData
    advertisement[CBAdvertisementDataManufacturerDataKey] = "ffff0000 01e2ffff 00000100 00000000 0000"
    macPeripheral?.advertisement.advertisementData[CBAdvertisementDataManufacturerDataKey] = "ffff0000 01e2ffff 00000100 00000000 0000"
    let peripheralUUID = _macPeripheral.identifier // "788C222B-EF14-447A-B1C8-FD73354CD753"
    if let _peripheral = centralManager.retrievePeripherals(withIdentifiers: [peripheralUUID]).first {

      let p = BlePeripheral(peripheral: _peripheral, advertisementData: advertisement, rssi: nil)
      print("p: ", p.advertisement.advertisementData)
      macPeripheral = p
      //macPeripheral?.peripheral(_peripheral, didWriteValueFor: CBAdvertisementDataManufacturerDataKey, error: nil)
    }*/
    
    // FirmwareUpdater.
    
    //    macPeripheral?.write(data: <#T##Data#>, for: CBAdvertisementDataManufacturerDataKey, type: CBCharacteristicWriteType, completion: { error in
    //        print("error...", error)
    //    })
    
    // Read services / characteristics
    //firmwareUpdater.checkUpdatesForPeripheral(macPeripheral!, delegate: self, shouldDiscoverServices: true, shouldRecommendBetaReleases: true, versionToIgnore: nil)
    
    //print("macPeripheral...",  )
    //print("Reading services and characteristics...", macPeripheral!.advertisement.advertisementData)
 
    //BleManager.sharedInstance.disconnect(from: macPeripheral!)
    //firmwareUpdater.checkUpdatesForPeripheral(dfuPeripheral, delegate: self, shouldDiscoverServices: true, shouldRecommendBetaReleases: true, versionToIgnore: nil)
  }
  
    private func didConnectToPeripheral(notification: Notification) {
        //TODO: FOR Method2
        //TODO: Try to update data
        // Unsubscribe from didConnect notifications
        if let didConnectToPeripheralObserver = didConnectToPeripheralObserver { NotificationCenter.default.removeObserver(didConnectToPeripheralObserver) }

        // Check connected
        guard let dfuPeripheral = dfuPeripheral  else {
            DLog("dfuDidConnectToPeripheral dfuPeripheral is nil")
            dfuFinished()
            return
        }

        //TODO: try to get advertisment data like in Method2
        //TODO: see Method2
        // print("advertisements: ", peripheral.advertisement.advertisementData)
        // Read services / characteristics
        print("Reading services and characteristics...")
        firmwareUpdater.checkUpdatesForPeripheral(dfuPeripheral, delegate: self, shouldDiscoverServices: true, shouldRecommendBetaReleases: true, versionToIgnore: nil)
    }

    fileprivate func dfuFinished() {
        dfuSemaphore.signal()
    }

    func downloadFirmwareUpdatesDatabase(url dataUrl: URL, showBetaVersions: Bool, completionHandler: (([AnyHashable: Any]?) -> Void)?) {

        FirmwareUpdater.refreshSoftwareUpdatesDatabase(url: dataUrl) { [unowned self] success in
            let boardsInfo = self.firmwareUpdater.releases(showBetaVersions: showBetaVersions)
            completionHandler?(boardsInfo)
        }
        /*
        DataDownloader.downloadDataFromURL(dataUrl) { (data) in
            let boardsInfo = ReleasesParser.parse(data, showBetaVersions: showBetaVersions)
            completionHandler?(boardsInfo)
        }
 */
    }
}

// MARK: - DfuUpdateProcessDelegate
@available(OSX 10.13, *)
extension CommandLine: DfuUpdateProcessDelegate {
    func onUpdateProcessSuccess() {
        BleManager.sharedInstance.restoreCentralManager()

        print("")
        print("Update completed successfully")
        dfuFinished()
    }

    func onUpdateProcessError(errorMessage: String, infoMessage: String?) {
        BleManager.sharedInstance.restoreCentralManager()

        print(errorMessage)
        dfuFinished()
    }

    func onUpdateProgressText(_ message: String) {
        print("\t"+message)
    }

    func onUpdateProgressValue(_ progress: Double) {
        print(".", terminator: "")
        fflush(__stdoutp)
    }
}

// MARK: - FirmwareUpdaterDelegate
@available(OSX 10.13, *)
extension CommandLine: FirmwareUpdaterDelegate {

    func onFirmwareUpdateAvailable(isUpdateAvailable: Bool, latestRelease: FirmwareInfo?, deviceInfo: DeviceInformationService?) {

        // Info received
        DLog("onFirmwareUpdatesAvailable: \(isUpdateAvailable)")
        
        if let deviceInfo = deviceInfo {
            print("Peripheral info:")
            print("\tManufacturer: \(deviceInfo.manufacturer ?? "{unknown}")")
            print("\tModel:        \(deviceInfo.modelNumber ?? "{unknown}")")
            print("\tSoftware:     \(deviceInfo.softwareRevision ?? "{unknown}")")
            print("\tFirmware:     \(deviceInfo.firmwareRevision ?? "{unknown}")")
            print("\tBootlader:    \(deviceInfo.bootloaderVersion ?? "{unknown}")")
        }
        
        if !dFUIgnorePrechecks {
            guard deviceInfo != nil else {
                print("DIS characteristic not found")
                dfuFinished()
                return
            }
            
            guard deviceInfo?.hasDefaultBootloaderVersion == false else {
                print("The legacy bootloader on this device is not compatible with this application")
                dfuFinished()
                return
            }
        }

        // Determine final hex and init (depending if is a custom firmware selected by the user, or an automatic update comparing the peripheral version with the update server xml)
        var hexUrl: URL?
        var iniUrl: URL?
        var zipUrl: URL?

        if self.releases != nil {  // Use automatic-update

            guard let latestRelease = latestRelease else {
                print("No updates available")
                dfuFinished()
                return
            }

            guard isUpdateAvailable else {
                print("Latest available version is: \(latestRelease.version)")
                print("No updates available")
                dfuFinished()
                return
            }
            
            print("Auto-update to version: \(latestRelease.version)")
            hexUrl = latestRelease.hexFileUrl
            iniUrl = latestRelease.iniFileUrl
            zipUrl = latestRelease.zipFileUrl
            
        } else {      // is a custom update selected by the user
            hexUrl = self.hexUrl
            iniUrl = self.iniUrl
            zipUrl = self.zipUrl
        }

        // Check update parameters
        guard let dfuPeripheral = dfuPeripheral  else {
            DLog("dfuDidConnectToPeripheral dfuPeripheral is nil")
            dfuFinished()
            return
        }

        guard hexUrl != nil || zipUrl != nil else {
            DLog("dfuDidConnectToPeripheral no update file defined")
            dfuFinished()
            return
        }

        // Start update
        print("Start Update")
        dfuUpdateProcess.delegate = self
        
        if let zipUrl = zipUrl {
            dfuUpdateProcess.startUpdateForPeripheral(peripheral: dfuPeripheral.peripheral, zipUrl: zipUrl)
        }
        else {
            dfuUpdateProcess.startUpdateForPeripheral(peripheral: dfuPeripheral.peripheral, hexUrl: hexUrl!, iniUrl: iniUrl)
        }
    }

    func onDfuServiceNotFound() {
        print("DFU service not found")
             dfuFinished()
    }
}
