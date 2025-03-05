import Amplify
import AWSCognitoAuthPlugin
import SwiftUI

@main
struct FaceLivenessTestApp: App {
    
    init() {
            do {
                try Amplify.add(plugin: AWSCognitoAuthPlugin())
                try Amplify.configure()
            } catch {
                fatalError("Unable to configure Amplify \(error)")
            }
        }
    
    var body: some Scene {
        WindowGroup {
            LivenessView()
                .environmentObject(LivenessViewModel())
        }
    }
}
