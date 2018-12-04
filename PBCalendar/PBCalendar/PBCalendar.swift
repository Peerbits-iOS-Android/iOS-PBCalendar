//
//  PBCalendar.swift
//  PBCalendar
//
//  Calender
//
//  Created by macmini7 on 06/09/18.
//  Copyright © 2018 macmini7. All rights reserved.
//

import Foundation
import UIKit

// MARK: Private Public Protocols

protocol PBCalendarDelegate: class {
    func selectedDaysDidUpdate(_ days: [PBDay])
}

protocol PBWeekViewDelegate: class {
    func dayStateChanged(_ day: PBDay, in week: PBWeek)
}
protocol PBMonthViewDelegate: class {
    func dayStateChanged(_ day: PBDay, in month: PBMonth)
}

@objc
public protocol PBMonthViewAppearanceDelegate: class {
    @objc optional func leftInset() -> CGFloat
    @objc optional func rightInset() -> CGFloat
    @objc optional func verticalMonthTitleFont() -> UIFont
    @objc optional func verticalMonthTitleColor() -> UIColor
    @objc optional func verticalCurrentMonthTitleColor() -> UIColor
}

public protocol PBMonthHeaderViewDelegate: class {
    func didTapNextMonth()
    func didTapPreviousMonth()
}

@objc
public protocol PBDayViewAppearanceDelegate: class {
    @objc optional func font(for state: PBDayState) -> UIFont
    @objc optional func textColor(for state: PBDayState) -> UIColor
    @objc optional func textBackgroundColor(for state: PBDayState) -> UIColor
    @objc optional func backgroundColor(for state: PBDayState) -> UIColor
    @objc optional func borderWidth(for state: PBDayState) -> CGFloat
    @objc optional func borderColor(for state: PBDayState) -> UIColor
    @objc optional func dotBottomVerticalOffset(for state: PBDayState) -> CGFloat
    @objc optional func shape() -> PBDayShape
    // percent of the selected area to be painted
    @objc optional func selectedArea() -> CGFloat
}

protocol PBDayViewDelegate: class {
    func dayStateChanged(_ day: PBDay)
}

@objc
public protocol PBCalendarViewDelegate: class {
    // use this method for single selection style
    @objc optional func selectedDate(_ date: Date)
    // use this method for multi selection style
    @objc optional func selectedDates(_ dates: [Date])
}
public protocol PBCalendarMonthDelegate: class {
    func monthDidChange(_ currentMonth: Date)
}

// MARK: Private Public enums

public enum DaysAvailability {
    case all
    case some([Date])
}
public enum PBSelectionStyle {
    case single, multi
}

public enum PBCalendarScrollDirection {
    case horizontal, vertical
}

public enum PBCalendarViewType {
    case month, week
}

@objc
public enum PBDayState: Int {
    case out, selected, available, unavailable
}

@objc
public enum PBDayShape: Int {
    case square, circle
}

public enum PBDaySupplementary: Hashable {
    
    // 3 dot max
    case bottomDots([UIColor])
    
    public var hashValue: Int {
        switch self {
        case .bottomDots:
            return 1
        }
    }
    
    public static func ==(lhs: PBDaySupplementary, rhs: PBDaySupplementary) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
    
}

public enum PBWeekDaysSymbolsType {
    case short, veryShort
    
    func names(from calendar: Calendar) -> [String] {
        switch self {
        case .short:
            return calendar.shortWeekdaySymbols
        case .veryShort:
            return calendar.veryShortWeekdaySymbols
        }
    }
    
}

// MARK: Public Class

public class PBCalendar {
    
    var months = [PBMonth]()
    weak var delegate: PBCalendarDelegate?
    
    private let calendar: Calendar
    private var daysAvailability: DaysAvailability = .all
    
    private var selectedDays = [PBDay]() {
        didSet {
            delegate?.selectedDaysDidUpdate(selectedDays)
        }
    }
    
    public init(
        startDate: Date? = nil,
        endDate: Date? = nil,
        selectedDate: Date? = Date(),
        calendar: Calendar = Calendar.current) {
        self.calendar = calendar
        
        if let selectedDate = selectedDate {
            let day = PBDay(date: selectedDate, state: .selected, calendar: calendar)
            selectedDays = [day]
        }
        
        let startDate = startDate ?? calendar.date(byAdding: .year, value: -1, to: Date())!
        let endDate = endDate ?? calendar.date(byAdding: .year, value: 20, to: Date())!
        months = generateMonths(from: startDate, endDate: endDate)
    }
    
    func selectDay(_ day: PBDay) {
        months.first(where: { $0.dateInThisMonth(day.date) })?.setDaySelectionState(day, state:.selected)
        selectedDays = [day]
    }
    
