//
//  YoutubeLoaderService.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 28.03.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import ReactiveSwift
import Python
import SSZipArchive

class YoutubeLoaderService {
    
    private let fileManager = FileManager.default
    
    private lazy var appSupportUrl: URL = {
        self.fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("uproar-mac")
    }()
    
    private let downloaderQueue = DispatchQueue(label: "Downloader.py", qos: .background)
    
    init() {
        copyResourcesToAppSupport()
        initializePythonContext()
    }
    
    private func copyResourcesToAppSupport() {
        let youtubeDlPath = Bundle.main.path(forResource: "youtube_dl", ofType: "zip")!
        if SSZipArchive.unzipFile(atPath: youtubeDlPath, toDestination: appSupportUrl.path) {
            print("Unzipped")
        }
        
        let downloaderScriptPath = Bundle.main.path(forResource: "Downloader", ofType: "py")!
        let downloaderScriptDestinationUrl = appSupportUrl.appendingPathComponent("Downloader.py")
        if fileManager.fileExists(atPath: downloaderScriptDestinationUrl.path) {
            try! fileManager.removeItem(atPath: downloaderScriptDestinationUrl.path)
        }
        try! fileManager.copyItem(atPath: downloaderScriptPath, toPath: downloaderScriptDestinationUrl.path)
    }
    
    private func initializePythonContext() {
        let appSupportPath = self.appSupportUrl.path
        downloaderQueue.async {
            Py_Initialize()
            
            let sysPath = PySys_GetObject(UnsafeMutablePointer(mutating: UnsafePointer("path".cString(using: .utf8))))
            let path = PyString_FromString(appSupportPath)
            PyList_Insert(sysPath, 0, path)
        }
    }
    
    func downloadVideo(by url: URL) -> Signal<URL, YoutubeLoadingError> {
        return Signal {[weak self] (observer) -> Disposable? in
            self?.downloaderQueue.async {
                let downloaderModule = PyImport_ImportModule("Downloader")
                if PyErr_Occurred() != nil {
                    PyErr_Print()
                }
                
                let downloadFunc = PyObject_GetAttrString(downloaderModule, "download")
                guard PyCallable_Check(downloadFunc) == 1 else {
                    observer.send(error: YoutubeLoadingError(message: "download func missed"))
                    return
                }
                let args = PyTuple_New(1)
                let arg = PyString_FromString(url.absoluteString)
                guard PyTuple_SetItem(args, 0, arg) == 0 else {
                    observer.send(error: YoutubeLoadingError(message: "failed to build download args"))
                    return
                }
                guard PyTuple_Size(args) == 1 else {
                    observer.send(error: YoutubeLoadingError(message: "failed to build download args"))
                    return
                }
                PyObject_CallObject(downloadFunc, args)
                
                let pollFinalFilepathFunc = PyObject_GetAttrString(downloaderModule, "pollFinalFilepath")
                guard PyCallable_Check(pollFinalFilepathFunc) == 1 else {
                    observer.send(error: YoutubeLoadingError(message: "pollFinalFilepath func missed"))
                    return
                }
                let filepathObject = PyObject_CallObject(pollFinalFilepathFunc, PyTuple_New(0))
                
                guard let filepathCString = PyString_AsString(filepathObject) else {
                    observer.send(error: YoutubeLoadingError(message: "pollFinalFilepath return nil"))
                    return
                }
                guard let filepath = String(cString: filepathCString, encoding: .utf8) else {
                    observer.send(error: YoutubeLoadingError(message: "pollFinalFilepath return broken string"))
                    return
                }
                
                observer.send(value: URL(fileURLWithPath: filepath))
                observer.sendCompleted()
            }
            return nil
        }.observe(on: UIScheduler())
    }
    
    deinit {
        Py_Finalize()
    }
}
