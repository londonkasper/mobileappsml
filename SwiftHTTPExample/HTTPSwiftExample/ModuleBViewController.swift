//
//  ModuleBViewController.swift
//  HTTPSwiftExample
//
//  Created by Jeremy Waibel on 11/20/22.
//  Copyright © 2022 Eric Larson. All rights reserved.
//

import UIKit
import CoreMotion

class ModuleBViewController: UIViewController, URLSessionDelegate{
    let SERVER_URL = "http://10.8.144.86:8000" // change this for your server name!!!

    @IBOutlet weak var forestPrediction: UILabel!
    @IBOutlet weak var maxIterationsForrest: UILabel!
    @IBOutlet weak var maxDepthForrest: UILabel!
    @IBAction func iterationStepperForrest(_ sender: UIStepper) {
        self.maxIterationsForrest.text = String(Int(sender.value))
    }
    @IBAction func depthStepperForrest(_ sender: UIStepper) {
        self.maxDepthForrest.text = String(Int(sender.value))
    }

    
    @IBOutlet weak var treePrediction: UILabel!
    @IBOutlet weak var maxDepthTree: UILabel!
    @IBOutlet weak var maxIterationsTree: UILabel!
    @IBAction func iterationsStepperTree(_ sender: UIStepper) {
        self.maxIterationsTree.text = String(Int(sender.value))
    }
    @IBAction func depthStepperTree(_ sender: UIStepper) {
        self.maxDepthTree.text = String(Int(sender.value))
    }
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.maxDepthForrest.text = "0"
        self.maxIterationsForrest.text = "5"
        self.maxDepthTree.text = "0"
        self.maxIterationsTree.text = "5"
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
    
    // updates both models with any new params from user
    @IBAction func updateModelButton(_ sender: Any) {
        makeRFCModel();
        makeBTModel();
    }
    
    @IBAction func predictionMotionButton(_ sender: Any) {
        self.startCalibration()
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

    func largeMotionEventOccurred(){
        if(self.isCalibrating && self.isWaitingForMotionData){
            self.isWaitingForMotionData = false
            self.isCalibrating = false
                // gets prediction from both Random Forest and Boosted Trees Models
                getRFCPrediction(self.ringBuffer.getDataAsVector())
                getBTPrediction(self.ringBuffer.getDataAsVector())
            }
    }
    func startCalibration() {
        DispatchQueue.main.async{
            self.forestPrediction.text = "Waiting..."
            self.treePrediction.text = "Waiting..."
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
    
    func getRFCPrediction(_ array:[Double]){
           let baseURL = "\(SERVER_URL)/PredictGivenModel"
           let postUrl = URL(string: "\(baseURL)")
           // create a custom HTTP POST request
           var request = URLRequest(url: postUrl!)
           // data to send in body of post request (send arguments as json)
           // includes type  of  model to train
           let jsonUpload:NSDictionary = ["feature":array, "dsid":self.dsid, "type":"rfc"]
           let requestBody:Data? = self.convertDictionaryToData(with:jsonUpload)
           request.httpMethod = "POST"
           request.httpBody = requestBody
           let postTask : URLSessionDataTask = self.session.dataTask(with: request,completionHandler:{
               (data, response, error) in
                           if(error != nil){
                               if let res = response{
                                   print("Response:\n",res)
                               }
                           }
                           else{ // no error we are aware of
                               let jsonDictionary = self.convertDataToDictionary(with: data)
                               
                                DispatchQueue.main.async{
                                    // server sets trained to false if prediction is called without a model, otherwise key does not exist
                                    // prevents app from breaking if model is not trained
                                    if jsonDictionary["trained"] != nil {
                                        self.forestPrediction.text = "Please Train Model"
                                    }
                                    else {
                                        self.forestPrediction.text = jsonDictionary["prediction"]! as? String
                                    }
                                }
                                
                           }
           })
           postTask.resume() // start the task
       }
    func getBTPrediction(_ array:[Double]){
           let baseURL = "\(SERVER_URL)/PredictGivenModel"
           let postUrl = URL(string: "\(baseURL)")
           // create a custom HTTP POST request
           var request = URLRequest(url: postUrl!)
           // data to send in body of post request (send arguments as json)
           // includes type  of  model to train
           let jsonUpload:NSDictionary = ["feature":array, "dsid":self.dsid, "type":"btm"]
           let requestBody:Data? = self.convertDictionaryToData(with:jsonUpload)
           request.httpMethod = "POST"
           request.httpBody = requestBody
           let postTask : URLSessionDataTask = self.session.dataTask(with: request,completionHandler:{
               (data, response, error) in
                           if(error != nil){
                               if let res = response{
                                   print("Response:\n",res)
                               }
                           }
                           else{ // no error we are aware of
                               let jsonDictionary = self.convertDataToDictionary(with: data)
                               
                                DispatchQueue.main.async{
                                    // server sets trained to false if prediction is called without a model, otherwise key does not exist
                                    // prevents app from breaking if model is not trained
                                    if jsonDictionary["trained"] != nil {
                                        self.treePrediction.text = "Please Train Model"
                                    }
                                    else {
                                        self.treePrediction.text = jsonDictionary["prediction"]! as? String
                                    }
                                }
                                
                           }
           })
           postTask.resume() // start the task
       }
    
    func makeRFCModel() {
           // create a GET request for server to update the ML model with current data
           let baseURL = "\(SERVER_URL)/UpdateGivenModel"
           let postUrl = URL(string: "\(baseURL)")
           // create a custom HTTP POST request
           var request = URLRequest(url: postUrl!)
           // data to send in body of post request (send arguments as json)
           //  includes model type and user submitted params
           let jsonUpload:NSDictionary = ["type":"rfc",
                                          "max_iters":maxIterationsForrest.text!,
                                          "max_depth":maxDepthForrest.text!,
                                          "dsid":dsid]
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
                       if let resubAcc = jsonDictionary["resubAccuracy"]{
                           print("Resubstitution Accuracy is", resubAcc)
                       }
                   }
           })
           postTask.resume() // start the task
       }

       func makeBTModel() {
           // create a GET request for server to update the ML model with current data
           let baseURL = "\(SERVER_URL)/UpdateGivenModel"
           let postUrl = URL(string: "\(baseURL)")
           // create a custom HTTP POST request
           var request = URLRequest(url: postUrl!)
           // data to send in body of post request (send arguments as json)
           //  includes model type and user submitted params
           let jsonUpload:NSDictionary = ["type":"btm",
                                          "max_iters":maxIterationsTree.text!,
                                          "max_depth":maxDepthTree.text!,
                                          "dsid":dsid]

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
                       if let resubAcc = jsonDictionary["resubAccuracy"]{
                           print("Resubstitution Accuracy is", resubAcc)
                       }
                   }
           })
           postTask.resume() // start the task
       }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.motion.stopDeviceMotionUpdates()
    }

}