    func selectDates(_ dates: [Date]) {
        let days = months.flatMap { $0.days(for: dates) }
        days.forEach { $0.setSelectionState(.selected) }
        selectedDays = days
    }
    
    func setDaysAvailability(_ availability: DaysAvailability) {
        daysAvailability = availability
        
        switch availability {
        case .all:
            let days = months.flatMap { $0.allDays() }
            days.forEach { $0.setState(.available) }
            
        case .some(let dates):
            let allDays = months.flatMap { $0.allDays() }
            allDays.forEach { $0.setState(.unavailable) }
            let availableDays = dates.flatMap { date in allDays.filter { $0.dateInDay(date) }}
            availableDays.forEach { $0.setState(.available) }
        }
    }
    
    func setDaySelectionState(_ day: PBDay, state: PBDayState) {
        months.first(where: { $0.dateInThisMonth(day.date) })?.setDaySelectionState(day, state: state)
        
        if let indexOfPerson1 = selectedDays.index(where: {$0 === day})
        {
            
             selectedDays.remove(at: indexOfPerson1)
        }
        else
        {
            self.selectedDays.append(day)
        }
       
    }
    
    func setSupplementaries(_ data: [(Date, [PBDaySupplementary])]) {
        let dates = data.map { $0.0 }
        let days = months.flatMap { $0.days(for: dates) }
        
        days.forEach { day in
            guard let supplementaries = data.first(where: { day.dateInDay($0.0) })?.1 else { return }
            day.set(supplementaries)
        }
    }
    
    func deselectAll() {
        selectedDays = []
        months.forEach { $0.deselectAll() }
    }
    
    private func generateMonths(from startDate: Date, endDate: Date) -> [PBMonth] {
        let startComponents = calendar.dateComponents([.year, .month], from: startDate)
        let endComponents = calendar.dateComponents([.year, .month], from: endDate)
        var startDate = calendar.date(from: startComponents)!
        let endDate = calendar.date(from: endComponents)!
        var months = [PBMonth]()
        
        repeat {
            let date = startDate
            let month = PBMonth(month: date, calendar: calendar)
            month.selectedDays = selectedDays.filter { calendar.isDate($0.date, equalTo: startDate, toGranularity: .month) }
            months.append(month)
            startDate = calendar.date(byAdding: .month, value: 1, to: date)!
        } while !calendar.isDate(startDate, inSameDayAs: endDate)
        
        return months
    }
    
}

public class PBCalendarView: UIScrollView {
    
    public weak var monthDelegate: PBCalendarMonthDelegate?
    public weak var dayViewAppearanceDelegate: PBDayViewAppearanceDelegate?
    public weak var monthViewAppearanceDelegate: PBMonthViewAppearanceDelegate?
    public weak var calendarDelegate: PBCalendarViewDelegate?
    
    public var scrollDirection: PBCalendarScrollDirection = .vertical
    // use this for vertical scroll direction
    public var monthVerticalInset: CGFloat = 20
    public var monthVerticalHeaderHeight: CGFloat = 20
    
    public var startDate = Date()
    public var showDaysOut = true
    public var selectionStyle: PBSelectionStyle = .single
    
    private var calculatedWeekHeight: CGFloat = 100
    private let calendar: PBCalendar
    private var monthViews = [PBMonthView]()
    private let maxNumberOfWeek = 6
    private let numberDaysInWeek = 7
    private var weekHeight: CGFloat {
        switch scrollDirection {
        case .horizontal:
            return frame.height / CGFloat(maxNumberOfWeek)
        case .vertical:
            return frame.width / CGFloat(numberDaysInWeek)
        }
    }
    private var viewType: PBCalendarViewType = .month
    private var currentMonth: PBMonthView? {
        return getMonthView(with: contentOffset)
    }
    
    public init(frame: CGRect, calendar: PBCalendar) {
        self.calendar = calendar
        
        super.init(frame: frame)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        
        fatalError("init(coder:) has not been implemented")
    }
    
    // specify all properties before calling setup()
    public func setup() {
        delegate = self
        calendar.delegate = self
        directionSetup()
        calculateContentSize()
        setupMonths()
        scrollToStartDate()
    }
    
    public func nextMonth() {
        switch scrollDirection {
        case .horizontal:
            let x = contentOffset.x + frame.width
            guard x < contentSize.width else { return }
            
            setContentOffset(CGPoint(x: x, y: 0), animated: false)
            drawVisibleMonth(with: contentOffset)
        case .vertical: break
        }
    }
    
