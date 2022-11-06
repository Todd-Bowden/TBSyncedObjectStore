//
//  String+remove.swift
//  
//
//  Created by Todd Bowden on 11/5/22.
//

import Foundation

extension String {
    
    func remove(_ r: String) -> String {
        self.replacingOccurrences(of: r, with: "")
    }
    
}
