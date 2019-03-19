//
//  ASDownloadManager.swift
//  DownloadManager
//
//  Created by Artem Solovenko on 11/03/2019.
//

import Foundation


struct ASDownloadTaskComponents {
    
    private enum TaskComponents {
        static let fileNameIndex = 0
        static let fileURLIndex = 1
        static let fileDestinationIndex = 2
    }
    
    let fileName: String
    let fileURL: String
    let destinationPath: String
    
    init(fileName: String, fileURL: String, destinationPath: String) {
        self.fileName = fileName
        self.fileURL = fileURL
        self.destinationPath = destinationPath
    }
    
    init(_ downloadTask: URLSessionDownloadTask) {
        let taskDescComponents = downloadTask.taskDescription?.components(separatedBy: ",") ?? []

        fileName = taskDescComponents[TaskComponents.fileNameIndex]
        fileURL = taskDescComponents[TaskComponents.fileURLIndex]
        destinationPath = taskDescComponents[TaskComponents.fileDestinationIndex]
    }
    
    func makeDescription() -> String {
        return [fileName, fileURL, destinationPath].joined(separator: ",")
    }
    
    func buildModel() -> ASDownloadModel {
        return ASDownloadModel(fileName: fileName, fileURL: fileURL, destinationPath: destinationPath)
    }
}


protocol DownloadManagerDelegate: class {
    
    
    /* REQUIRED */

    
    /// A delegate method called each time whenever any download task's progress is updated
    ///
    /// - Parameters:
    ///   - downloadModel: download model
    ///   - index: index of download
    func downloadRequestDidUpdateProgress(_ downloadModel: ASDownloadModel, index: Int)
    
    /// A delegate method called each time whenever any download task is failed due to any reason
    ///
    /// - Parameters:
    ///   - error: error
    ///   - downloadModel: download model
    ///   - index: index of download
    func downloadRequestDidFailedWithError(_ error: NSError, downloadModel: ASDownloadModel, index: Int)
    
    /// A delegate method called when interrupted tasks are repopulated
    ///
    /// - Parameter downloadModel: download model
    func downloadRequestDidPopulatedInterruptedTasks(_ downloadModel: [ASDownloadModel])
    
    
    /* OPTIONAL */

    
    /// A delegate method called each time whenever new download task is start downloading
    ///
    /// - Parameters:
    ///   - downloadModel: download model
    ///   - index: index of download
    func downloadRequestStarted(_ downloadModel: ASDownloadModel, index: Int)
    
    /// A delegate method called each time whenever any download task is finished successfully
    ///
    /// - Parameters:
    ///   - downloadModel: download model
    ///   - index: index of download
    func downloadRequestFinished(_ downloadModel: ASDownloadModel, index: Int)
    
    /// A delegate method called each time whenever any download task is cancelled by the user
    ///
    /// - Parameters:
    ///   - downloadModel: download model
    ///   - index: index of download
    func downloadRequestCanceled(_ downloadModel: ASDownloadModel, index: Int)
    
    /// A delegate method called each time whenever running download task is paused.
    /// If task is already paused the action will be ignored.
    ///
    /// - Parameters:
    ///   - downloadModel: download model
    ///   - index: index of download
    func downloadRequestDidPaused(_ downloadModel: ASDownloadModel, index: Int)

    /// A delegate method called each time whenever any download task is resumed.
    /// If task is already downloading the action will be ignored.
    ///
    /// - Parameters:
    ///   - downloadModel: download model
    ///   - index: index of download
    func downloadRequestDidResumed(_ downloadModel: ASDownloadModel, index: Int)
    
    /// A delegate method called each time whenever specified destination does not exists.
    /// It will be called on the session queue. It provides the opportunity to handle error appropriately.
    ///
    /// - Parameters:
    ///   - downloadModel: download model
    ///   - index: index of download
    ///   - location: URL of destination location
    func downloadRequestDestinationDoestNotExists(_ downloadModel: ASDownloadModel, index: Int, location: URL)
}

extension DownloadManagerDelegate {
    func downloadRequestStarted(_ downloadModel: ASDownloadModel, index: Int) { }
    
    func downloadRequestFinished(_ downloadModel: ASDownloadModel, index: Int) { }
    
    func downloadRequestCanceled(_ downloadModel: ASDownloadModel, index: Int) { }
    
    func downloadRequestDidPaused(_ downloadModel: ASDownloadModel, index: Int) { }
    