    public func previousMonth() {
        switch scrollDirection {
        case .horizontal:
            let x = contentOffset.x - frame.width
            guard x >= 0 else { return }
            
            setContentOffset(CGPoint(x: x, y: 0), animated: false)
            drawVisibleMonth(with: contentOffset)
        case .vertical: break
        }
    }
    
    public func selectDates(_ dates: [Date]) {
        calendar.deselectAll()
        calendar.selectDates(dates)
    }
    
    public func setAvailableDates(_ availability: DaysAvailability) {
        calendar.setDaysAvailability(availability)
    }
    
    public func setSupplementaries(_ data: [(Date, [PBDaySupplementary])]) {
        calendar.setSupplementaries(data)
    }
    
    public func changeViewType() {
        switch scrollDirection {
        case .horizontal:
            viewType = viewType == .month ? .week : .month
            calculateContentSize()
            drawMonths()
            scrollToStartDate()
        case .vertical: break
        }
    }
    
    // MARK: Private Methods.
    
    private func directionSetup() {
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        
        switch scrollDirection {
        case .horizontal:
            isPagingEnabled = true
        case .vertical: break
        }
    }
    
    private func calculateContentSize() {
        switch scrollDirection {
        case .horizontal:
            switch viewType {
            case .month:
                contentSize.width = frame.width * CGFloat(calendar.months.count)
            case .week:
                let weeksWidth = calendar.months.reduce(0) { sum, month -> CGFloat in
                    return sum + (CGFloat(month.weeks.count) * frame.width)
                }
                contentSize.width = weeksWidth
            }
        case .vertical:
            let monthsHeight: CGFloat = calendar.months.enumerated().reduce(0) { result, item in
                let inset: CGFloat = item.offset == calendar.months.count - 1  ? 0.0 : monthVerticalInset
                let height = CGFloat(item.element.numberOfWeeks) * weekHeight + inset + monthVerticalHeaderHeight
                return CGFloat(result) + height
            }
            contentSize.height = monthsHeight
        }
    }
    
    private func setupMonths() {
        monthViews = calendar.months.map {
            PBMonthView(month: $0, showDaysOut: showDaysOut, weekHeight: weekHeight, viewType: viewType)
        }
        
        monthViews.forEach { addSubview($0) }
        drawMonths()
    }
    
    private func drawMonths() {
        monthViews.forEach { $0.clean() }
        monthViews.enumerated().forEach { index, monthView in
            switch scrollDirection {
            case .horizontal:
                switch viewType {
                case .month:
                    let x = index == 0 ? 0 : monthViews[index - 1].frame.maxX
                    monthView.frame = CGRect(x: x, y: 0, width: self.frame.width, height: self.frame.height)
                case .week:
                    let x = index == 0 ? 0 : monthViews[index - 1].frame.maxX
                    let monthWidth = self.frame.width * CGFloat(monthView.numberOfWeeks)
                    monthView.frame = CGRect(x: x, y: 0, width: monthWidth, height: self.frame.height)
                }
            case .vertical:
                let y = index == 0 ? 0 : monthViews[index - 1].frame.maxY + monthVerticalInset
                let height = (CGFloat(monthView.numberOfWeeks) * weekHeight) + monthVerticalHeaderHeight
                monthView.frame = CGRect(x: 0, y: y, width: self.frame.width, height: height)
            }
        }
    }
    
    private func scrollToStartDate() {
        let startMonth = monthViews.first(where: { $0.month.dateInThisMonth(startDate) })
        var offset: CGPoint = startMonth?.frame.origin ?? .zero
        
        setContentOffset(offset, animated: false)
        drawVisibleMonth(with: contentOffset)
        
        if viewType == .week {
            let weekOffset = startMonth?.week(with: startDate)?.frame.origin.x ?? 0
            let inset = startMonth?.monthViewAppearanceDelegate?.leftInset?() ?? 0
            offset.x += weekOffset - inset
            setContentOffset(offset, animated: false)
        }
    }
    
    private func getMonthView(with offset: CGPoint) -> PBMonthView? {
        switch scrollDirection {
        case .horizontal:
            switch viewType {
            case .month:
                return monthViews.first(where: { $0.frame.midX >= offset.x })
            case .week:
                let visibleRect = CGRect(x: offset.x, y: offset.y, width: frame.width, height: frame.height)
                return monthViews.first(where: { $0.frame.intersects(visibleRect) })
            }
        case .vertical:
            return monthViews.first(where: { $0.frame.midY >= offset.y })
        }
    }
    
