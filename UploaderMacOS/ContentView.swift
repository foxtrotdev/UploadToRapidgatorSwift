//
//  ContentView.swift
//  UploaderMacOS
//
//  Created by Michał on 29/12/2024.
//

import SwiftUI
import ZIPFoundation
import CommonCrypto

struct ContentView: View {
    @State private var cookie: String = ""
    @State private var title: String = ""
    
    @State private var dropCoverArea: String? = nil
    @State private var dropFilesArea: [String] = []
    
    @State private var coverUploadResult: String? = nil
    @State private var filesZipResult: String? = nil
    @State private var filesUploadResult: String? = nil
    @State private var postResult: String? = nil
    
    @State private var uploadStatus: String? = nil // New state to track the upload status
    
    private let credentials = CredentialsManager.shared
    
    enum ActionType {
        case uploadCover(String)
        case zipFiles([String])
        case uploadFile(String)
    }
    
    var body: some View {
        ScrollView {
            VStack {
                Button(action: resetData) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                }
                
                TextField("Cookie", text: $cookie)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("Title", text: $title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("Drop cover here")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .onDrop(of: ["public.file-url"], isTargeted: nil) { providers in
                        handleDrop(providers: providers, isCover: true)
                    }
                
                if let cover = dropCoverArea {
                    HStack {
                        Text("Cover File:")
                            .fontWeight(.bold)
                        Text(cover)
                            .lineLimit(1) // Ensure it's a single-line display
                            .truncationMode(.middle) // Truncate in the middle for long paths
                            .foregroundColor(.blue)
                            .textSelection(.enabled) // Allow users to copy the path
                    }
                    
                    if coverUploadResult == nil {
                        Button("Upload Cover") {
                            performAction(for: .uploadCover(cover)) { result in
                                switch result {
                                case .success(let url):
                                    self.coverUploadResult = url
                                case .failure(let error):
                                    print("Error uploading cover: \(error)")
                                }
                            }
                        }
                    } else if let result = coverUploadResult {
                        HStack {
                            Text("Cover Upload Result:")
                                .fontWeight(.bold)
                            Text(result)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Text("Drop files here")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .onDrop(of: ["public.file-url"], isTargeted: nil) { providers in
                        handleDrop(providers: providers, isCover: false)
                    }
                
                if !dropFilesArea.isEmpty {
                    List(dropFilesArea, id: \.self) { filePath in
                        Text(filePath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }                    .frame(height: 220) // Limit height to 5
                    
                    if filesZipResult == nil {
                        Button("Zip Files") {
                            performAction(for: .zipFiles(dropFilesArea)) { result in
                                switch result {
                                case .success(let path):
                                    self.filesZipResult = path
                                case .failure(let error):
                                    print("Error: \(error.localizedDescription)")
                                }
                            }
                        }
                    } else if let zipResult = filesZipResult {
                        HStack {
                            Text("Zipped File Path:")
                                .fontWeight(.bold)
                            Text(zipResult)
                                .foregroundColor(.green)
                                .textSelection(.enabled)
                        }
                    }
                    
                    if filesZipResult != nil && filesUploadResult == nil {
                        Button("Upload Zipped File") {
                            performAction(for: .uploadFile(filesZipResult!)) { result in
                                switch result {
                                case .success(let path):
                                    self.filesUploadResult = path
                                case .failure(let error):
                                    print("Error: \(error.localizedDescription)")
                                }
                            }
                        }
                    } else if let uploadResult = filesUploadResult {
                        HStack {
                            Text("Files Upload Result:")
                                .fontWeight(.bold)
                            Text(uploadResult)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                if coverUploadResult != nil && filesUploadResult != nil {
                    if postResult == nil {
                        Button("Post It") {
                            // TODO...
                        }
                    } else if let result = postResult {
                        HStack {
                            Text("Post Result:")
                                .fontWeight(.bold)
                            Text(result)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 700, maxHeight: .infinity, alignment: .top) // Align components to the top
        }
    }
    
    private func handleDrop(providers: [NSItemProvider], isCover: Bool) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, error) in
                    DispatchQueue.main.async {
                        if let data = urlData as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                            if isCover {
                                self.dropCoverArea = url.path
                            } else {
                                self.dropFilesArea.append(url.path)
                            }
                        }
                    }
                }
            }
        }
        return true
    }
    
    private func performAction(for uploadType: ActionType, completion: @escaping (Result<String, Error>) -> Void) {
        switch uploadType {
        case .uploadCover(let filePath):
            uploadImage(filePath: filePath, apiKey: credentials.apiKey) { result in
                DispatchQueue.main.async {
                    completion(result)
                }
            }
        case .zipFiles(let filePaths):
            zipFiles(filePaths: filePaths) { result in
                DispatchQueue.main.async {
                    completion(result)
                }
            }
            
        case .uploadFile(let filePath):
            completion(.success("Authenticating..."))
            authenticate(login: credentials.login, password: credentials.password) { authResult in
                switch authResult {
                case .success(let token):
                    completion(.success("Uploading..."))
                    uploadToRapidgator(filePath: filePath, token: token) { uploadResult in
                        DispatchQueue.main.async {
                            completion(uploadResult)
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    private func resetData() {
        title = ""
        dropCoverArea = nil
        dropFilesArea = []
        coverUploadResult = nil
        filesUploadResult = nil
        postResult = nil
    }
    
    func authenticate(login: String, password: String, completion: @escaping (Result<String, Error>) -> Void) {
        let url = URL(string: "https://rapidgator.net/api/v2/user/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "login": login,
            "password": password
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        
        NSLog("Fire: authenticate")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: -1, userInfo: nil)))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let data = json["response"] as? [String: Any],
                   let token = data["token"] as? String {
                    completion(.success(token))
                } else {
                    completion(.failure(NSError(domain: "ParseError", code: -1, userInfo: nil)))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    func uploadToRapidgator(filePath: String, token: String, completion: @escaping (Result<String, Error>) -> Void) {
        let url = URL(string: "https://rapidgator.net/api/v2/file/upload")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            completion(.failure(NSError(domain: "FileError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot read file"])))
            return
        }
        
        NSLog("filePath: %@", filePath)
        let fileName = URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
        NSLog("fileName: %@", fileName)
        let fileSize = fileData.count
        NSLog("fileSize: %d", fileSize)
        let fileHash = md5(data: fileData)
        NSLog("fileHash: %@", fileHash)
        
        var body = Data()
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"token\"\r\n\r\n\(token)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"name\"\r\n\r\n\(fileName)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"hash\"\r\n\r\n\(fileHash)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"size\"\r\n\r\n\(fileSize)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        NSLog("Fire: uploadToRapidagator")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: -1, userInfo: nil)))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let response = json["response"] as? [String: Any],
                   let upload = response["upload"] as? [String: Any],
                   let uploadId = upload["upload_id"] as? String {
                    NSLog("Response: " + response.description)
                    
                    completion(.success("Checking status..."))
                    DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                        checkUploadStatus(uploadId: uploadId, token: token, completion: completion)
                    }
                } else {
                    completion(.failure(NSError(domain: "ParseError", code: -1, userInfo: nil)))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    func checkUploadStatus(uploadId: String, token: String, completion: @escaping (Result<String, Error>) -> Void) {
        let url = URL(string: "https://rapidgator.net/api/v2/file/upload_info")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "upload_id": uploadId,
            "token": token
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        
        NSLog("Fire: checkUploadStatus")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: -1, userInfo: nil)))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let response = json["response"] as? [String: Any],
                   let upload = response["upload"] as? [String: Any],
                   let state = upload["state"] as? Int {
                    
                    NSLog("Response: " + response.description)
                    
                    if state == 2 {
                        if let file = upload["file"] as? [String: Any],
                           let url = file["url"] as? String {
                            completion(.success(url))
                        } else {
                            completion(.failure(NSError(domain: "NoDownloadURL", code: -1, userInfo: nil)))
                        }
                    } else {
                        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                            checkUploadStatus(uploadId: uploadId, token: token, completion: completion)
                        }
                    }
                } else {
                    completion(.failure(NSError(domain: "ParseError", code: -1, userInfo: nil)))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    private func md5(data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_MD5($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    func zipFiles(filePaths: [String], completion: @escaping (Result<String, Error>) -> Void) {
        guard !filePaths.isEmpty else {
            completion(.failure(NSError(domain: "NoFiles", code: -1, userInfo: [NSLocalizedDescriptionKey: "No files to zip."])))
            return
        }
        
        let fileManager = FileManager.default
        
        // Find the longest file name
        let longestFileName = filePaths
            .map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent }
            .max(by: { $0.count < $1.count }) ?? "archive"
        
        // Ensure the name ends with `.zip`
        let zipFileName = "\(longestFileName).zip"
        
        // Get the temporary directory
        let tempDirectory = fileManager.temporaryDirectory
        let archiveURL = tempDirectory.appendingPathComponent(zipFileName)
        
        do {
            // Remove any existing file with the same name
            if fileManager.fileExists(atPath: archiveURL.path) {
                try fileManager.removeItem(at: archiveURL)
            }
            
            guard let archive = Archive(url: archiveURL, accessMode: .create) else {
                throw NSError(domain: "ArchiveError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to create archive."])
            }
            
            for filePath in filePaths {
                let fileURL = URL(fileURLWithPath: filePath)
                guard fileManager.fileExists(atPath: filePath) else {
                    throw NSError(domain: "FileError", code: -1, userInfo: [NSLocalizedDescriptionKey: "File does not exist: \(filePath)"])
                }
                
                // Add the file to the archive
                try archive.addEntry(with: fileURL.lastPathComponent, fileURL: fileURL)
            }
            
            // Completion handler with the archive path
            completion(.success(archiveURL.path))
        } catch {
            completion(.failure(error))
        }
    }
    
    func uploadImage(filePath: String, apiKey: String, completion: @escaping (Result<String, Error>) -> Void) {
        let url = URL(string: "https://api.imgbb.com/1/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        guard let imageData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            completion(.failure(NSError(domain: "FileError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot read file"])))
            return
        }
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"key\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(apiKey)\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: -1, userInfo: nil)))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let data = json["data"] as? [String: Any],
                   let imageUrl = data["url"] as? String {
                    completion(.success(imageUrl))
                } else {
                    completion(.failure(NSError(domain: "ParseError", code: -1, userInfo: nil)))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
}

#Preview {
    ContentView()
        .frame(minWidth: 400, minHeight: 500)
}
