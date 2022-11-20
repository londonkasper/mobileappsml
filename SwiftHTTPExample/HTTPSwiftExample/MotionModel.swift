//
//  MotionModel.swift
//  HTTPSwiftExample
//
//  Created by Jeremy Waibel on 11/20/22.
//  Copyright © 2022 Eric Larson. All rights reserved.
//

//import CoreMotion

//MARK: Lost cause :( FIXME Next time girlies
//class MotionModel {
//    //Minimum magnitude to record motion data
//    var magValue = 0.2
//    
//    let motionOperationQueue = OperationQueue()
//    let calibrationOperationQueue = OperationQueue()
//
//    var ringBuffer = RingBuffer()
//    let motion = CMMotionManager()
//
//    var isCalibrating = false
//    var isWaitingForMotionData = false
//
//    let group = DispatchGroup()
//    var motionData:[Double] = []
//
//    func startMotionUpdates(){
//        // some internal inconsistency here: we need to ask the device manager for device
//
//        if self.motion.isDeviceMotionAvailable{
//            self.motion.deviceMotionUpdateInterval = 1.0/200
//            self.motion.startDeviceMotionUpdates(to: motionOperationQueue, withHandler: self.handleMotion )
//        }
//    }
//    func handleMotion(_ motionData:CMDeviceMotion?, error:Error?){
//        if let accel = motionData?.userAcceleration {
//            self.ringBuffer.addNewData(xData: accel.x, yData: accel.y, zData: accel.z)
//            let mag = fabs(accel.x)+fabs(accel.y)+fabs(accel.z)
//
//            //print magnitude for testing
//
//            if mag > self.magValue {
//                // buffer up a bit more data and then notify of occurrence
//                print("ENTER")
//                self.group.enter()
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: {
//                    self.calibrationOperationQueue.addOperation {
//                        // something large enough happened to warrant
//                        self.largeMotionEventOccurred()
//                    }
//                })
//            }
//        }
//    }
//    //MARK: Calibration procedure
//    func largeMotionEventOccurred(){
//        print("LARGE :D")
//        if(self.isCalibrating){
//            //send a labeled example
//            if(self.isWaitingForMotionData)
//            {
//                self.isWaitingForMotionData = false
//                print("HERE")
//                // return data, does not need label since view controller knows label / prediction will guess label
//                motionData = self.ringBuffer.getDataAsVector()
////                sendFeatures(self.ringBuffer.getDataAsVector(),
////                             withLabel: self.calibrationType)
//            }
//        }
//        else
//        {
//            self.isWaitingForMotionData = false
//        }
//    }
//
//    //Called by button from view controller
//    func startCalibration() -> [Double] {
//        self.isCalibrating = true
//        setDelayedWaitingToTrue(1.0)
//        //Wait until we get a result to return it
//        print("wait???")
//        self.group.wait();
//
//        print(self.motionData)
//        let res = self.motionData
//        self.motionData = []
//        return res
//
//    }
//
//    func setDelayedWaitingToTrue(_ time:Double){
//        DispatchQueue.main.asyncAfter(deadline: .now() + time, execute: {
//            self.isWaitingForMotionData = true
//        })
//    }
//
//    func stopMotionUpdates(){
//        self.motion.stopDeviceMotionUpdates()
//    }
//}
