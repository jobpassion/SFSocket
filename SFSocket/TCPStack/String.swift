//
//  String.swift
//  Surf
//
//  Created by yarshure on 2016/8/10.
//  Copyright © 2016年 yarshure. All rights reserved.
//

import Foundation

extension String{
    func delLastN(_ n:Int) ->String{
        
        let i = self.index(self.endIndex, offsetBy: 0 - n)
        let d = self.to(index: i)
        return d
        
    }
}
