# trainTime Privacy Policy

**Effective Date:** February 13, 2026

## Overview

trainTime (\"the App\") is committed to protecting your privacy. This Privacy Policy explains how we handle information when you use our iOS application.

## Information We Collect

**trainTime does not collect, transmit, or store any personal information.**

### Data Storage

All data within trainTime is stored locally on your device:

- **Saved Journeys:** Your saved train routes are stored in your device's local database using SwiftData
- **Recent Searches:** Your recent journey searches are stored locally for quick access
- **Cached Data:** Departure and service information is temporarily cached on your device for offline viewing
- **User Preferences:** App settings (refresh intervals, API tokens) are stored in your device's local preferences

This data never leaves your device and is not transmitted to any servers we operate.

### Third-Party Services

trainTime uses the following third-party services:

#### National Rail Darwin OpenLDBWS API (Huxley2)

- We fetch live train departure and service information from National Rail's Darwin OpenLDBWS API via the Huxley2 proxy (https://huxley2.azurewebsites.net)
- This service receives your API requests containing station codes (CRS codes) to retrieve train information
- We do not control this third-party service. Please review National Rail's privacy policy at https://www.nationalrail.co.uk/privacy-policy/

#### Transport for London (TfL) API (Optional)

- When you request directions to a London station, we use TfL's Journey Planner API
- This service receives your location and destination to provide transit directions
- We do not control this third-party service. Please review TfL's privacy policy at https://tfl.gov.uk/corporate/privacy-and-cookies/

### Location Data

trainTime requests access to your location **only when you explicitly request directions** to a railway station:

- Location access is \"When In Use\" only - never in the background
- Your location is used solely to provide Apple Maps directions to the selected station
- Your location data is not stored, transmitted to our servers, or used for any other purpose
- You can deny location access and still use all other features of the App

### App Group Data Sharing

trainTime uses App Groups to share data between the main app, home screen widget, and Live Activities:

- Saved journey data is shared with the widget to display next departures
- Live Activity data is shared to show train progress on the Lock Screen
- This data remains on your device only and is not transmitted elsewhere

## Data We Do Not Collect

trainTime does **not** collect, store, or transmit:

- Personal identifiable information (name, email, phone number)
- Usage analytics or crash reports
- Advertising identifiers
- Device identifiers for tracking purposes
- Any data for marketing, advertising, or profiling

## Data Retention

Since all data is stored locally on your device:

- Data persists until you delete the App or clear cache through the App's settings
- Deleting the App removes all locally stored data
- No data is retained on any servers we operate

## Third-Party Access

We do not sell, trade, or transfer your data to third parties. The only data transmission occurs when the App fetches live train information from National Rail's API as part of normal operation.

## CarPlay and Live Activities

- **CarPlay:** Displays departure information from your saved journeys. Data remains on your device.
- **Live Activities:** Shows train progress on your Lock Screen and Dynamic Island. Data remains on your device.
- **Home Screen Widget:** Displays next departure for your saved journey. Data remains on your device.

## Children's Privacy

trainTime does not knowingly collect information from children. The App is rated 4+ and suitable for all ages.

## Changes to This Privacy Policy

We may update this Privacy Policy from time to time. We will notify you of any changes by updating the \"Effective Date\" at the top of this policy. Continued use of the App after changes constitutes acceptance of the updated policy.

## Contact Us

If you have questions about this Privacy Policy, please contact:

**Email:** darryl@dreamfold.dev

## Your Rights

Under UK GDPR and applicable data protection laws:

- You have the right to know what data is processed (none, in this case)
- You have the right to deletion (delete the App from your device)
- You have the right to data portability (data is already on your device)

Since trainTime does not collect or process personal data on servers, these rights are inherently satisfied through local storage.

---

**Summary:** trainTime is a privacy-first application. Your data stays on your device, we collect nothing, and we have no tracking or analytics. The only network communication is fetching live train times from National Rail's public API.
