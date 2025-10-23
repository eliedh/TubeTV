//
//  SettingsView.swift
//  TubeTV
//
//  Created by Copilot on 22.10.25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var serverURL: String
    @State private var apiToken: String
    @State private var isTestingConnection = false
    @State private var testResult: TestResult?
    @Environment(\.dismiss) private var dismiss
    
    init(settings: AppSettings) {
        self.settings = settings
        _serverURL = State(initialValue: settings.serverURL)
        _apiToken = State(initialValue: settings.apiToken)
    }
    
    private enum TestResult {
        case success(String) // version
        case failure(String) // error message
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Server Configuration").font(.headline)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Server URL")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("http://192.168.1.100:8000", text: $serverURL)
                            .textContentType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Token")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("Your API token", text: $apiToken)
                            .textContentType(.password)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                
                Section {
                    Button(action: testConnection) {
                        HStack {
                            if isTestingConnection {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("Testing Connection...")
                            } else {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text("Test Connection")
                            }
                        }
                    }
                    .disabled(serverURL.isEmpty || apiToken.isEmpty || isTestingConnection)
                    
                    if let result = testResult {
                        switch result {
                        case .success(let version):
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                VStack(alignment: .leading) {
                                    Text("Connection Successful")
                                        .foregroundColor(.green)
                                    Text("TubeArchivist v\(version)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        case .failure(let error):
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                VStack(alignment: .leading) {
                                    Text("Connection Failed")
                                        .foregroundColor(.red)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: saveSettings) {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Save Settings")
                        }
                    }
                    .disabled(serverURL.isEmpty || apiToken.isEmpty)
                    
                    if settings.isConfigured {
                        Button(action: {
                            settings.clearSettings()
                            serverURL = ""
                            apiToken = ""
                            testResult = nil
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Clear Settings")
                            }
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        if settings.isConfigured {
                            dismiss()
                        }
                    }
                    .disabled(!settings.isConfigured)
                }
            }
        }
        #if os(iOS)
        .navigationViewStyle(StackNavigationViewStyle())
        #endif
    }
    
    // MARK: - Actions
    
    private func testConnection() {
        isTestingConnection = true
        testResult = nil
        
        let trimmedURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let url = URL(string: "\(trimmedURL)/api/ping/") else {
            testResult = .failure("Invalid server URL")
            isTestingConnection = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Token \(trimmedToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isTestingConnection = false
                
                if let error = error {
                    testResult = .failure(error.localizedDescription)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    testResult = .failure("Invalid response from server")
                    return
                }
                
                guard httpResponse.statusCode == 200 else {
                    testResult = .failure("HTTP \(httpResponse.statusCode)")
                    return
                }
                
                guard let data = data else {
                    testResult = .failure("No data received")
                    return
                }
                
                do {
                    let pingResponse = try JSONDecoder().decode(PingResponse.self, from: data)
                    if pingResponse.isValid {
                        testResult = .success(pingResponse.version)
                    } else {
                        testResult = .failure("Invalid response: expected 'pong'")
                    }
                } catch {
                    testResult = .failure("Failed to decode response: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    private func saveSettings() {
        settings.saveSettings(serverURL: serverURL, apiToken: apiToken)
        if settings.isConfigured {
            dismiss()
        }
    }
}