    func downloadRequestDidResumed(_ downloadModel: ASDownloadModel, index: Int) { }
    
    func downloadRequestDestinationDoestNotExists(_ downloadModel: ASDownloadModel, index: Int, location: URL) { }
}

open class DownloadManager: NSObject {
    
    private var sessionManager: URLSession!
    
    /// Background session completion handler
    private var backgroundSessionCompletionHandler: (() -> Void)?

    private weak var delegate: DownloadManagerDelegate?
    
    /// Current downloadings
    open var downloadings: [ASDownloadModel]
    
    
    open var uniqueDownloadings: Set<ASDownloadModel>
    
    
    // MARK: - Init
    
    init(session sessionIdentifier: String,
         delegate: DownloadManagerDelegate,
         sessionConfiguration: URLSessionConfiguration? = nil,
         completion: (() -> Void)? = nil) {
        
        self.downloadings = []
        self.uniqueDownloadings = []
        self.delegate = delegate
        self.backgroundSessionCompletionHandler = completion
        super.init()
        
        self.sessionManager = backgroundSession(identifier: sessionIdentifier)
    }
    
    class func defaultSessionConfiguration(identifier: String) -> URLSessionConfiguration {
        return URLSessionConfiguration.background(withIdentifier: identifier)
    }
    
    private func backgroundSession(identifier: String, configuration: URLSessionConfiguration? = nil) -> URLSession {
        let sessionConfiguration = configuration ?? DownloadManager.defaultSessionConfiguration(identifier: identifier)
        
        assert(identifier == sessionConfiguration.identifier, "Configuration identifiers do not match")
        
        return URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: nil)
    }
    
}

extension DownloadManager {
    
    private func downloadTasks() -> [URLSessionDownloadTask] {
        var tasks: [URLSessionDownloadTask] = []
        
        let semaphore = DispatchSemaphore(value: 0)
        
        sessionManager.getTasksWithCompletionHandler { (_, _, downloadTasks) -> Void in
            tasks = downloadTasks
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        
        debugPrint("DownloadManager: pending tasks \(tasks)")
        
        return tasks
    }
    
    private func populateOtherDownloadTasks() {
        let downloadTasks = self.downloadTasks()
        
        for downloadTask in downloadTasks {
            let downloadModel = ASDownloadTaskComponents(downloadTask).buildModel()
            downloadModel.task = downloadTask
            downloadModel.startTime = Date()
            
            switch downloadTask.state {
            case .running:
                downloadModel.status = .downloading
                downloadings.append(downloadModel)
            case .suspended:
                downloadModel.status = .paused
                downloadings.append(downloadModel)
            default:
                downloadModel.status = .failed
            }
        }
    }
    
    private func isValid(resumeData: Data?) -> Bool {
        guard let resumeData = resumeData, !resumeData.isEmpty else { return false }
        
        do {
            let resumeDictionary = try PropertyListSerialization.propertyList(from: resumeData,
                                                                              options: PropertyListSerialization.MutabilityOptions(),
                                                                              format: nil) as? NSDictionary
            
            let localFilePath: String
            
            if let filePath = resumeDictionary?["NSURLSessionResumeInfoLocalPath"] as? String, !filePath.isEmpty {
                localFilePath = filePath
            } else {
                localFilePath = NSTemporaryDirectory() + (resumeDictionary?["NSURLSessionResumeInfoTempFileName"] as? String ?? "")
            }
            
            debugPrint("Resume data file exists: \(FileManager.default.fileExists(atPath: localFilePath))")
            
            return FileManager.default.fileExists(atPath: localFilePath)
        } catch {
            debugPrint("Resume data is nil: \(error)")
            return false
        }
        
    }

}

extension DownloadManager {
    
    func addDownloadTask(fileName: String, request: URLRequest, destinationPath: String = "") {
        
        guard let url = request.url else { return }
        
        let fileURL = url.absoluteString
        
        let downloadTask = sessionManager.downloadTask(with: request)
        downloadTask.taskDescription = [fileName, fileURL, destinationPath].joined(separator: ",")
        downloadTask.resume()
        
        debugPrint("Session manager: \(String(describing: sessionManager)) \nURL: \(String(describing: url)) \nRequest: \(String(describing: request))")
        
        let downloadModel = ASDownloadModel(fileName: fileName, fileURL: fileURL, destinationPath: destinationPath)
        downloadModel.startTime = Date()
        downloadModel.status = .downloading
        downloadModel.task = downloadTask
        
        downloadings.append(downloadModel)
        delegate?.downloadRequestStarted(downloadModel, index: downloadings.count - 1)
    }
    
