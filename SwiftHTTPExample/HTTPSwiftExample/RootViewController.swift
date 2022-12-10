import UIKit

class RootViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackground()
        setupBopItLabel()
      }
    
    @IBOutlet weak var bopItLabel: UILabel!
    //TODO: Add animations to this label
    func setupBopItLabel() {
        UIView.animate(withDuration: 0.07, animations: {
            self.bopItLabel.transform = CGAffineTransform(translationX: 10, y: 0)
        }, completion: { (finished: Bool) in
            UIView.animate(withDuration: 0.05, animations: {
                self.bopItLabel.transform = CGAffineTransform(translationX: -10, y: 0)
            }, completion: { (finished: Bool) in
                UIView.animate(withDuration: 0.05, animations: {
                    self.bopItLabel.transform = CGAffineTransform(translationX: 0, y: 0)
                })
            })
        })
    }
    
    lazy var gradient: CAGradientLayer = {
        // https://medium.com/swlh/how-to-create-a-custom-gradient-in-swift-with-cagradientlayer-ios-swift-guide-190941cb3db2
        let gradient = CAGradientLayer()
        gradient.type = .axial
        gradient.colors = [
            UIColor.yellow.withAlphaComponent(0.75).cgColor,
            UIColor.systemTeal.withAlphaComponent(0.75).cgColor,
            UIColor.yellow.withAlphaComponent(0.75).cgColor
        ]
        gradient.locations = [0.33, 0.66, 0.99]
        
        let colorAnimation = CABasicAnimation(keyPath: "colors")
        colorAnimation.fromValue = gradient.colors
        colorAnimation.toValue = [
            UIColor.systemTeal.withAlphaComponent(0.75).cgColor,
            UIColor.yellow.withAlphaComponent(0.75).cgColor,
            UIColor.systemTeal.withAlphaComponent(0.75).cgColor
        ]
        colorAnimation.duration = 3
        colorAnimation.isRemovedOnCompletion = false
        colorAnimation.fillMode = CAMediaTimingFillMode.forwards
        colorAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
        colorAnimation.autoreverses = true
        colorAnimation.repeatCount = Float.infinity
        gradient.add(colorAnimation, forKey: "colorsChangeAnimation")
        
        return gradient
    }()
    
    func setupBackground() {
        gradient.frame = view.bounds
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        view.layer.insertSublayer(gradient, at: 0)

    }
}





