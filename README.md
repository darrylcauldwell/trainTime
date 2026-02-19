# LiveRail

Live UK train departure tracking app for iOS.

## Features

- **Live Departures** — Real-time departure boards filtered by destination, with operator, platform, estimated times, delay reasons, and cancellation notices
- **Journey Planner** — Connecting journeys with interchanges, covering both London (via TfL) and national routes (via Smart Planner algorithm)
- **Get Home** — Detects your current location, finds the nearest stations, and shows live departures toward your home station with walking distances and optional TfL transit directions
- **Find Alternatives** — Automatically surfaces non-cancelled services when your train is cancelled
- **Saved Journeys** — Save frequent routes for one-tap access
- **Offline Mode** — Cached departure data shown with a timestamp when no network is available
- **CarPlay** — View live departures for a saved route on your car display
- **Settings** — Configurable refresh interval, cache management, and optional API credentials

## Requirements

- iOS 17.0 or later
- iPhone
- Network connection for live data (cached data available offline)

## Privacy

No data is collected. Location is accessed on-device only to identify your nearest station — GPS coordinates are never transmitted to any server. No analytics, no tracking, no ads.

Read the full [Privacy Policy](PRIVACY.md).

---

## Technical Reference

### Data Sources

#### Huxley2 — National Rail Departures

**Base URL:** `https://huxley2.azurewebsites.net`

Huxley2 is an open proxy for the National Rail Darwin OpenLDBWS feed. All live departure data comes from here.

| Endpoint | Used for |
|----------|----------|
| `GET /departures/{origin}/to/{destination}` | Departure board filtered by destination |
| `GET /arrivals/{station}/from/{origin}` | Arrival board used by the Smart Journey Planner to find connecting services |

Parameters include an access token (a default public token is embedded; users can supply their own in Settings). Responses are decoded into `DepartureBoard` → `TrainService` models which carry scheduled/estimated times, platform, operator, and cancellation/delay reasons.

#### TfL Unified API — London Transit

**Base URL:** `https://api.tfl.gov.uk`

Used for two distinct purposes:

| Endpoint | Used for |
|----------|----------|
| `GET /Journey/JourneyResults/{from}/to/{to}` | Multi-leg journey planning within London (modes: tube, DLR, Overground, Elizabeth line, walking) |
| `GET /StopPoint/{stopId}/Arrivals` | Real-time arrivals at a tube/rail stop, used to verify the next live service on a leg and detect line suspensions |

The Journey API accepts lat/lon coordinates for origin and destination (preferred over CRS codes to avoid disambiguation errors at stations served by multiple lines). When a stop has live predictions but none on the expected line, the service treats the line as suspended and surfaces a disruption message to the user.

#### TransportAPI — Full UK Journey Planning (Optional)

**Base URL:** `https://transportapi.com/v3/uk/public/journey/`

An optional paid data source for national journey planning beyond London. Requires the user to supply their own `app_id` and `app_key` in Settings. When configured it takes precedence over the Smart Planner algorithm.

---

### Station Database

A bundled JSON file (`uk_rail_stations.json`, 2,595 entries) provides the full UK rail network. Each entry contains:

```json
{ "crs": "CHD", "name": "Chesterfield", "lat": 53.2383, "lon": -1.4214 }
```

At launch, `StationSearchService` loads this into memory with two indexes:
- A dictionary keyed by CRS code for O(1) lookup
- The full array for proximity searches and free-text search

**Search** (`search(query:)`) — case-insensitive prefix/contains match, returns top 15 results.
**Nearest** (`nearestStations(to:count:)`) — Haversine distance sort for Get Home.
**London detection** — stations within the bounding box 51.28–51.69°N, -0.51–0.33°E are treated as London for API routing decisions.

---

### View Architecture

