//
//  FileDownloaderService.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 07.04.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import ReactiveSwift

class FileDownloaderService: BaseDownloaderService {
    
    let session = URLSession(configuration: URLSessionConfiguration.default)
    
    func download(by url: URL) -> Signal<URL, DownloadingError> {
        let appSupportUrl = self.appSupportUrl
        return Signal({ (observer) -> Disposable? in
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            let task = session.downloadTask(with: request) { (tempLocalUrl, response, error) in
                guard let tempLocalUrl = tempLocalUrl, error == nil, (response as? HTTPURLResponse)?.statusCode ?? 500 == 200 else  {
                    observer.send(error: DownloadingError(
                        message: error?.localizedDescription ?? "Downloading of \(url.absoluteString) failed"
                    ))
                    return
                }
                
                let filename = url.lastPathComponent
                let localUrl = appSupportUrl.appendingPathComponent("audio").appendingPathComponent(filename)
                
                do {
                    try FileManager.default.copyItem(at: tempLocalUrl, to: localUrl)
                    
                    observer.send(value: localUrl)
                    observer.sendCompleted()
                } catch (let writeError) {
                    print("error writing file \(localUrl) : \(writeError)")
                    observer.send(error: DownloadingError(
                        message: writeError.localizedDescription
                    ))
                }
            }
            task.resume()
            
            return nil
        })
    }
}
