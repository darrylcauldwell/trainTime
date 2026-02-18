//
//  SettingsView.swift
//  LiveRail
//
//  API token configuration, refresh interval, cache management
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @State private var apiToken: String = UserDefaults.standard.string(forKey: "darwinApiToken") ?? ""
    @State private var networkRailUsername: String = UserDefaults.standard.string(forKey: "networkRailUsername") ?? ""
    @State private var networkRailPassword: String = UserDefaults.standard.string(forKey: "networkRailPassword") ?? ""
    @State private var tflAppId: String = UserDefaults.standard.string(forKey: "tflAppId") ?? ""
    @State private var tflAppKey: String = UserDefaults.standard.string(forKey: "tflAppKey") ?? ""
    @State private var transportAPIAppId: String = UserDefaults.standard.string(forKey: "transportAPIAppId") ?? ""
    @State private var transportAPIAppKey: String = UserDefaults.standard.string(forKey: "transportAPIAppKey") ?? ""
    @State private var enableSmartAlgorithm: Bool = UserDefaults.standard.bool(forKey: "enableSmartAlgorithm")
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

                // Network Rail Open Data
                Section {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(String(localized: "Network Rail Open Data"))
                            .font(.subheadline.bold())
                        Text(String(localized: "For detailed departed train information"))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField(String(localized: "Username"), text: $networkRailUsername)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .onChange(of: networkRailUsername) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "networkRailUsername")
                            }

                        SecureField(String(localized: "Password"), text: $networkRailPassword)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: networkRailPassword) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "networkRailPassword")
                            }

                        Link(String(localized: "Register at opendata.nationalrail.co.uk"), destination: URL(string: "https://opendata.nationalrail.co.uk/")!)
                            .font(.caption)
                            .foregroundStyle(AppColors.primary)
                    }
                } header: {
                    Label(String(localized: "Historical Data"), systemImage: "clock.arrow.circlepath")
                } footer: {
                    Text(String(localized: "Network Rail provides actual departure/arrival times for departed trains. This is optional - the app works without it."))
                }

                // Journey Planning
                Section {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        // Smart Algorithm (Free)
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(String(localized: "Smart Algorithm (Free)"))
                                        .font(.subheadline.bold())
                                    Text(String(localized: "Uses existing Huxley2 API for free journey planning"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: $enableSmartAlgorithm)
                                    .labelsHidden()
                                    .onChange(of: enableSmartAlgorithm) { _, newValue in
                                        UserDefaults.standard.set(newValue, forKey: "enableSmartAlgorithm")
                                    }
                            }

                            if enableSmartAlgorithm {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(AppColors.onTime)
                                        Text(String(localized: "Free forever • Works for most UK routes"))
                                            .font(.caption.bold())
                                            .foregroundStyle(AppColors.onTime)
                                    }
                                    Text(String(localized: "Finds connections via major UK interchanges like Manchester, Birmingham, and Crewe. Best for routes like Walkden→Euston."))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.top, Spacing.xs)
                            }
                        }

                        Divider()

                        // TfL API
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text(String(localized: "TfL Unified API (Free)"))
                                .font(.subheadline.bold())
                            Text(String(localized: "London and South East UK coverage"))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TextField(String(localized: "App ID"), text: $tflAppId)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .onChange(of: tflAppId) { _, newValue in
                                    UserDefaults.standard.set(newValue, forKey: "tflAppId")
                                }

                            SecureField(String(localized: "App Key"), text: $tflAppKey)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: tflAppKey) { _, newValue in
                                    UserDefaults.standard.set(newValue, forKey: "tflAppKey")
                                }

                            Link(String(localized: "Register at api.tfl.gov.uk"), destination: URL(string: "https://api.tfl.gov.uk")!)
                                .font(.caption)
                                .foregroundStyle(AppColors.primary)
                        }

                        Divider()

                        // TransportAPI (optional, for future use)
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text(String(localized: "TransportAPI (Paid, Optional)"))
                                .font(.subheadline.bold())
                            Text(String(localized: "Full UK coverage - for inter-city journeys"))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TextField(String(localized: "App ID"), text: $transportAPIAppId)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .onChange(of: transportAPIAppId) { _, newValue in
                                    UserDefaults.standard.set(newValue, forKey: "transportAPIAppId")
                                }

                            SecureField(String(localized: "App Key"), text: $transportAPIAppKey)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: transportAPIAppKey) { _, newValue in
                                    UserDefaults.standard.set(newValue, forKey: "transportAPIAppKey")
                                }

                            Link(String(localized: "Register at transportapi.com"), destination: URL(string: "https://www.transportapi.com")!)
                                .font(.caption)
                                .foregroundStyle(AppColors.primary)
                        }
                    }
                } header: {
                    Label(String(localized: "Journey Planning"), systemImage: "arrow.triangle.branch")
                } footer: {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(String(localized: "Journey planning finds routes with changes when no direct trains are available."))
                        Text(String(localized: "Recommendation order:"))
                            .font(.caption.bold())
                            .padding(.top, 4)
                        Text(String(localized: "1. Smart Algorithm (Free) - Best for most users"))
                            .font(.caption)
                        Text(String(localized: "2. TransportAPI (Paid) - For maximum reliability"))
                            .font(.caption)
                        Text(String(localized: "3. TfL API (Free) - London area only"))
                            .font(.caption)
                    }
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

                // NRE Attribution (required by Darwin API terms)
                Section {
                    VStack(spacing: Spacing.md) {
                        Image("NRE_Powered")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 200)
                            .padding(.vertical, Spacing.sm)

                        Text("Live departure data provided by National Rail Enquiries")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Link("Visit nationalrail.co.uk", destination: URL(string: "https://www.nationalrail.co.uk")!)
                            .font(.caption)
                            .foregroundStyle(AppColors.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                } header: {
                    Label(String(localized: "Data Provider"), systemImage: "train.side.front.car")
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
