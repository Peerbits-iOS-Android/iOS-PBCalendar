//
//  ViewController.swift
//  PBCalendarDemo
//
//  Created by Shahabuddin on 30/11/18.
//  Copyright © 2018 Peerbits. All rights reserved.
//

import UIKit
import PBCalendar

class ViewController: UIViewController {
    
    @IBOutlet weak var monthHeaderView: PBMonthHeaderView! {
        didSet {
            let appereance = PBMonthHeaderViewAppearance(
                previousButtonImage: #imageLiteral(resourceName: "previous"),
                nextButtonImage: #imageLiteral(resourceName: "next"),
                dateFormat: "LLL-yyyy"
            )
            monthHeaderView.delegate = self
            monthHeaderView.appearance = appereance
        }
    }
    
    @IBOutlet weak var weekDaysView: PBWeekDaysView! {
        didSet {
            let appereance = PBWeekDaysViewAppearance(symbolsType: .veryShort, calendar: defaultCalendar)
            weekDaysView.appearance = appereance
        }
    }
    
    let defaultCalendar: Calendar = {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
    
    var calendarView: PBCalendarView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let calendar = PBCalendar(calendar: defaultCalendar)
        calendarView = PBCalendarView(frame: .zero, calendar: calendar)
        calendarView.showDaysOut = true
        calendarView.selectionStyle = .single
        calendarView.monthDelegate = monthHeaderView
        calendarView.dayViewAppearanceDelegate = self
        calendarView.monthViewAppearanceDelegate = self
        calendarView.calendarDelegate = self
        calendarView.scrollDirection = .horizontal
        //        calendarView.setSupplementaries([
        //            (Date().addingTimeInterval(-(60 * 60 * 70)), [PBDaySupplementary.bottomDots([.red, .magenta])]),
        //            (Date().addingTimeInterval((60 * 60 * 110)), [PBDaySupplementary.bottomDots([.red])]),
        //            (Date().addingTimeInterval((60 * 60 * 370)), [PBDaySupplementary.bottomDots([.blue, .darkGray])]),
        //            (Date().addingTimeInterval((60 * 60 * 430)), [PBDaySupplementary.bottomDots([.orange, .purple, .cyan])])
        //            ])
        view.addSubview(calendarView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if calendarView.frame == .zero {
            calendarView.frame = CGRect(
                x: 0,
                y: weekDaysView.frame.maxY,
                width: view.frame.width,
                height: view.frame.height * 0.6
            )
            calendarView.setup()
        }
    }
    
    
    
}

extension ViewController: PBMonthHeaderViewDelegate {
    
    func didTapNextMonth() {
        calendarView.nextMonth()
    }
    
    func didTapPreviousMonth() {
        calendarView.previousMonth()
    }
    
}

extension ViewController: PBMonthViewAppearanceDelegate {
    
    func leftInset() -> CGFloat {
        return 10.0
    }
    
    func rightInset() -> CGFloat {
        return 10.0
    }
    
    func verticalMonthTitleFont() -> UIFont {
        return UIFont.systemFont(ofSize: 16, weight: .semibold)
    }
    
    func verticalMonthTitleColor() -> UIColor {
        return .black
    }
    
    func verticalCurrentMonthTitleColor() -> UIColor {
        return .red
    }
    
}

extension ViewController: PBDayViewAppearanceDelegate {
    
    func textColor(for state: PBDayState) -> UIColor {
        switch state {
        case .out:
            return UIColor(red: 214 / 255, green: 214 / 255, blue: 219 / 255, alpha: 1.0)
        case .selected:
            return .white
        case .unavailable:
            return .lightGray
        default:
            return .black
        }
    }
    
    func textBackgroundColor(for state: PBDayState) -> UIColor {
        switch state {
        case .selected:
            return .red
        default:
            return .clear
        }
    }
    
    func shape() -> PBDayShape {
        return .circle
    }
    
    func dotBottomVerticalOffset(for state: PBDayState) -> CGFloat {
        switch state {
        case .selected:
            return 2
        default:
            return -7
        }
    }
    
}

extension ViewController: PBCalendarViewDelegate {
    
    func selectedDates(_ dates: [Date]) {
        calendarView.startDate = dates.last ?? Date()
        print(dates)
        print(dates.count)
    }
    func selectedDate(_ date: Date) {
        print(date)
    }
}

