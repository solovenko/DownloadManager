//
//  ASDownloadModel.swift
//  DownloadManager
//
//  Created by Artem Solovenko on 06/03/2019.
//

import Foundation


public enum ASTaskStatus {
    case preparation, downloading, paused, failed, unknown
    
    public var description: String {
        switch self {
        case .preparation:
            return "Preparation"
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


open class ASDownloadModel: Hashable {
    
    open var fileName: String
    open var fileURL: String
    
    open var status: ASTaskStatus
    
    open var file: (size: Double, unit: String)?
    open var downloadedFile: (size: Double, unit: String)?
    
    open var remainingTime: (hours: Int, minutes: Int, seconds: Int)?
    
    open var speed: (speed: Double, unit: String)?
    
    open var progress: Double = 0
    
    open var task: URLSessionDownloadTask?
    
    open var startTime: Date?
    
    fileprivate(set) open var destinationPath: String
    
    private init() {
        self.fileName = ""
        self.fileURL = ""
        self.status = .preparation
        self.destinationPath = ""
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
    
    public static func == (lhs: ASDownloadModel, rhs: ASDownloadModel) -> Bool {
        return lhs.fileName == rhs.fileName ||
            lhs.fileURL == rhs.fileURL ||
            lhs.status == rhs.status ||
            lhs.progress == rhs.progress ||
            lhs.destinationPath == rhs.destinationPath
    }
    
    public var hashValue: Int {
        return fileName.hashValue ^ fileURL.hashValue ^ status.hashValue ^ destinationPath.hashValue
    }
}