    func addDownloadTask(fileName: String, fileURL: String, destinationPath: String = "") {
        let request = URLRequest(url: URL(string: fileURL)!)
        addDownloadTask(fileName: fileName, request: request, destinationPath: destinationPath)
    }
    
    func pauseDownloadTaskAtIndex(_ index: Int) {
        
        let downloadModel = downloadings[index]
        
        guard downloadModel.status != .paused else { return }
        
        let downloadTask = downloadModel.task
        downloadTask?.suspend()
        downloadModel.status = .paused
        downloadModel.startTime = Date()
        
        downloadings[index] = downloadModel
        
        delegate?.downloadRequestDidPaused(downloadModel, index: index)
    }
    
    func resumeDownloadTaskAtIndex(_ index: Int) {
        
        let downloadModel = downloadings[index]
        
        guard downloadModel.status != .downloading else { return }
        
        let downloadTask = downloadModel.task
        downloadTask?.resume()
        downloadModel.status = .downloading
        
        downloadings[index] = downloadModel
        
        delegate?.downloadRequestDidResumed(downloadModel, index: index)
    }
    
    func retryDownloadTaskAtIndex(_ index: Int) {
        let downloadModel = downloadings[index]
        
        guard downloadModel.status != .downloading else { return }
        
        let downloadTask = downloadModel.task
        
        downloadTask?.resume()
        downloadModel.status = .downloading
        downloadModel.startTime = Date()
        downloadModel.task = downloadTask
        
        downloadings[index] = downloadModel
    }
    
    func cancelTaskAtIndex(_ index: Int) {
        let downloadTask = downloadings[index].task
        downloadTask?.cancel()
    }

}


// MARK: - URLSessionDelegate

extension DownloadManager: URLSessionDownloadDelegate {
    
