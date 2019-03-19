//
//  ASUtility.swift
//  DownloadManager
//
//  Created by Artem Solovenko on 11/03/2019.
//

import Foundation


enum ASUtility {
    
    private static let kiloByte = 1024.0
    private static let megaByte = 1024.0 * 1024.0
    private static let gigaByte = 1024.0 * 1024.0 * 1024.0
    
    static let baseFilePath = NSHomeDirectory().appending("/Documents")
    
    static func calculateFileSizeInUnit(_ contentLength: Int64) -> Double {
        let dataLength = Double(contentLength)
        
        if dataLength >= gigaByte {
            return dataLength / gigaByte
        } else if dataLength >= megaByte {
            return dataLength / megaByte
        } else if dataLength >= kiloByte {
            return dataLength / kiloByte
        } else {
            return dataLength
        }
    }
    
    static func calculateUnit(_ contentLength: Int64) -> String {
        let contentLengthDouble = Double(contentLength)
        
        if contentLengthDouble >= gigaByte {
            return "GB"
        } else if contentLengthDouble >= megaByte {
            return "MB"
        } else if contentLengthDouble >= kiloByte {
            return "KB"
        } else {
            return "Bytes"
        }
    }
}
