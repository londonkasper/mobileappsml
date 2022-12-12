//
//  HowToPlayViewController.swift
//  HTTPSwiftExample
//
//  Created by Carys LeKander on 12/11/22.
//  Code adapted from:
//      https://medium.com/@anitaa_1990/create-a-horizontal-paging-uiscrollview-with-uipagecontrol-swift-4-xcode-9-a3dddc845e92
//      and
//      https://www.youtube.com/watch?v=EKAVB_56RIU&t=9s
//

import UIKit

class HowToPlayViewController: UIViewController {
    
    let bopItBlue = UIColor(red: 0.30, green: 0.84, blue: 0.96, alpha: 1.00)
    let bopItYellow = UIColor(red: 1.00, green: 0.90, blue: 0.24, alpha: 1.00)
    let bopItPurple = UIColor(red: 0.52, green: 0.41, blue: 0.82, alpha: 1.00)
    
    private let scrollView = UIScrollView()
    
    private let pageControl: UIPageControl = {
        let pageControl = UIPageControl()
        pageControl.numberOfPages = 7
        pageControl.backgroundColor = .black
        return pageControl
    }()
    
    func createSlides() -> [Slide] {

            let slide1:Slide = Bundle.main.loadNibNamed("Slide", owner: self, options: nil)?.first as! Slide
           // slide1.imageView.image = UIImage(named: "ic_onboarding_1")
            slide1.moveTitle.text = "Welcome to Boop It!"
            slide1.moveDesc.text = "Are you ready to Boop to your heart's content? Do the moves on the screen before the time runs out!"
        
            let slide2:Slide = Bundle.main.loadNibNamed("Slide", owner: self, options: nil)?.first as! Slide
           // slide1.imageView.image = UIImage(named: "ic_onboarding_1")
            slide2.moveTitle.text = ""
            slide2.moveDesc.text = "For best results, hold phone in  left hand and do moves sharply and quickly. Swipe for tutorials on each move"
        
            let slide3:Slide = Bundle.main.loadNibNamed("Slide", owner: self, options: nil)?.first as! Slide
            //slide2.imageView.image = UIImage(named: "ic_onboarding_2")
            slide3.moveTitle.text = "Boop It"
            slide3.moveDesc.text = "Hit your phone"
            
            let slide4:Slide = Bundle.main.loadNibNamed("Slide", owner: self, options: nil)?.first as! Slide
            //slide3.imageView.image = UIImage(named: "ic_onboarding_3")
            slide4.moveTitle.text = "Pull It"
            slide4.moveDesc.text = "Pull your phone into your chest"
            
            let slide5:Slide = Bundle.main.loadNibNamed("Slide", owner: self, options: nil)?.first as! Slide
            //slide4.imageView.image = UIImage(named: "ic_onboarding_4")
            slide5.moveTitle.text = "Twist It"
            slide5.moveDesc.text = "Twist your phone clockwise"
            
            
            let slide6:Slide = Bundle.main.loadNibNamed("Slide", owner: self, options: nil)?.first as! Slide
            //slide5.imageView.image = UIImage(named: "ic_onboarding_5")
            slide6.moveTitle.text = "Push It"
            slide6.moveDesc.text = "Push your phone away from you"
        
            let slide7:Slide = Bundle.main.loadNibNamed("Slide", owner: self, options: nil)?.first as! Slide
            //slide7.imageView.image = UIImage(named: "ic_onboarding_5")
            slide7.moveTitle.text = "Slide It"
            slide7.moveDesc.text = "Slide your phone to the right"
            
            return [slide1, slide2, slide3, slide4, slide5, slide6, slide7]
        }
    var slides:[Slide] = [];
    override func viewDidLoad() {
        super.viewDidLoad()
        slides = createSlides()
        print(slides.count)
        scrollView.delegate = self
        pageControl.addTarget(self, action:#selector(pageControlDidChange(_:)), for: .valueChanged)
        view.addSubview(scrollView)
        view.addSubview(pageControl)
    }
    
    @objc private func pageControlDidChange(_ sender: UIPageControl) {
        let current = sender.currentPage
        scrollView.setContentOffset(CGPoint(x: CGFloat(current) * view.frame.size.width, y: 0), animated: true)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        pageControl.frame = CGRect(x:10, y: view.frame.size.height-100, width: view.frame.size.width-20, height: 70)
        scrollView.frame = CGRect(x: 0, y:0, width: view.frame.size.width, height: view.frame.size.height - 100)
        
        if scrollView.subviews.count == 2 {
            configureScrollView()
        }
    }
    
    private func configureScrollView() {
        scrollView.contentSize = CGSize(width: view.frame.size.width*7, height: 0)
        scrollView.isPagingEnabled = true
        let colors: [UIColor]  = [
            self.bopItBlue,
            self.bopItYellow,
            self.bopItPurple,
            self.bopItBlue,
            self.bopItYellow,
            self.bopItPurple,
            self.bopItBlue]
        
        for i in 0..<7 {
            print(i)
            slides[i].frame = CGRect(x: CGFloat(i) * view.frame.size.width, y: 0, width: view.frame.size.width, height: scrollView.frame.size.height)
            slides[i].backgroundColor = colors[i]
            scrollView.addSubview(slides[i])
        }
    }
    
    
}

extension HowToPlayViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !(floorf(Float(scrollView.contentOffset.x)) / Float(scrollView.frame.size.width)).isNaN {
            pageControl.currentPage = Int(floorf(Float(scrollView.contentOffset.x) / Float(scrollView.frame.size.width)))
        }
        else {
            pageControl.currentPage = 0
        }
    }
}
