//
//  ViewController.swift
//  iBeaconWatch
//
//  Created by Yutaka Yoshida on 2015/07/12.
//  Copyright (c) 2015年 Yutaka Yoshida. All rights reserved.
//

import UIKit
import CoreLocation
import AVFoundation

class ViewController: UIViewController, CLLocationManagerDelegate, UIAlertViewDelegate {

    @IBOutlet weak var status: UILabel!
    @IBOutlet weak var accurancy: UILabel!
    @IBOutlet weak var rssi: UILabel!
    @IBOutlet weak var rangeLv: UILabel!
    @IBOutlet weak var uuid: UILabel!
    
    let proximityUUID = NSUUID(UUIDString:"00000000-FC55-1001-B000-001C4D0D4993")
    var region: CLBeaconRegion?
    var manager: CLLocationManager?
    
    var talker: AVSpeechSynthesizer = AVSpeechSynthesizer()
    var voice: AVSpeechSynthesisVoice = AVSpeechSynthesisVoice(language: "ja-JP")
    
    var rangeMessage: String?
    var beforeMsg: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if(!CLLocationManager.isMonitoringAvailableForClass(CLCircularRegion)) {
            self.status.text = "install error."
            var alert:UIAlertView? = UIAlertView(title: "確認",message: "この端末ではiBeaconを利用できません。", delegate: self, cancelButtonTitle: nil, otherButtonTitles: "OK")
            alert?.show()
            exit(0)
        }
        
        self.uuid.text = proximityUUID?.UUIDString
        self.status.text = "..."
        self.accurancy.text = "-"
        self.rssi.text = "-"
        self.rangeLv.text = "-"

        manager = CLLocationManager()
        manager?.delegate = self
            
        region = CLBeaconRegion(proximityUUID:proximityUUID, identifier: "net.kronos-jp.lab.adsh1y0")
        
        // regionには以下のプロパティが存在する今回は全てデフォルトで利用
//            // ディスプレイがOffでもイベントが通知されるように設定(trueにするとディスプレイがOnの時だけ反応).
//            region?.notifyEntryStateOnDisplay = false
//            // 入域通知の設定.
//            region?.notifyOnEntry = true
//            // 退域通知の設定.
//            region?.notifyOnExit = true
            
        // requestWhenInUseAuthorizationがあれば承認が必要 for iOS8
        if (manager?.respondsToSelector("requestWhenInUseAuthorization") != nil) {
            println("---> didChangeAuthorizationStatus")
            manager?.requestAlwaysAuthorization();
            manager?.startMonitoringForRegion(self.region)
        } else {
            manager?.startMonitoringForRegion(self.region)
        }

