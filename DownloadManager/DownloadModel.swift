//
//  DownloadModel.swift
//  DownloadManager
//
//  Created by Artem Solovenko on 06/03/2019.
//

import Foundation


public enum TaskStatus {
    case unknown, gettingInfo, downloading, paused, failed
    
    public var description: String {
        switch self {
        case .gettingInfo:
            return "GettingInfo"
        case .downloading:
            return "Downloading"
        case .paused:
            return "Paused"
        case .failed:
            return "Failed"
        case .unknown:
            return "Unknown"
        }
    }
}


open class DownloadModel {
    
    open var fileName: String
    
    open var fileURL: String
    
    open var status: String = "" // TODO: assign default value
    
    open var file: (size: Float, unit: String)?
    open var downloadedFile: (size: Float, unit: String)?
    
    open var remainingTime: (hours: Int, minutes: Int, seconds: Int)?
    
    open var speed: (speed: Float, unit: String)?
    
    open var progress: Float = 0
    
    open var task: URLSessionDownloadTask?
    
    open var startTime: Date?
    
    fileprivate(set) open var destinationPath: String = ""
    
    private init() {
        self.fileName = ""
        self.fileURL = ""
    }
    
    fileprivate convenience init(fileName: String, fileURL: String) {
        self.init()
        
        self.fileName = fileName
        self.fileURL = fileURL
    }
    
    convenience init(fileName: String, fileURL: String, destinationPath: String) {
        self.init(fileName: fileName, fileURL: fileURL)
        
        self.destinationPath = destinationPath
    }
}
