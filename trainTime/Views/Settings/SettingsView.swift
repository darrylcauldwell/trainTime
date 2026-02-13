//
//  SettingsView.swift
//  trainTime
//
//  API token configuration, refresh interval, cache management
//

import SwiftUI

struct SettingsView: View {
    @State private var apiToken: String = UserDefaults.standard.string(forKey: "darwinApiToken") ?? ""
    @State private var refreshInterval: Double = UserDefaults.standard.double(forKey: "refreshInterval")
    @State private var showClearCacheAlert = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Form {
                // API Configuration
                Section {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(String(localized: "Darwin API Token"))
                            .font(.subheadline.bold())
                        Text(String(localized: "Register for free at raildata.org.uk"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        SecureField(String(localized: "Enter your API token"), text: $apiToken)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: apiToken) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "darwinApiToken")
                            }
                    }
                } header: {
                    Label(String(localized: "API Configuration"), systemImage: "key.fill")
                }

                // Refresh Settings
                Section {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(String(localized: "Auto-refresh interval"))
                            .font(.subheadline)
                        Picker(String(localized: "Interval"), selection: Binding(
                            get: { refreshIntervalOption },
                            set: { newValue in
                                refreshInterval = newValue
                                UserDefaults.standard.set(newValue, forKey: "refreshInterval")
                            }
                        )) {
                            Text(String(localized: "15 seconds")).tag(15.0)
                            Text(String(localized: "30 seconds")).tag(30.0)
                            Text(String(localized: "60 seconds")).tag(60.0)
                            Text(String(localized: "2 minutes")).tag(120.0)
                        }
                        .pickerStyle(.segmented)
                    }
                } header: {
                    Label(String(localized: "Refresh"), systemImage: "arrow.clockwise")
                }

                // Cache Management
                Section {
                    Button(role: .destructive) {
                        showClearCacheAlert = true
                    } label: {
                        Label(String(localized: "Clear All Cached Data"), systemImage: "trash")
                    }

                    Button(role: .destructive) {
                        clearRecentHistory()
                    } label: {
                        Label(String(localized: "Clear Recent History"), systemImage: "clock.arrow.circlepath")
                    }
                } header: {
                    Label(String(localized: "Cache"), systemImage: "internaldrive")
                } footer: {
                    Text(String(localized: "Cached data is used when you have no signal. Clearing it will remove all offline data."))
                }

                // About
                Section {
                    HStack {
                        Text(String(localized: "Version"))
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text(String(localized: "Data Source"))
                        Spacer()
                        Text("Darwin OpenLDBWS")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label(String(localized: "About"), systemImage: "info.circle")
                }
            }
            .navigationTitle(String(localized: "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .glassNavigation()
            .alert(String(localized: "Clear Cache?"), isPresented: $showClearCacheAlert) {
                Button(String(localized: "Cancel"), role: .cancel) {}
                Button(String(localized: "Clear"), role: .destructive) {
                    CacheService(modelContext: modelContext).clearAllCache()
                }
            } message: {
                Text(String(localized: "This will remove all cached departure and service data. You will need an internet connection to view train information."))
            }
            .onAppear {
                if refreshInterval == 0 { refreshInterval = 30 }
            }
        }
    }

    private func clearRecentHistory() {
        do {
            try modelContext.delete(model: RecentRoute.self)
        } catch {
            // Silently handle - non-critical operation
        }
    }

    private var refreshIntervalOption: Double {
        switch refreshInterval {
        case 0...22: return 15
        case 23...45: return 30
        case 46...90: return 60
        default: return 120
        }
    }
}