```
ContentView  (floating 2-tab switcher)
│
├── JourneySearchView          ← origin/destination picker, recent routes, saved journeys
│     └── DepartureListView   ← live TrainService list, auto-refresh (default 30s)
│           ├── ServiceDetailView   ← calling points for a selected service
│           └── JourneyPlannerView  ← connecting journeys (shown when no direct trains found)
│                 └── JourneyDetailView  ← leg-by-leg breakdown of a journey
│
├── GetHomeView                ← location lookup, nearest stations, live departures homeward
│     └── DepartureListView
│
└── SettingsView               ← sheet presented from gear icon in any view's navigation bar
```

**Departure list flow:**
1. `DepartureListView` calls `HuxleyAPIService.fetchDepartures(origin, destination, rows: 10)`.
2. The response is decoded into `[TrainService]` and displayed. National Rail customer messages (`NRCCMessage`) appear as a banner.
3. If no direct services are found, `SmartJourneyPlanner` runs automatically and the results appear below as `JourneyCard` rows.
4. Results are cached in SwiftData (`CachedDeparture`) with a 2-minute stale threshold and 24-hour expiry. On a network failure the cached version is shown with an "Offline" banner.

**Get Home flow:**
1. `LocationService` acquires the user's GPS position (permission requested on first use).
2. `JourneyPlanningService.getHomeOptions()` determines whether the user is in London.
   - **London:** Queries nine major termini (STP, EUS, KGX, VIC, WAT, PAD, LBG, LST, MYB) in parallel, plus a TfL transit journey to each.
   - **Elsewhere:** Finds the five nearest stations via `StationSearchService.nearestStations()`, fetches departures for each.
3. Results are returned as `[GetHomeOption]` sorted by walking distance and displayed as option cards. Each card shows the nearest train(s), walk time, and — for London — the tube/rail path to the station. If a transit line is detected as suspended, an orange disruption banner appears with a tap-to-scroll shortcut to the next-nearest alternative.

**Smart Journey Planner flow:**
1. Looks up potential interchange stations from a hardcoded database of ~60 major UK interchanges.
2. For each interchange, fetches arrivals from the origin and departures toward the destination in parallel.
3. Matches feasible connections (non-cancelled, 5–60 min change window), deduplicates by service pair, and returns up to five journeys sorted by total duration.
4. Each `Journey` contains an array of `JourneyLeg` objects (train, walk, tube, etc.) carrying origin/destination with CRS code, lat/lon, and TfL stop ID where applicable.

---

### Key Data Models

| Model | Purpose |
|-------|---------|
| `TrainService` | A single departure: times, platform, operator, cancellation/delay reasons. `Hashable` for SwiftUI navigation. |
| `DepartureBoard` | Container returned by Huxley2: location name + array of `TrainService`. |
| `Journey` | A multi-leg route: array of `JourneyLeg`, departure/arrival times, total duration. |
| `JourneyLeg` | One segment: transport mode, origin, destination, scheduled times, platform, disruption message. |
| `GetHomeOption` | Nearest station + live departures toward home + walk distance + optional TfL transit path. |
| `Station` | CRS code, name, lat/lon. Source of truth for all station lookups. |
| `SavedJourney` | SwiftData model persisting a favourite origin/destination pair. |
| `CachedDeparture` / `CachedJourney` | SwiftData models for offline cache with stale/expiry timestamps. |
| `RecentRoute` | SwiftData model recording search history, with pin/unpin support. |

---

### Architecture Notes

- **State management:** `@Observable` (iOS 17+) throughout — no `ObservableObject` or Combine.
- **Concurrency:** `async/await` with `TaskGroup` for parallel station queries; `@MainActor` for UI updates.
- **Networking:** `URLSession` with 15 s request / 30 s resource timeout; `URLComponents` for query encoding; custom `APIError` for HTTP status handling.
- **Persistence:** SwiftData with four models; cache pruning runs on app launch.
- **CarPlay:** `CarPlaySceneDelegate` implements `CPTemplateApplicationSceneDelegate`; reads the active route from `UserDefaults` and refreshes the `CPListTemplate` every 30 seconds.

---

## Support

[Open an issue](https://github.com/darrylcauldwell/trainTime/issues) for bug reports or feature requests.

## License

© 2026 Darryl Cauldwell