    private func drawVisibleMonth(with offset: CGPoint) {
        switch scrollDirection {
        case .horizontal:
            let first: ((offset: Int, element: PBMonthView)) -> Bool = { $0.element.frame.midX >= offset.x }
            guard let currentIndex = monthViews.enumerated().first(where: first)?.offset else { return }
            
            monthViews.enumerated().forEach { index, month in
                if index == currentIndex || index + 1 == currentIndex || index - 1 == currentIndex {
                    month.delegate = self
                    month.setupWeeksView(with: viewType)
                } else {
                    month.clean()
                }
            }
            
        case .vertical:
            let first: ((offset: Int, element: PBMonthView)) -> Bool = { $0.element.frame.minY >= offset.y }
            guard let currentIndex = monthViews.enumerated().first(where: first)?.offset else { return }
            
            monthViews.enumerated().forEach { index, month in
                if index >= currentIndex - 1 && index <= currentIndex + 1 {
                    month.delegate = self
                    month.setupWeeksView(with: viewType)
                } else {
                    month.clean()
                }
            }
        }
    }
    
}

public class PBMonthHeaderView: UIView {
    
    public var appearance = PBMonthHeaderViewAppearance() {
        didSet {
            formatter.dateFormat = appearance.dateFormat
            setupView()
        }
    }
    
    public weak var delegate: PBMonthHeaderViewDelegate?
    
    private lazy var formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = appearance.dateFormat
        return formatter
    }()
    
    private let monthLabel = UILabel()
    private let previousButton = UIButton()
    private let nextButton = UIButton()
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        setupView()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        setupView()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        let buttonWidth: CGFloat = 50.0
        monthLabel.frame = CGRect(x: 0, y: 0, width: appearance.monthTextWidth, height: frame.height)
        monthLabel.center.x = center.x
        previousButton.frame = CGRect(x: 0, y: 0, width: buttonWidth, height: frame.height)
        nextButton.frame = CGRect(x: frame.width - buttonWidth, y: 0, width: buttonWidth, height: frame.height)
    }
    
    private func setupView() {
        subviews.forEach{ $0.removeFromSuperview() }
        
        backgroundColor = .white
        monthLabel.font = appearance.monthFont
        monthLabel.textAlignment = .center
        monthLabel.textColor = appearance.monthTextColor
        
        previousButton.setImage(appearance.previousButtonImage, for: .normal)
        previousButton.addTarget(self, action: #selector(didTapPrevious(_:)), for: .touchUpInside)
        
        nextButton.setImage(appearance.nextButtonImage, for: .normal)
        nextButton.addTarget(self, action: #selector(didTapNext(_:)), for: .touchUpInside)
        
        addSubview(monthLabel)
        addSubview(previousButton)
        addSubview(nextButton)
        
        layoutSubviews()
    }
    
    @objc
    private func didTapNext(_ sender: UIButton) {
        delegate?.didTapNextMonth()
    }
    
    @objc
    private func didTapPrevious(_ sender: UIButton) {
        delegate?.didTapPreviousMonth()
    }
    
}

public class PBWeekDaysView: UIView {
    
    public var appearance = PBWeekDaysViewAppearance() {
        didSet {
            setupView()
        }
    }
    
    private let separatorView = UIView()
    private var dayLabels = [UILabel]()
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        setupView()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        setupView()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        let width = frame.width - (appearance.leftInset + appearance.rightInset)
        let dayWidth = width / CGFloat(dayLabels.count)
        
        dayLabels.enumerated().forEach { index, label in
            let x = index == 0 ? appearance.leftInset : dayLabels[index - 1].frame.maxX
            
            label.frame = CGRect(
                x: x,
                y: 0,
                width: dayWidth,
                height: self.frame.height
            )
        }
        
        let separatorHeight = 1 / UIScreen.main.scale
        let separatorY = frame.height - separatorHeight
        separatorView.frame = CGRect(
            x: appearance.leftInset,
            y: separatorY,
            width: width,
            height: separatorHeight
        )
    }
    
    private func setupView() {
        subviews.forEach { $0.removeFromSuperview() }
        dayLabels = []
        
        let names = getWeekdayNames()
        names.enumerated().forEach { index, name in
            let label = UILabel()
            label.text = name
            label.textAlignment = .center
            label.font = appearance.weekDayTextFont
            label.textColor = appearance.weekDayTextColor
            dayLabels.append(label)
            addSubview(label)
        }
        
        separatorView.backgroundColor = appearance.separatorBackgroundColor
        addSubview(separatorView)
        layoutSubviews()
    }
    
    private func getWeekdayNames() -> [String] {
        let symbols = appearance.symbolsType.names(from: appearance.calendar)
        
        if appearance.calendar.firstWeekday == 1 {
            return symbols
        } else {
            let allDaysWihoutFirst = Array(symbols[appearance.calendar.firstWeekday - 1..<symbols.count])
            return allDaysWihoutFirst + symbols[0..<appearance.calendar.firstWeekday - 1]
        }
    }
    
}

