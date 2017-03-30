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
    
    private let pyCompilerFlags = PyCompilerFlags()
    
    private lazy var appSupportUrl: URL = {
        self.fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("uproar-mac")
    }()
    
    private let downloaderQueue = DispatchQueue(label: "Downloader.py", qos: .background, attributes: .concurrent)
    
    init() {
        copyResourcesToAppSupport()
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
        Py_Initialize()
        
        let sysPath = PySys_GetObject(UnsafeMutablePointer(mutating: UnsafePointer("path".cString(using: .utf8))))
        let path = PyString_FromString(appSupportUrl.path)
        PyList_Insert(sysPath, 0, path)
        PyImport_ImportModule("youtube_dl")
        if PyErr_Occurred() != nil {
            PyErr_Print()
        }
    }
    
    func downloadVideo(by url: URL) -> Signal<URL, YoutubeLoadingError> {
        return Signal {[weak self] (observer) -> Disposable? in
            DispatchQueue.main.async {
                self?.initializePythonContext()
                
                let urlPath = url.absoluteString
                var urlBytes: UnsafeMutablePointer<Int8>? = urlPath.cString(using: .utf8).map { UnsafeMutablePointer(mutating: $0) }
                PySys_SetArgvEx(1, &urlBytes, 0)
                
                self?.downloaderQueue.async {
                    defer {
                        DispatchQueue.main.async {
                            Py_Finalize()
                        }
                    }
                    
                    let pModule = PyImport_ImportModule("Downloader")
                    let getFilenameFunc = PyObject_GetAttrString(pModule, "getFinalFilepath")
                    guard PyCallable_Check(getFilenameFunc) == 1 else {
                        observer.send(error: YoutubeLoadingError(message: "getFinalFilepath missed"))
                        return
                    }
                    
                    let filepathObject = PyObject_CallObject(getFilenameFunc, PyTuple_New(0))
                    guard let filepathCString = PyString_AsString(filepathObject) else {
                        observer.send(error: YoutubeLoadingError(message: "getFinalFilepath return nil"))
                        return
                    }
                    guard let filepath = String(cString: filepathCString, encoding: .utf8) else {
                        observer.send(error: YoutubeLoadingError(message: "getFinalFilepath return broken string"))
                        return
                    }
                    
                    observer.send(value: URL(fileURLWithPath: filepath))
                    observer.sendCompleted()
                }
            }
            
            return nil
        }
    }
}
