//
//  HowToPlayViewController.swift
//  HTTPSwiftExample
//
//  Created by Carys LeKander on 12/11/22.
//  Copyright © 2022 Eric Larson. All rights reserved.
//

import UIKit

class HowToPlayViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    
    private let pageControl: UIPageControl = {
        let pageControl = UIPageControl()
        pageControl.numberOfPages = 6
        pageControl.backgroundColor = .systemBlue
        return pageControl
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
        scrollView.contentSize = CGSize(width: view.frame.size.width*6, height: scrollView.frame.size.height)
        scrollView.isPagingEnabled = true
        let colors: [UIColor]  = [
            .systemRed,
            .systemGreen,
            .systemGray,
            .systemOrange,
            .systemPurple,
            .systemPink]
        
        for x in 0..<6 {
            let page = UIView(frame: CGRect(x: CGFloat(x) * view.frame.size.width, y: 0, width: view.frame.size.width, height: scrollView.frame.size.height))
            page.backgroundColor = colors[x]
            scrollView.addSubview(page)
        }
    }
    
    
}

extension HowToPlayViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        pageControl.currentPage = Int(floorf(Float(scrollView.contentOffset.x)) / Float(scrollView.frame.size.width))
    }
}