// MARK: General Class

class PBDay {
    
    let date: Date
    var stateChanged: ((PBDayState) -> Void)?
    var supplementariesDidUpdate: (() -> Void)?
    let calendar: Calendar
    
    var reverseSelectionState: PBDayState {
        return state == .available ? .selected : .available
    }
    
    var isSelected: Bool {
        return state == .selected
    }
    
    var isSelectable: Bool {
        return state == .selected || state == .available
    }
    
    var dayInMonth: Bool {
        return state != .out
    }
    
    var state: PBDayState {
        didSet {
            stateChanged?(state)
        }
    }
    
    var supplementaries = Set<PBDaySupplementary>() {
        didSet {
            supplementariesDidUpdate?()
        }
    }
    
    init(date: Date, state: PBDayState, calendar: Calendar) {
        self.date = date
        self.state = state
        self.calendar = calendar
    }
    
    func dateInDay(_ date: Date) -> Bool {
        return calendar.isDate(date, equalTo: self.date, toGranularity: .day)
    }
    
    func setSelectionState(_ state: PBDayState) {
        guard state == reverseSelectionState && isSelectable else { return }
        
        self.state = state
    }
    
    func setState(_ state: PBDayState) {
        self.state = state
    }
    
    func set(_ supplementaries: [PBDaySupplementary]) {
        self.supplementaries = Set(supplementaries)
    }
    
}
class PBDayView: UIView {
    
    var day: PBDay
    weak var delegate: PBDayViewDelegate?
    
    weak var dayViewAppearanceDelegate: PBDayViewAppearanceDelegate? {
        return (superview as? PBWeekView)?.dayViewAppearanceDelegate
    }
    
    private var dotStackView: UIStackView {
        let stack = UIStackView()
        stack.distribution = .fillEqually
        stack.axis = .horizontal
        stack.spacing = dotSpacing
        return stack
    }
    
    private let dotSpacing: CGFloat = 5
    private let dotSize: CGFloat = 5
    private var supplementaryViews = [UIView]()
    private let dateLabel = UILabel()
    
    init(day: PBDay) {
        self.day = day
        super.init(frame: .zero)
        
        self.day.stateChanged = { [weak self] state in
            self?.setState(state)
        }
        
        self.day.supplementariesDidUpdate = { [weak self] in
            self?.updateSupplementaryViews()
        }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapSelect))
        addGestureRecognizer(tapGesture)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupDay() {
        let shortestSide: CGFloat = (frame.width < frame.height ? frame.width : frame.height)
        let side: CGFloat = shortestSide * (dayViewAppearanceDelegate?.selectedArea?() ?? 0.8)
        
        dateLabel.font = dayViewAppearanceDelegate?.font?(for: day.state) ?? dateLabel.font
        dateLabel.text = PBFormatters.dayFormatter.string(from: day.date)
        dateLabel.textAlignment = .center
        dateLabel.frame = CGRect(
            x: 0,
            y: 0,
            width: side,
            height: side
        )
        dateLabel.center = CGPoint(x: frame.width / 2, y: frame.height / 2)
        
        setState(day.state)
        addSubview(dateLabel)
        updateSupplementaryViews()
    }
    
    @objc
    private func didTapSelect() {
        guard day.state != .out && day.state != .unavailable else { return }
        delegate?.dayStateChanged(day)
    }
    
    private func setState(_ state: PBDayState) {
        if dayViewAppearanceDelegate?.shape?() == .circle && state == .selected {
            dateLabel.clipsToBounds = true
            dateLabel.layer.cornerRadius = dateLabel.frame.height / 2
        }
        
        backgroundColor = dayViewAppearanceDelegate?.backgroundColor?(for: state) ?? backgroundColor
        layer.borderColor = dayViewAppearanceDelegate?.borderColor?(for: state).cgColor ?? layer.borderColor
        layer.borderWidth = dayViewAppearanceDelegate?.borderWidth?(for: state) ?? dateLabel.layer.borderWidth
        
        dateLabel.textColor = dayViewAppearanceDelegate?.textColor?(for: state) ?? dateLabel.textColor
        dateLabel.backgroundColor = dayViewAppearanceDelegate?.textBackgroundColor?(for: state) ?? dateLabel.backgroundColor
        
        updateSupplementaryViews()
    }
    
    private func updateSupplementaryViews() {
        removeAllSupplementaries()
        
        day.supplementaries.forEach { supplementary in
            switch supplementary {
            case .bottomDots(let colors):
                let stack = dotStackView
                
                colors.forEach { color in
                    let dotView = PBDotView(size: dotSize, color: color)
                    stack.addArrangedSubview(dotView)
                }
                let spaceOffset = CGFloat(colors.count - 1) * dotSpacing
                let stackWidth = CGFloat(colors.count) * dotSpacing + spaceOffset
                
                let verticalOffset = dayViewAppearanceDelegate?.dotBottomVerticalOffset?(for: day.state) ?? 2
                stack.frame = CGRect(x: 0, y: dateLabel.frame.maxY + verticalOffset, width: stackWidth, height: dotSize)
                stack.center.x = dateLabel.center.x
                addSubview(stack)
                supplementaryViews.append(stack)
            }
        }
    }
    
    private func removeAllSupplementaries() {
        supplementaryViews.forEach { $0.removeFromSuperview() }
        supplementaryViews = []
    }
    
}