    public func urlSession(_ session: URLSession,
                           downloadTask: URLSessionDownloadTask,
                           didWriteData bytesWritten: Int64,
                           totalBytesWritten: Int64,
                           totalBytesExpectedToWrite: Int64) {
        
        for (index, downloadModel) in self.downloadings.enumerated() {
            if downloadTask.isEqual(downloadModel.task) {
                DispatchQueue.main.async {
                    let receivedBytesCount = Double(downloadTask.countOfBytesReceived)
                    let totalBytesCount = Double(downloadTask.countOfBytesExpectedToReceive)
                    let progress = receivedBytesCount / totalBytesCount
                    
                    let taskStartedDate = downloadModel.startTime ?? Date()
                    let timeInterval = taskStartedDate.timeIntervalSinceNow
                    let downloadTime = -1 * timeInterval
                    
                    let speed = Double(totalBytesWritten) / downloadTime
                    
                    let remainingContentLength = totalBytesExpectedToWrite - totalBytesWritten
                    
                    let remainingTime = remainingContentLength / Int64(speed)
                    let hours = Int(remainingTime / 3600)
                    let minutes = (Int(remainingTime) - hours * 3600) / 60
                    let seconds = Int(remainingTime) - hours * 3600 - minutes * 60
                    
                    let totalFileSize = ASUtility.calculateFileSizeInUnit(totalBytesExpectedToWrite)
                    let totalFileSizeUnit = ASUtility.calculateUnit(totalBytesExpectedToWrite)
                    
                    let downloadedFileSize = ASUtility.calculateFileSizeInUnit(totalBytesWritten)
                    let downloadedSizeUnit = ASUtility.calculateUnit(totalBytesWritten)
                    
                    let speedSize = ASUtility.calculateFileSizeInUnit(Int64(speed))
                    let speedUnit = ASUtility.calculateUnit(Int64(speed))
                    
                    downloadModel.remainingTime = (hours, minutes, seconds)
                    downloadModel.file = (totalFileSize, totalFileSizeUnit)
                    downloadModel.downloadedFile = (downloadedFileSize, downloadedSizeUnit)
                    downloadModel.speed = (speedSize, speedUnit)
                    downloadModel.progress = progress
                    
                    if self.downloadings.contains(downloadModel), let objectIndex = self.downloadings.index(of: downloadModel) {
                        self.downloadings[objectIndex] = downloadModel
                    }
                    
                    self.delegate?.downloadRequestDidUpdateProgress(downloadModel, index: index)
                }
            }
        }
        
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        for (index, downloadModel) in downloadings.enumerated() {
            if downloadTask.isEqual(downloadModel.task) {
                let fileName = downloadModel.fileName
                let basePath = downloadModel.destinationPath.isEmpty ? ASUtility.baseFilePath : downloadModel.destinationPath
                let destinationPath = basePath.appending("/" + fileName)
                
                if FileManager.default.fileExists(atPath: basePath) {
                    let fileURL = URL(fileURLWithPath: destinationPath)
                    
                    debugPrint("Directory path: \(destinationPath)")
                    
                    do {
                        try FileManager.default.moveItem(at: location, to: fileURL)
                    } catch let error as NSError {
                        debugPrint("Error while moving downloaded file to destination path: \(error)")
                        
                        DispatchQueue.main.async {
                            self.delegate?.downloadRequestDidFailedWithError(error, downloadModel: downloadModel, index: index)
                        }
                    }
                } else {
                    // TODO: needs to handle case when destination path does not exist
                    
                    self.delegate?.downloadRequestDestinationDoestNotExists(downloadModel, index: index, location: location)
                }
                
                break
            }
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        debugPrint("Task ID: \(task.taskIdentifier)")
        
        DispatchQueue.main.async {
            let err = error as NSError?
            
            let cancelledReasonKey = (err?.userInfo[NSURLErrorBackgroundTaskCancelledReasonKey] as? NSNumber)?.intValue
            
            let reasons = [NSURLErrorCancelledReasonUserForceQuitApplication,
                           NSURLErrorCancelledReasonBackgroundUpdatesDisabled]
            
            if let cancelledReasonKey = cancelledReasonKey, reasons.contains(cancelledReasonKey) {
                
                let downloadTask = task as! URLSessionDownloadTask

                let downloadModel = ASDownloadTaskComponents(downloadTask).buildModel()
                downloadModel.status = .failed
                downloadModel.task = downloadTask
                
                let resumeData = err?.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
                var newTask = downloadTask
                
                if self.isValid(resumeData: resumeData) {
                    newTask = self.sessionManager.downloadTask(withResumeData: resumeData!)
                } else {
                    newTask = self.sessionManager.downloadTask(with: URL(string: downloadModel.fileURL)!)
                }
                
                newTask.taskDescription = downloadTask.taskDescription
                downloadModel.task = newTask
                
                self.downloadings.append(downloadModel)
                
                self.delegate?.downloadRequestDidPopulatedInterruptedTasks(self.downloadings)
            } else {
                
                for (index, object) in self.downloadings.enumerated() {
                    
                    let downloadModel = object
                    
                    if task.isEqual(downloadModel.task) {
                        if err?.code == NSURLErrorCancelled || err == nil {
                            
                            self.downloadings.remove(at: index)
                            
                            if err == nil {
                                self.delegate?.downloadRequestFinished(downloadModel, index: index)
                            } else {
                                self.delegate?.downloadRequestCanceled(downloadModel, index: index)
                            }
                        } else {
                            
                            let resumeData = err?.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
                            
                            var newTask = task
                            
                            if self.isValid(resumeData: resumeData) {
                                newTask = self.sessionManager.downloadTask(withResumeData: resumeData!)
                            } else {
                                newTask = self.sessionManager.downloadTask(with: URL(string: downloadModel.fileURL)!)
                            }
                            
                            newTask.taskDescription = task.taskDescription
                            downloadModel.status = .failed
                            downloadModel.task = newTask as? URLSessionDownloadTask
                            
                            self.downloadings[index] = downloadModel
                            
                            if let error = err {
                                self.delegate?.downloadRequestDidFailedWithError(error, downloadModel: downloadModel, index: index)
                            } else {
                                let error = NSError(domain: "ASDownloadManagerDomain",
                                                    code: 1000,
                                                    userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred"])
                                self.delegate?.downloadRequestDidFailedWithError(error, downloadModel: downloadModel, index: index)
                            }
                        }
                        break
                    }
                }
            }
        }
    }
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        if let backgroundCompletion = self.backgroundSessionCompletionHandler {
            DispatchQueue.main.async {
                backgroundCompletion()
            }
        }
        
        debugPrint("All tasks are finished")
    }
}
