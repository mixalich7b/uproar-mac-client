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
        initializePythonContext()
    }
    
    private func copyResourcesToAppSupport() {
        let youtubeDlPath = Bundle.main.path(forResource: "youtube_dl", ofType: "zip")!
        if SSZipArchive.unzipFile(atPath: youtubeDlPath, toDestination: appSupportUrl.path) {
            print("Unzipped")
        }
        
        let downloaderPath = Bundle.main.path(forResource: "Downloader", ofType: "py")!
        let downloaderDestinationUrl = appSupportUrl.appendingPathComponent("Downloader.py")
        if fileManager.fileExists(atPath: downloaderDestinationUrl.path) {
            try! fileManager.removeItem(atPath: downloaderDestinationUrl.path)
        }
        try! fileManager.copyItem(atPath: downloaderPath, toPath: downloaderDestinationUrl.path)
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
        let downloaderUrl = appSupportUrl.appendingPathComponent("Downloader.py")
        var compilerFlags = pyCompilerFlags
        return Signal { (observer) -> Disposable? in
            downloaderQueue.async {
                let mainFile = fopen(downloaderUrl.path, "r")
                if PyRun_SimpleFileExFlags(mainFile, (downloaderUrl.path as NSString).lastPathComponent, 1, &compilerFlags) == 0 {
                    let videoUrlStub = self.appSupportUrl.appendingPathComponent("videos").appendingPathComponent("doAcaKGeQwI.mp4")
                    observer.send(value: videoUrlStub)
                }
            }
            return nil
        }
    }
}
