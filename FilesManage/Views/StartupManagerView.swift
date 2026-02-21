
import SwiftUI

struct StartupManagerView: View {
    @StateObject private var manager = LaunchAgentManager()
    @State private var selection: Set<UUID> = []
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("startup.title".localized)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button(action: { manager.fetchAgents() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("toolbar.refresh".localized)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            if manager.agents.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "wind")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("startup.empty".localized)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selection) {
                    ForEach(manager.agents) { agent in
                        HStack(spacing: 12) {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.secondary)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(agent.label ?? agent.name)
                                    .font(.headline)
                                if agent.label != nil {
                                    Text(agent.name)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: { manager.openInFinder(agent) }) {
                                Image(systemName: "magnifyingglass")
                            }
                            .buttonStyle(.plain)
                            .help("startup.showInFinder".localized)
                        }
                        .padding(.vertical, 4)
                        .contextMenu {
                            Button("startup.showInFinder".localized) {
                                manager.openInFinder(agent)
                            }
                            Divider()
                            Button("startup.delete".localized, role: .destructive) {
                                manager.deleteAgent(agent)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .background(Color.themeBackground)
        .onAppear {
            manager.fetchAgents()
        }
    }
}