class PBDotView: UIView {
    
    init(size: CGFloat, color: UIColor) {
        let frame = CGRect(x: 0, y: 0, width: size, height: size)
        super.init(frame: frame)
        
        layer.cornerRadius = frame.height / 2
        clipsToBounds = true
        backgroundColor = color
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

struct PBFormatters {
    
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL"
        return formatter
    }()
    
}
class PBMonth {
    
    var weeks = [PBWeek]()
    let lastMonthDay: Date
    let date: Date
    
    var isCurrent: Bool {
        return calendar.isDate(date, equalTo: Date(), toGranularity: .month)
    }
    
    var numberOfWeeks: Int {
        return weeks.count
    }
    
    var selectedDays = [PBDay]() {
        didSet {
            self.weeks = generateWeeks()
        }
    }
    
    private let calendar: Calendar
    
    init(month: Date, calendar: Calendar) {
        self.date = month
        self.calendar = calendar
        self.lastMonthDay = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: date)!
    }
    
    func days(for dates: [Date]) -> [PBDay] {
        return weeks.flatMap { $0.days(for: dates) }
    }
    
    func allDays() -> [PBDay] {
        return weeks.flatMap { $0.days }.filter { $0.dayInMonth }
    }
    
    func dateInThisMonth(_ date: Date) -> Bool {
        return calendar.isDate(date, equalTo: self.date, toGranularity: .month)
    }
    
    func deselectAll() {
        weeks.forEach { $0.deselectAll() }
    }
    
    func setDaySelectionState(_ day: PBDay, state: PBDayState) {
        weeks.first(where: { $0.dateInThisWeek(day.date) })?.setDaySelectionState(day, state: state)
    }
    
    func set(_ day: PBDay, supplementaries: [PBDaySupplementary]) {
        weeks.first(where: { $0.dateInThisWeek(day.date) })?.set(day, supplementaries: supplementaries)
    }
    
    private func generateWeeks() -> [PBWeek] {
        var weeks = [PBWeek]()
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        var weekDay = calendar.date(from: components)!
        
        repeat {
            var days = [PBDay]()
            for index in 0...6 {
                guard let dayInWeek = calendar.date(byAdding: .day, value: +index, to: weekDay) else { continue }
                let dayState = state(for: dayInWeek)
                let day = PBDay(date: dayInWeek, state: dayState, calendar: calendar)
                days.append(day)
            }
            let week = PBWeek(days: days, date: weekDay, calendar: calendar)
            weeks.append(week)
            weekDay = calendar.date(byAdding: .weekOfYear, value: 1, to: weekDay)!
        } while calendar.isDate(weekDay, equalTo: lastMonthDay, toGranularity: .month)
        
        return weeks
    }
    
    private func state(for date: Date) -> PBDayState {
        if !calendar.isDate(date, equalTo: lastMonthDay, toGranularity: .month) {
            return .out
        } else if selectedDays.contains(where: { calendar.isDate($0.date , inSameDayAs: date) }) {
            return .selected
        } else {
            return .available
        }
    }
    
}


public struct PBMonthHeaderViewAppearance {
    
    let monthFont: UIFont
    let monthTextColor: UIColor
    let monthTextWidth: CGFloat
    let previousButtonImage: UIImage
    let nextButtonImage: UIImage
    let dateFormat: String
    
    public init(
        monthFont: UIFont = UIFont.systemFont(ofSize: 21),
        monthTextColor: UIColor = UIColor.black,
        monthTextWidth: CGFloat = 150,
        previousButtonImage: UIImage = UIImage(),
        nextButtonImage: UIImage = UIImage(),
        dateFormat: String = "MMMM") {
        self.monthFont = monthFont
        self.monthTextColor = monthTextColor
        self.monthTextWidth = monthTextWidth
        self.previousButtonImage = previousButtonImage
        self.nextButtonImage = nextButtonImage
        self.dateFormat = dateFormat
    }
    
}