        var session: AVAudioSession = AVAudioSession.sharedInstance()
        var error: NSError?
        session.setCategory(AVAudioSessionCategoryPlayback,error:&error)
        session.setActive(true, error:nil)
        
    }
    
    func speak(text : String!) {
        var utterance: AVSpeechUtterance = AVSpeechUtterance(string:text)
        utterance.voice = voice
        utterance.rate = 0.1;
        talker.speakUtterance(utterance)
    }
    
    func notify(text : String!) {
        var notification = UILocalNotification()
        notification.fireDate = NSDate(timeIntervalSinceNow: 0)
        notification.timeZone = NSTimeZone.localTimeZone()
        notification.alertBody = text
        notification.alertAction = "Open"
        notification.soundName = UILocalNotificationDefaultSoundName
        UIApplication.sharedApplication().scheduleLocalNotification(notification)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // Delegate:
    func locationManager(manager: CLLocationManager!, didStartMonitoringForRegion region: CLRegion!) {
        println("Start Monitoring Region.")
        self.status.text = "Start Monitoring Region."
        manager?.requestStateForRegion(self.region) // 既にリージョン圏内の場合を想定
    }
    
    // Delegate: 位置情報の許可設定 for iOS8
    func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        println("didChangeAuthorizationStatus")
        // 位置即位の権限がある上でリージョンのモニタリングを開始
        if(status == .NotDetermined) {
            println("NotDetermined")
            notify("位置情報を利用するをONにしてください。")
        } else if(status == .AuthorizedAlways) {
            println("AuthorizedAlways")
//            manager?.startRangingBeaconsInRegion(self.region)
            manager?.startMonitoringForRegion(self.region)
        } else if(status == .AuthorizedWhenInUse) {
            println("AuthorizedWhenInUse")
            // manager?.startRangingBeaconsInRegion(self.region)
            manager?.startMonitoringForRegion(self.region)
        }
    }

    // Delegate: リージョン内に入ったというイベントを受け取る.
    func locationManager(manager: CLLocationManager!, didEnterRegion region: CLRegion!) {
        println("didEnterRegion");
        speak("ビーコン圏内に入りました")
        notify("ビーコン圏内に入りました")
        if(region.isMemberOfClass(CLBeaconRegion) && CLLocationManager.isRangingAvailable()) {
            manager?.startRangingBeaconsInRegion(self.region)
            speak("距離即位を開始します")
        }
    }
    
    // Delegate: リージョンから出たというイベントを受け取る.
    func locationManager(manager: CLLocationManager!, didExitRegion region: CLRegion!) {
        println("didExitRegion")
        speak("ビーコン圏外です")
        notify("ビーコン圏外です")
        if(region.isMemberOfClass(CLBeaconRegion) && CLLocationManager.isRangingAvailable()) {
            manager?.stopRangingBeaconsInRegion(region as! CLBeaconRegion);
        }
    }
    
    // Delegate:
    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        println("didFailWithError \(error)")
    }
    
    // Delegate: 領域内にいるかどうかの判断
    func locationManager(manager: CLLocationManager!, didDetermineState state: CLRegionState, forRegion region: CLRegion!) {

        switch(state) {
        case .Inside:
            println("inside")
            if(region.isMemberOfClass(CLBeaconRegion) && CLLocationManager.isRangingAvailable()) {
                self.manager?.startRangingBeaconsInRegion(self.region)
            }
            break
        case .Outside:
            println("outside")
            break
        case .Unknown:
            println("Unknown")
            println("---> Reload App.")
            break
        default:
            println("default")
            break
        }
        
    }
    
    // Delegate: range開始後、位置秒毎に実行される
    func locationManager(manager: CLLocationManager!, didRangeBeacons beacons: [AnyObject]!, inRegion region: CLBeaconRegion!) {
        
        if(beacons.count > 0) {
            
            var beacon = beacons[0] as! CLBeacon

            var proximity:CLProximity? = beacon.proximity
            var bAccuracy:CLLocationAccuracy? = beacon.accuracy
            
            self.accurancy.text = "\(beacon.accuracy)"
            self.rssi.text = "\(beacon.rssi)"

            if(proximity == CLProximity.Immediate) {
                rangeMessage = "ちかいわー"
            } else if(proximity == CLProximity.Near) {
                rangeMessage = "そこそこちかい"
            } else if(proximity == CLProximity.Far) {
                rangeMessage = "まぁまぁ遠いな"
            } else if(proximity == CLProximity.Unknown) {
                rangeMessage = "わけわからん"
            } else {
                rangeMessage = "？"
            }
            
            println(rangeMessage)
            self.rangeLv.text = rangeMessage
            
            if (beforeMsg != rangeMessage) {
                speak(rangeMessage)
                // notify(rangeMessage)
            }
            
            beforeMsg = rangeMessage
        }
    }

    // Delegate: 領域観測に失敗した場合
    func locationManager(manager: CLLocationManager!, monitoringDidFailForRegion region: CLRegion!, withError error: NSError!) {
        println("Monitoring Error.")
        self.status.text = "Monitoring Error."
    }
    

}

