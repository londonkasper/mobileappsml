//
//  TestingViewController.swift
//  HTTPSwiftExample
//
//  Created by Jeremy Waibel on 11/20/22.
//  Copyright © 2022 Eric Larson. All rights reserved.
//

import UIKit
import CoreMotion

class TestingViewController: UIViewController, URLSessionDelegate {
    let SERVER_URL = "http://10.8.144.86:8000" // change this for your server name!!!

    override func viewDidLoad() {
        super.viewDidLoad()
        startMotionUpdates()
    }
    
    lazy var session: URLSession = {
        let sessionConfig = URLSessionConfiguration.ephemeral
        
        sessionConfig.timeoutIntervalForRequest = 5.0
        sessionConfig.timeoutIntervalForResource = 8.0
        sessionConfig.httpMaximumConnectionsPerHost = 1
        
        return URLSession(configuration: sessionConfig,
            delegate: self,
            delegateQueue:self.operationQueue)
    }()
    
    let operationQueue = OperationQueue()
    let motionOperationQueue = OperationQueue()
    let calibrationOperationQueue = OperationQueue()
    
    var ringBuffer = RingBuffer()
    let motion = CMMotionManager()
    
    var isCalibrating = false
    var isWaitingForMotionData = false
        
    //Minimum magnitude to record motion data
    var magValue = 1.0

    //Hardcode as 0 for now, maybe in the final make multiple models for easy/medium/hard modes
    let dsid = 0
    
    @IBOutlet weak var PredictionLabel: UILabel!
    
    @IBAction func MotionButton(_ sender: Any) {
        self.startCalibration()
    }
    // MARK: Class Properties with Observers
    
    enum CalibrationType {
        case none
        case boop_it
        case twist_it
        case pull_it
    }
    
    
    //Todo some animation or something, probably can do with button clicks or smthing
    var calibrationType:CalibrationType = .none {
        didSet{
            switch calibrationType {
            case .boop_it:
                self.isCalibrating = true
                setDelayedWaitingToTrue(1.0)
                break
            case .pull_it:
                self.isCalibrating = true
                setDelayedWaitingToTrue(1.0)
                break
            case .twist_it:
                self.isCalibrating = true
                setDelayedWaitingToTrue(1.0)
                break
            case .none:
                self.isCalibrating = false
                setDelayedWaitingToTrue(1.0)
                break
            }
        }
    }
    
    func startMotionUpdates(){
        // some internal inconsistency here: we need to ask the device manager for device
        
        if self.motion.isDeviceMotionAvailable{
            self.motion.deviceMotionUpdateInterval = 1.0/200
            self.motion.startDeviceMotionUpdates(to: motionOperationQueue, withHandler: self.handleMotion )
        }
    }
    func handleMotion(_ motionData:CMDeviceMotion?, error:Error?){
        if let accel = motionData?.userAcceleration {
            self.ringBuffer.addNewData(xData: accel.x, yData: accel.y, zData: accel.z)
            let mag = fabs(accel.x)+fabs(accel.y)+fabs(accel.z)
            
            //print magnitude for testing
            if mag > self.magValue {
                // buffer up a bit more data and then notify of occurrence
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: {
                    self.calibrationOperationQueue.addOperation {
                        // something large enough happened to warrant
                        self.largeMotionEventOccurred()
                    }
                })
            }
        }
    }
    
    //MARK: Calibration procedure
    func largeMotionEventOccurred(){
        if(self.isCalibrating && self.isWaitingForMotionData){
            self.isWaitingForMotionData = false
            self.isCalibrating = false
            //Send Prediction
                getPrediction(self.ringBuffer.getDataAsVector())
            }
    }

        func getPrediction(_ array:[Double]){
            let baseURL = "\(SERVER_URL)/PredictOne"
            let postUrl = URL(string: "\(baseURL)")
    
            // create a custom HTTP POST request
            var request = URLRequest(url: postUrl!)
    
            // data to send in body of post request (send arguments as json)
            let jsonUpload:NSDictionary = ["feature":array, "dsid":self.dsid]
    
    
            let requestBody:Data? = self.convertDictionaryToData(with:jsonUpload)
    
            request.httpMethod = "POST"
            request.httpBody = requestBody
    
            let postTask : URLSessionDataTask = self.session.dataTask(with: request,
                                                                      completionHandler:{
                            (data, response, error) in
                            if(error != nil){
                                if let res = response{
                                    print("Response:\n",res)
                                }
                            }
                            else{ // no error we are aware of
                                let jsonDictionary = self.convertDataToDictionary(with: data)
                                DispatchQueue.main.async{
                                    self.PredictionLabel.text = jsonDictionary["prediction"]! as? String
                                }
                            }
    
            })
    
            postTask.resume() // start the task
        }
    
    //MARK: Calibration
    //MARK: TODO MAKE CONNECTED TO BUTTON
    func startCalibration() {
        DispatchQueue.main.async{
            self.PredictionLabel.text = "Waiting..."
        }
        self.isWaitingForMotionData = false // dont do anything yet
        self.isCalibrating = true
        setDelayedWaitingToTrue(1)
    }
    
    func setDelayedWaitingToTrue(_ time:Double){
        DispatchQueue.main.asyncAfter(deadline: .now() + time, execute: {
            self.isWaitingForMotionData = true
        })
    }
       
    
    //MARK: JSON Conversion Functions
    func convertDictionaryToData(with jsonUpload:NSDictionary) -> Data?{
        do { // try to make JSON and deal with errors using do/catch block
            let requestBody = try JSONSerialization.data(withJSONObject: jsonUpload, options:JSONSerialization.WritingOptions.prettyPrinted)
            return requestBody
        } catch {
            print("json error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func convertDataToDictionary(with data:Data?)->NSDictionary{
        do { // try to parse JSON and deal with errors using do/catch block
            let jsonDictionary: NSDictionary =
                try JSONSerialization.jsonObject(with: data!,
                                              options: JSONSerialization.ReadingOptions.mutableContainers) as! NSDictionary
            
            return jsonDictionary
            
        } catch {
            
            if let strData = String(data:data!, encoding:String.Encoding(rawValue: String.Encoding.utf8.rawValue)){
                            print("printing JSON received as string: "+strData)
            }else{
                print("json error: \(error.localizedDescription)")
            }
            return NSDictionary() // just return empty
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.motion.stopDeviceMotionUpdates()
    }
}
