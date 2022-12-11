//
//  Game.swift
//  HTTPSwiftExample
//
//  Created by Carys LeKander on 12/10/22.
//  Copyright © 2022 Eric Larson. All rights reserved.
//


import UIKit
import CoreMotion

class GameViewController: UIViewController, URLSessionDelegate {
    let SERVER_URL = "http://10.9.142.187:8000" // change this for your server name!!!
    
    let moves = ["['twist_it']", "['pull_it']", "['boop_it']","['push_it']", "['slide_it']"]
    let faster = [10, 15, 20]
    let speed = [3.0, 2.0, 1.5]
    var gameSpeed = 0.0
    var roundsToFaster = 0
    var userGame = 0
    var score = 0
    var userMotion = ""
    var randomMove = ""
    
    var timer = Timer()

    @IBOutlet weak var motionLabel: UILabel!
    @IBOutlet weak var scoreLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        gameSpeed = speed[userGame]
        print(gameSpeed)
        roundsToFaster = faster[userGame]
        startMotionUpdates()
        play()
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
    
    var moveNum = 0
    func play() {
        var playing = true
        print(self.gameSpeed)
        timer = Timer.scheduledTimer(withTimeInterval: gameSpeed,
                                                 repeats: true) { timer in
            if self.moveNum != 0 && self.userMotion == "" {
                print("You didn't make a move in time!")
                timer.invalidate() // invalidate the timer
                playing = false
                self.isWaitingForMotionData = false
            }
            if (playing) {
                self.userMotion = ""
                self.motionLabel.text = self.userMotion
                let move = Int.random(in: 0...4)
                self.randomMove = self.moves[move]
                print("Random Move: " + self.randomMove)
                self.motionLabel.text = self.randomMove
                self.scoreLabel.text = String(self.score)
                self.isWaitingForMotionData = true
                self.moveNum += 1

            }
            if playing && self.moveNum % self.roundsToFaster == 0 && self.gameSpeed > 1.2 {
                print("here")
                self.gameSpeed -= 0.1
                self.moveNum += 1
                timer.invalidate()
                self.play()
                playing = false
            }
        }
    }
    
    //MARK: Calibration procedure
    func largeMotionEventOccurred(){
        if(self.isWaitingForMotionData){
            self.isWaitingForMotionData = false
            //Send Prediction
            getPrediction(self.ringBuffer.getDataAsVector())
        }
    }

        func getPrediction(_ array:[Double]){
            let baseURL = "\(SERVER_URL)/Predict"
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
                                    // server sets trained to false if prediction is called without a model, otherwise key does not exist
                                    // prevents app from breaking if model is not trained
                                    if jsonDictionary["trained"] != nil {
                                        //self.PredictionLabel.text = "Please Train Model"
                                    }
                                    else {
                                        self.userMotion = (jsonDictionary["prediction"]! as? String)!
                                        print("User Motion: " + self.userMotion)

                                        if(self.userMotion != self.randomMove) {
                                            self.motionLabel.text = "Wrong Move!"
                                            print("Wrong Move!")
                                            self.timer.invalidate()
                                        }
                                        else {
                                            self.score += 1
                                            self.scoreLabel.text = String(self.score)
                                            print("Correct Move!")
                                        }
                                    }
                                }
                            }
    
            })
    
            postTask.resume() // start the task
        }
    
    //MARK: Calibration
    //MARK: TODO MAKE CONNECTED TO BUTTON
    func startCalibration() {
        DispatchQueue.main.async{
            //self.PredictionLabel.text = "Waiting..."
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
