//
//  ModuleBViewController.swift
//  HTTPSwiftExample
//
//  Created by Jeremy Waibel on 11/20/22.
//  Copyright © 2022 Eric Larson. All rights reserved.
//

import UIKit
import CoreMotion

class ModuleBViewController: UIViewController, URLSessionDelegate, UIPickerViewDataSource,  UIPickerViewDelegate{
    let SERVER_URL = "http://10.8.144.86:8000" // change this for your server name!!!

    @IBOutlet weak var forestPrediction: UILabel!
    @IBOutlet weak var maxIterations: UILabel!
    @IBOutlet weak var maxDepth: UILabel!
    @IBAction func iterationStepper(_ sender: UIStepper) {
        self.maxIterations.text = String(Int(sender.value))
    }
    @IBAction func depthStepper(_ sender: UIStepper) {
        self.maxDepth.text = String(Int(sender.value))
    }
    
    
    @IBOutlet weak var knnPrediction: UILabel!
    @IBOutlet weak var distanceType: UIPickerView!
    
    
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
        self.maxDepth.text = "0"
        self.maxIterations.text = "5"
        distanceType.dataSource = self
        distanceType.delegate = self
        
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
            //Send Prediction
                getPrediction(self.ringBuffer.getDataAsVector())
            }
    }
    func startCalibration() {
        DispatchQueue.main.async{
            self.forestPrediction.text = "Waiting..."
            self.knnPrediction.text = "Waiting..."
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
    
    func getPrediction(_ array:[Double]){
           self.makeRFCModel()
           self.makeKNNModel()
           let baseURL = "\(SERVER_URL)/PredictOne"
           let postUrl = URL(string: "\(baseURL)")
           // create a custom HTTP POST request
           var request = URLRequest(url: postUrl!)
           // data to send in body of post request (send arguments as json
           let jsonUpload:NSDictionary = ["feature":array, "dsid":self.dsid]
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
                               //TODO UPDATE LABELS
                               /**
                                DispatchQueue.main.async{
                                    self.PredictionLabel.text = jsonDictionary["prediction"]! as? String
                                }
                                */
                           }
           })
           postTask.resume() // start the task
       }
    
       func makeRFCModel() {
           // create a GET request for server to update the ML model with current data
           let baseURL = "\(SERVER_URL)/UpdateWithModel"
           let postUrl = URL(string: "\(baseURL)")
           // create a custom HTTP POST request
           var request = URLRequest(url: postUrl!)
           // data to send in body of post request (send arguments as json)
           let jsonUpload:NSDictionary = ["type":"rfc",
                                          "max_iters":maxIterations.text,
                                          "max_depth":maxDepth.text]
           let _:Data? = self.convertDictionaryToData(with:jsonUpload)
           let postTask : URLSessionDataTask = self.session.dataTask(with: request,
               completionHandler:{(data, response, error) in
                   if(error != nil){
                       if let res = response{
                           print("Response:\n",res)
                       }
                   }
                   else{
                       let jsonDictionary = self.convertDataToDictionary(with: data)
                   }
           })
           postTask.resume() // start the task
       }
       lazy private var data = ["Euclidean", "Squared Euclidean", "Manhattan", "Levenshtein", "Jaccard", "Weighted Jaccard", "Cosine", "Transformed Dot Product"]

       func makeKNNModel() {
           // create a GET request for server to update the ML model with current data
           let baseURL = "\(SERVER_URL)/UpdateWithModel"
           let postUrl = URL(string: "\(baseURL)")
           // create a custom HTTP POST request
           var request = URLRequest(url: postUrl!)
           let distance = data[distanceType.selectedRow(inComponent: 0)]
           // data to send in body of post request (send arguments as json)
           let jsonUpload:NSDictionary = ["type":"knn",
                                          "distance":distance]
           let _:Data? = self.convertDictionaryToData(with:jsonUpload)
           let postTask : URLSessionDataTask = self.session.dataTask(with: request,
               completionHandler:{(data, response, error) in
                   if(error != nil){
                       if let res = response{
                           print("Response:\n",res)
                       }
                   }
                   else{
                       let jsonDictionary = self.convertDataToDictionary(with: data)
                   }
           })
           postTask.resume() // start the task
       }

       func numberOfComponents(in pickerView: UIPickerView) -> Int {
           return 1
       }

       func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
           return data.count
       }

       

       func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
           if let title = data[row] as? String {
               return title
           }
           return ""
       }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.motion.stopDeviceMotionUpdates()
    }

}
