//
//  TrainingViewController.swift
//  HTTPSwiftExample
//
//  Created by Jeremy Waibel on 11/20/22.
//  Copyright © 2022 Eric Larson. All rights reserved.
//

import UIKit
import CoreMotion


class TrainingViewController: UIViewController, URLSessionDelegate {
    let SERVER_URL = "http://10.9.142.187:8000" // change this for your server name!!!

    //MARK: Basic setup, not at all good / clean / completed.
    //MARK: Maybe make seperate models for handeling server / motion activity - Code reuseability.
    override func viewDidLoad() {
        super.viewDidLoad()
        startMotionUpdates()
    }
    
    // Should be a button and a 1 second delay or so, maybe detect a movement before trying to record? Same sort of code/setup to test
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
    
    // MARK: Class Properties with Observers
    enum CalibrationType {
        case none
        case boop_it
        case twist_it
        case pull_it
        case hold_it
        case slide_it
        case push_it
    }
    
    @IBOutlet weak var StatusLabel: UILabel!
    
    
    // Begins calibration for each move after button is clicked
    @IBAction func BopItButton(_ sender: Any) {
        startCalibration(newCalibrationType: CalibrationType.boop_it)
    }
    
    @IBAction func PullItButton(_ sender: Any) {
        startCalibration(newCalibrationType: CalibrationType.pull_it)
    }
    
    @IBAction func TwistItButton(_ sender: Any) {
        startCalibration(newCalibrationType: CalibrationType.twist_it)
    }
    
    @IBAction func HoldItButton(_ sender: Any) {
        startCalibration(newCalibrationType: CalibrationType.hold_it)
    }
    
    @IBAction func SlideItButton(_ sender: Any) {
        startCalibration(newCalibrationType: CalibrationType.slide_it)
    }
    
    @IBAction func PushItButton(_ sender: Any) {
        startCalibration(newCalibrationType: CalibrationType.push_it)
    }
    func makeModel() {
        // create a GET request for server to update the ML model with current data
        let baseURL = "\(SERVER_URL)/UpdateModel"
        // makes model with dsid of 0
        let query = "?dsid=\(self.dsid)"
        
        let getUrl = URL(string: baseURL+query)
        let request: URLRequest = URLRequest(url: getUrl!)
        let dataTask : URLSessionDataTask = self.session.dataTask(with: request,
              completionHandler:{(data, response, error) in
                // handle error!
                if (error != nil) {
                    if let res = response{
                        print("Response:\n",res)
                    }
                }
                else{
                    let jsonDictionary = self.convertDataToDictionary(with: data)
                    
                    if let resubAcc = jsonDictionary["resubAccuracy"]{
                        print("Resubstitution Accuracy is", resubAcc)
                    }
                }
                                                                    
        })
        
        dataTask.resume() // start the task
        
    }

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
            case .push_it:
                self.isCalibrating = true
                setDelayedWaitingToTrue(1.0)
                break
            case .slide_it:
                self.isCalibrating = true
                setDelayedWaitingToTrue(1.0)
                break
            case .hold_it:
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
        if self.motion.isDeviceMotionAvailable{
            self.motion.deviceMotionUpdateInterval = 1.0/200
            self.motion.startDeviceMotionUpdates(to: motionOperationQueue, withHandler: self.handleMotion )
        }
    }
    func handleMotion(_ motionData:CMDeviceMotion?, error:Error?){
        if let accel = motionData?.userAcceleration {
            self.ringBuffer.addNewData(xData: accel.x, yData: accel.y, zData: accel.z)
            let mag = fabs(accel.x)+fabs(accel.y)+fabs(accel.z)
                        
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
        if(self.isCalibrating){
            //send a labeled example
            if(self.calibrationType != .none && self.isWaitingForMotionData)
            {
                self.isWaitingForMotionData = false
                
                DispatchQueue.main.async {
                    self.StatusLabel.text = "Sending Data to Server"
                }
                
                // send data to the server with label
                sendFeatures(self.ringBuffer.getDataAsVector(),
                             withLabel: self.calibrationType)
            }
        }
    }
    
    //MARK: Calibration
    //MARK: TODO MAKE CONNECTED TO BUTTON
    func startCalibration(newCalibrationType:CalibrationType) {
        self.isWaitingForMotionData = false // dont do anything yet
        self.calibrationType = newCalibrationType
        DispatchQueue.main.async {
            self.StatusLabel.text = "Training a " + "\(newCalibrationType)"
        }
    }
    
    func setDelayedWaitingToTrue(_ time:Double){
        DispatchQueue.main.asyncAfter(deadline: .now() + time, execute: {
            self.isWaitingForMotionData = true
        })
    }
    
    //MARK: Comm with Server
    func sendFeatures(_ array:[Double], withLabel label:CalibrationType){
        let baseURL = "\(SERVER_URL)/AddDataPoint"
        let postUrl = URL(string: "\(baseURL)")

        // create a custom HTTP POST request
        var request = URLRequest(url: postUrl!)

        // data to send in body of post request (send arguments as json)
        let jsonUpload:NSDictionary = ["feature":array,
                                       "label":"\(label)",
                                       "dsid":self.dsid]


        let requestBody:Data? = self.convertDictionaryToData(with:jsonUpload)

        request.httpMethod = "POST"
        request.httpBody = requestBody

        let postTask : URLSessionDataTask = self.session.dataTask(with: request,
            completionHandler:{(data, response, error) in
                if(error != nil){
                    if let res = response{
                        print("Response:\n",res)
                    }
                }
                else{
                    let jsonDictionary = self.convertDataToDictionary(with: data)
                    print(jsonDictionary["feature"]!)
                    print(jsonDictionary["label"]!)
                }

        })

        postTask.resume() // start the task
        
        DispatchQueue.main.async {
            self.StatusLabel.text = "Select a motion to train!"
        }
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
        //Update model
        makeModel()
    }
}