class PBMonthView: UIView {
    
    var numberOfWeeks: Int {
        return month.numberOfWeeks
    }
    
    var isDrawn: Bool {
        return !weekViews.isEmpty
    }
    
    var scrollDirection: PBCalendarScrollDirection {
        return (superview as? PBCalendarView)?.scrollDirection ?? .horizontal
    }
    
    var monthVerticalHeaderHeight: CGFloat {
        return (superview as? PBCalendarView)?.monthVerticalHeaderHeight ?? 0.0
    }
    
    var superviewWidth: CGFloat {
        return superview?.frame.width ?? 0
    }
    
    weak var monthViewAppearanceDelegate: PBMonthViewAppearanceDelegate? {
        return (superview as? PBCalendarView)?.monthViewAppearanceDelegate
    }
    
    weak var dayViewAppearanceDelegate: PBDayViewAppearanceDelegate? {
        return (superview as? PBCalendarView)?.dayViewAppearanceDelegate
    }
    
    weak var delegate: PBMonthViewDelegate?
    
    let month: PBMonth
    
    private let showDaysOut: Bool
    private var monthLabel: UILabel?
    private var weekViews = [PBWeekView]()
    private let weekHeight: CGFloat
    private var viewType: PBCalendarViewType
    
    init(month: PBMonth, showDaysOut: Bool, weekHeight: CGFloat, viewType: PBCalendarViewType) {
        self.month = month
        self.showDaysOut = showDaysOut
        self.weekHeight = weekHeight
        self.viewType = viewType
        
        super.init(frame: .zero)
        
        backgroundColor = .clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupWeeksView(with type: PBCalendarViewType) {
        guard isDrawn == false else { return }
        
        self.viewType = type
        
        if scrollDirection == .vertical {
            setupMonthLabel()
        }
        
        self.weekViews = []
        
        month.weeks.enumerated().forEach { index, week in
            let weekView = PBWeekView(week: week, showDaysOut: showDaysOut)
            weekView.delegate = self
            self.weekViews.append(weekView)
            self.addSubview(weekView)
        }
        
        draw()
    }
    
    func clean() {
        monthLabel = nil
        weekViews = []
        subviews.forEach { $0.removeFromSuperview() }
    }
    
    func week(with date: Date) -> PBWeekView? {
        return weekViews.first(where: { $0.contains(date: date) })
    }
    
    private func draw() {
        let leftInset = monthViewAppearanceDelegate?.leftInset?() ?? 0
        let rightInset = monthViewAppearanceDelegate?.rightInset?() ?? 0
        let initialOffsetY = self.monthLabel?.frame.maxY ?? 0
        let weekViewWidth = self.frame.width - (leftInset + rightInset)
        
        var x: CGFloat = leftInset
        var y: CGFloat = initialOffsetY
        
        weekViews.enumerated().forEach { index, week in
            switch viewType {
            case .month:
                week.frame = CGRect(
                    x: leftInset,
                    y: y,
                    width: weekViewWidth,
                    height: self.weekHeight
                )
                y = week.frame.maxY
                
            case .week:
                let width = self.superviewWidth - (leftInset + rightInset)
                
                week.frame = CGRect(
                    x: x,
                    y: initialOffsetY,
                    width: width,
                    height: self.weekHeight
                )
                x = week.frame.maxX + (leftInset + rightInset)
            }
            week.setupDays()
        }
    }
    
    private func setupMonthLabel() {
        let textColor = month.isCurrent ? monthViewAppearanceDelegate?.verticalCurrentMonthTitleColor?() :
            monthViewAppearanceDelegate?.verticalMonthTitleColor?()
        
        monthLabel = UILabel()
        monthLabel?.text = PBFormatters.monthFormatter.string(from: month.date)
        monthLabel?.textColor = textColor ?? monthLabel?.textColor
        monthLabel?.font = monthViewAppearanceDelegate?.verticalMonthTitleFont?() ?? monthLabel?.font
        monthLabel?.sizeToFit()
        monthLabel?.center.x = center.x
        addSubview(monthLabel ?? UIView())
    }
    
}



class PBWeek {
    
    var days: [PBDay]
    let date: Date
    
    private let calendar: Calendar
    
    init(days: [PBDay], date: Date, calendar: Calendar) {
        self.days = days
        self.date = date
        self.calendar = calendar
    }
    
