//
//  Date+earlylate.swift
//  
//
//  Created by Todd Bowden on 11/6/22.
//

import Foundation

extension Date {
    
    static func laterDate(_ date1: Date, _ date2: Date) -> Date {
        if date1 > date2 {
            return date1
        } else {
            return date2
        }
    }
    
    static func earlierDate(_ date1: Date, _ date2: Date) -> Date {
        if date1 < date2 {
            return date1
        } else {
            return date2
        }
    }
}
