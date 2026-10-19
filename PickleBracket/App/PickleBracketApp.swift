import SwiftUI
import SwiftData

@main
struct PickleBracketApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TournamentModel.self,
            LeagueModel.self,
            BracketMatchModel.self,
            TeamModel.self,
            PlayerModel.self,
            UserProfileModel.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}
