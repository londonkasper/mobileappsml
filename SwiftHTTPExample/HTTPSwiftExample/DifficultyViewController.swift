//
//  DifficultyViewController.swift
//  HTTPSwiftExample
//
//  Created by Jeremy Waibel on 12/11/22.
//  Copyright © 2022 Eric Larson. All rights reserved.
//

import UIKit

class DifficultyViewController: UIViewController {

    @IBOutlet weak var DifficultyLabel: UILabel!
    @IBOutlet weak var ScoreLabel: UILabel!
    @IBOutlet weak var bopItButton: UIButton!

    @IBAction func LeftArrowPress(_ sender: Any) {
        if (difficultyNumber != 0) {
            difficultyNumber -= 1
            afterArrowPress()
        }
    }
    
    @IBAction func RightArrrowPress(_ sender: Any) {
        if (difficultyNumber != 2) {
            difficultyNumber += 1
            afterArrowPress()
        }
    }
    
    @IBAction func PlayButton(_ sender: Any) {
        // Perform the actions that should happen when the Play button is pressed
    }
    var difficultyNumber = 0
    let difficulties = ["Wimp", "Novice", "Expert"]
    let bopItButtonColors = [UIColor.green.withAlphaComponent(0.7), UIColor.orange.withAlphaComponent(0.7), UIColor.red.withAlphaComponent(0.7)]
    
    let colors = [[UIColor.green.withAlphaComponent(0.5).cgColor, UIColor.magenta.withAlphaComponent(0.5).cgColor],
                  [UIColor.orange.withAlphaComponent(0.5).cgColor, UIColor.systemTeal.withAlphaComponent(0.5).cgColor],
                  [UIColor.red.withAlphaComponent(0.5).cgColor, UIColor.cyan.withAlphaComponent(0.5).cgColor]
    ] //Colors for easy, medium, and hard , [x][0] is main, [x][1] is complimentary
    
    override func viewDidLoad() {
        super.viewDidLoad()
        DifficultyLabel.text = difficulties[difficultyNumber]
        bopItButton.backgroundColor = bopItButtonColors[difficultyNumber]
        setupBackground(remove: false)
        getHighScore()
    }
    
    func afterArrowPress() {
        DifficultyLabel.text = difficulties[difficultyNumber]
        bopItButton.backgroundColor = bopItButtonColors[difficultyNumber]

        setupBackground(remove: true)
        getHighScore()
    }
    func getHighScore() {
        if let score = UserDefaults.standard.string(forKey: difficulties[difficultyNumber]) {
            ScoreLabel.text = score
        } else {
            ScoreLabel.text = "0"
        }
    }
    
    func setupBackground(remove: Bool) {
        let gradient = CAGradientLayer()
        gradient.type = .axial
        gradient.colors = [
            colors[difficultyNumber][0],
            colors[difficultyNumber][1],
            colors[difficultyNumber][0],
            colors[difficultyNumber][1]
        ]
        gradient.locations = [0.2, 0.3, 0.6, 0.8]
        
        let colorAnimation = CABasicAnimation(keyPath: "colors")
        colorAnimation.fromValue = gradient.colors
        colorAnimation.toValue = [
            colors[difficultyNumber][1],
            colors[difficultyNumber][0],
            colors[difficultyNumber][1],
            colors[difficultyNumber][0]
        ]
        colorAnimation.duration = 3
        colorAnimation.isRemovedOnCompletion = false
        colorAnimation.fillMode = CAMediaTimingFillMode.forwards
        colorAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
        colorAnimation.autoreverses = true
        colorAnimation.repeatCount = Float.infinity
        gradient.add(colorAnimation, forKey: "colorsChangeAnimation")
        gradient.frame = view.bounds
        gradient.startPoint = CGPoint(x: 0.2, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        if(remove) {
            view.layer.sublayers?[0].removeFromSuperlayer() //remove old layer
        }
        view.layer.insertSublayer(gradient, at: 0)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
               
           // Create a variable to store the name the user entered on textField
        let difficulty = self.difficultyNumber
               
           // Create a new variable to store the instance of the SecondViewController
           // set the variable from the SecondViewController that will receive the data
           let destinationVC = segue.destination as! GameViewController
           destinationVC.userGame = difficulty
       }
}
