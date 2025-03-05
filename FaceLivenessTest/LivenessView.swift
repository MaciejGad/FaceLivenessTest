import SwiftUI
import FaceLiveness
import UIKit

struct LivenessView: View {
    @EnvironmentObject var viewModel: LivenessViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                Text("Face Liveness Detection")
                    .font(.largeTitle)
                HStack {
                    Text("Hostname:")
                    TextField("Hostname", text: $viewModel.apiWorker.hostname)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .padding()
                        .border(.gray, width: 1)
                }
                HStack {
                    Text("Username:")
                    TextField("Username", text: $viewModel.apiWorker.username)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .padding()
                        .border(.gray, width: 1)
                }
                HStack {
                    Text("Password:")
                    SecureField("Password", text: $viewModel.apiWorker.password)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                        .keyboardType(.default)
                        .textContentType(.password)
                        .padding()
                        .border(.gray, width: 1)
                }
                
                if let sessionID = viewModel.sessionID {
                    Text("Session ID: \(sessionID)").font(.footnote)
                }
                if let localCheckOutput = viewModel.localCheckOutput {
                    Text("Local result: \(localCheckOutput)").font(.footnote)
                }
                
                Button("Start Liveness detection") {
                    viewModel.onFetchSession()
                }
                .disabled(viewModel.loading)
                .buttonStyle(.borderedProminent)
                if viewModel.sessionID != nil && viewModel.livenessResult == nil {
                    Button("Check result") {
                        viewModel.onFetchResults()
                    }
                    .disabled(viewModel.loading)
                    .buttonStyle(.bordered)
                }
                if viewModel.loading {
                    ProgressView() {
                        Text("Loading...")
                    }
                }
                if let livenessResult = viewModel.livenessResult {
                    Text(String(format: "Confidence: %.1f", livenessResult.confidence))
                    Text("Status: \(livenessResult.status)")
                        .foregroundColor(
                            livenessResult.status == .success ? .green : .red
                        )
                    if livenessResult.status == .success {
                        Button("See Details") {
                            viewModel.apiWorker.openDetails(for: livenessResult.sessionID)
                        }
                    }
                }
                Spacer()
                ScrollView {
                    Text(viewModel.debug)
                        .font(.caption)
                        .padding()
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .fullScreenCover(isPresented: $viewModel.showLiveness) {
                if let sessionID = viewModel.sessionID {
                    FaceLivenessDetectorView(sessionID: sessionID, region: "eu-west-1", isPresented: $viewModel.showLiveness) { result in
                        switch result {
                        case .success:
                            viewModel.localCheckOutput = "Verification completed successfully ✅"
                        case .failure(let error):
                            viewModel.localCheckOutput = "Error: \(error.localizedDescription) ❌"
                        }
                    }
                }
            }
        }
    }
}
