//
//  TrainingViewController.swift
//  HTTPSwiftExample
//
//  Created by Jeremy Waibel on 11/20/22.
//  Copyright © 2022 Eric Larson. All rights reserved.
//

import UIKit
import CoreMotion

let SERVER_URL = "http://10.0.1.6:8000" // change this for your server name!!!

class TrainingViewController: UIViewController, URLSessionDelegate {

    //MARK: Basic setup, not at all good / clean / completed.
    //MARK: Maybe make seperate models for handeling server / motion activity - Code reuseability.
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
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
    
    var dsid = 0;
    
    //Minimum magniture to record motion data
    var magValue = 0.1

    // MARK: Class Properties with Observers
    enum CalibrationStage {
        case none
        case bop_it
        case whip_it
        case naynay
    }

    //Todo some animation or something, probably can do with button clicks or smthing
    var calibrationStage:CalibrationStage = .none {
        didSet{
            switch calibrationStage {
            case .bop_it:
                self.isCalibrating = true
                break
            case .whip_it:
                self.isCalibrating = true
                break
            case .naynay:
                self.isCalibrating = true
                break
            case .none:
                self.isCalibrating = false
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
        if(self.isCalibrating){
            //send a labeled example
            if(self.calibrationStage != .none && self.isWaitingForMotionData)
            {
                self.isWaitingForMotionData = false
                
                // send data to the server with label
                sendFeatures(self.ringBuffer.getDataAsVector(),
                             withLabel: self.calibrationStage)
                
                self.nextCalibrationStage()
            }
        }
        else
        {
            //Tpdp no predictions in this controller, only training
            if(self.isWaitingForMotionData)
            {
                self.isWaitingForMotionData = false
                //predict a label
                //getPrediction(self.ringBuffer.getDataAsVector())
                // dont predict again for a bit
                //setDelayedWaitingToTrue(2.0)
            }
        }
    }
    
    func nextCalibrationStage(){
        //todo set calibration stage with button press
    }
    
    //MARK: Get New Dataset ID
    @IBAction func getDataSetId(_ sender: AnyObject) {
        // create a GET request for a new DSID from server
        let baseURL = "\(SERVER_URL)/GetNewDatasetId"
        
        let getUrl = URL(string: baseURL)
        let request: URLRequest = URLRequest(url: getUrl!)
        let dataTask : URLSessionDataTask = self.session.dataTask(with: request,
            completionHandler:{(data, response, error) in
                if(error != nil){
                    print("Response:\n%@",response!)
                }
                else{
                    let jsonDictionary = self.convertDataToDictionary(with: data)
                    
                    // This better be an integer
                    if let dsid = jsonDictionary["dsid"]{
                        self.dsid = dsid as! Int
                    }
                }
                
        })
        
        dataTask.resume() // start the task
    }
    
    //MARK: Calibration
    //MARK: TODO MAKE CONNECTED TO BUTTON
    @IBAction func startCalibration(_ sender: AnyObject) {
        self.isWaitingForMotionData = false // dont do anything yet
        nextCalibrationStage()
    }
    
    //MARK: Comm with Server
    func sendFeatures(_ array:[Double], withLabel label:CalibrationStage){
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
}