    func days(for dates: [Date]) -> [PBDay] {
        return dates.flatMap { date in days.filter { $0.dateInDay(date) && $0.isSelectable }}
    }
    
    func dateInThisWeek(_ date: Date) -> Bool {
        return calendar.isDate(date, equalTo: self.date, toGranularity: .weekOfYear)
    }
    
    func deselectAll() {
        days.forEach { $0.setSelectionState(.available) }
    }
    
    func setDaySelectionState(_ day: PBDay, state: PBDayState)  {
        days.first(where: { $0.dateInDay(day.date) })?.setSelectionState(state)
    }
    
    func set(_ day: PBDay, supplementaries: [PBDaySupplementary]) {
        days.first(where: { $0.dateInDay(day.date) })?.set(supplementaries)
    }
    
}



public struct PBWeekDaysViewAppearance {
    
    let symbolsType: PBWeekDaysSymbolsType
    let weekDayTextColor: UIColor
    let weekDayTextFont: UIFont
    let leftInset: CGFloat
    let rightInset: CGFloat
    let separatorBackgroundColor: UIColor
    let calendar: Calendar
    
    public init(
        symbolsType: PBWeekDaysSymbolsType = .veryShort,
        weekDayTextColor: UIColor = .black,
        weekDayTextFont: UIFont = UIFont.systemFont(ofSize: 15),
        leftInset: CGFloat = 10.0,
        rightInset: CGFloat = 10.0,
        separatorBackgroundColor: UIColor = .lightGray,
        calendar: Calendar = Calendar.current) {
        self.symbolsType = symbolsType
        self.weekDayTextColor = weekDayTextColor
        self.weekDayTextFont = weekDayTextFont
        self.leftInset = leftInset
        self.rightInset = rightInset
        self.separatorBackgroundColor = separatorBackgroundColor
        self.calendar = calendar
    }
    
}




class PBWeekView: UIView {
    
    weak var dayViewAppearanceDelegate: PBDayViewAppearanceDelegate? {
        return (superview as? PBMonthView)?.dayViewAppearanceDelegate
    }
    weak var delegate: PBWeekViewDelegate?
    
    private let showDaysOut: Bool
    private lazy var dayWidth = self.frame.width / 7
    private let week: PBWeek
    private var dayViews = [PBDayView]()
    
    init(week: PBWeek, showDaysOut: Bool) {
        self.week = week
        self.showDaysOut = showDaysOut
        super.init(frame: .zero)
        
        backgroundColor = .clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupDays() {
        dayViews = []
        
        var x: CGFloat = 0
        week.days.enumerated().forEach { index, day in
            let dayView = PBDayView(day: day)
            dayView.frame = CGRect(x: x, y: 0, width: dayWidth, height: frame.height)
            x = dayView.frame.maxX
            dayView.delegate = self
            dayViews.append(dayView)
            
            if showDaysOut || (!showDaysOut && dayView.day.state != .out) {
                addSubview(dayView)
                dayView.setupDay()
            }
        }
    }
    
    func contains(date: Date) -> Bool {
        return week.dateInThisWeek(date)
    }
    
}

extension PBWeekView: PBDayViewDelegate {
    
    func dayStateChanged(_ day: PBDay) {
        delegate?.dayStateChanged(day, in: week)
    }
    
}

extension PBMonthView: PBWeekViewDelegate {
    
    func dayStateChanged(_ day: PBDay, in week: PBWeek) {
        delegate?.dayStateChanged(day, in: month)
    }
    
}

extension PBMonthHeaderView: PBCalendarMonthDelegate {
    
    public func monthDidChange(_ currentMonth: Date) {
        monthLabel.text = formatter.string(from: currentMonth)
    }
    
}

extension PBCalendarView: PBCalendarDelegate {
    
    func selectedDaysDidUpdate(_ days: [PBDay]) {
        let dates = days.map { $0.date }
        calendarDelegate?.selectedDates?(dates)
    }
    
}

extension PBCalendarView: PBMonthViewDelegate {
    
    func dayStateChanged(_ day: PBDay, in month: PBMonth) {
        switch selectionStyle {
        case .single:
            guard day.state == .available else { return }
            
            calendar.deselectAll()
            calendar.setDaySelectionState(day, state: .selected)
            calendarDelegate?.selectedDate?(day.date)
            
        case .multi:
            calendar.setDaySelectionState(day, state: day.reverseSelectionState)
        }
    }
    
}
extension PBCalendarView: UIScrollViewDelegate {
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let monthView = getMonthView(with: scrollView.contentOffset) else { return }
        
        monthDelegate?.monthDidChange(monthView.month.date)
        drawVisibleMonth(with: scrollView.contentOffset)
    }
    
}


