<div align="center">

![KafeCam Logo](./Assets/logo/kafecam-logo.png)

### AI-Powered Disease Detection for Coffee Farmers

*A mobile-first platform combining machine learning, real-time weather intelligence, and collaborative farm management for smallholder coffee growers.*

![iOS](https://img.shields.io/badge/iOS-16+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![Version](https://img.shields.io/badge/Version-1.0-brightgreen.svg)

[**Features**](#features) • [**Tech Stack**](#tech-stack) • [**Getting Started**](#getting-started) • [**Download**](#download) • [**Contributing**](#contributing)

</div>

---

## Overview

**KafeCam** is an iOS application designed to empower coffee farmers in rural agricultural communities with intelligent crop monitoring. Using on-device machine learning, it identifies coffee crop diseases and nutritional deficiencies in real-time, provides actionable weather forecasts, and enables seamless collaboration between farmers and agricultural technicians.

Developed with farmers in Chiapas, Mexico in mind, KafeCam bridges the digital divide in agricultural technology by providing accessible, offline-capable disease detection without requiring internet connectivity for core functionality.

<div align="center">

| Home | Detection | Weather | Encyclopedia | Map | History |
|------|-----------|---------|--------------|-----|---------|
| ![Home](./Assets/images/screen-home.png) | ![Detect](./Assets/images/screen-detect.png) | ![Weather](./Assets/images/screen-anticipa.png) | ![Info](./Assets/images/screen-encyclopedia.png) | ![Map](./Assets/images/screen-map.png) | ![History](./Assets/images/screen-history.png) |

</div>

---

## Features

### 🔍 **Detecta** — Real-Time Disease Detection
Identify crop health issues instantly using your device camera.

- **On-device ML classification** — No internet required for diagnosis
- **5 coffee diseases** — Coffee Rust (Roya) and 4 nutritional deficiencies (Nitrogen, Iron, Magnesium, Manganese)
- **Confidence scoring** — See prediction accuracy at a glance
- **Field verification** — Accept or reject predictions before saving
- **Local & cloud storage** — Captures sync to your cloud history

### 🌤️ **Anticipa** — Weather Intelligence & Alerts
Stay ahead of crop threats with real-time weather and agronomic risk forecasting.

- **3-day forecast** — Temperature, humidity, rainfall, wind
- **Smart risk alerts** — Frost warnings, optimal spray windows, harvest dry-spell detection
- **Plot-specific data** — Weather pulled for your exact GPS location
- **Offline reference** — Access alerts without internet (cached data)

### 📚 **Infórmate** — Interactive Disease Encyclopedia
Visual reference guide for coffee diseases and nutritional problems.

- **High-resolution photos** — Symptoms from real infected crops
- **Treatment guidance** — Evidence-based recommendations
- **Search capability** — Find diseases by name or symptom
- **Offline encyclopedia** — All content available without internet

### 📍 **Mapa** — Plot Management & Visualization
Organize and monitor your coffee plots on an interactive map.

- **GPS-tagged plots** — Pin each plot's exact location
- **Disease history** — See detected issues pinned to specific locations
- **Geographic trends** — Identify disease spread patterns across your farm
- **Map controls** — Zoom, pan, manual location pin placement

### 📋 **Consulta** — Capture History & Analysis
Maintain a chronological record of all field inspections.

- **Photo library** — Every capture with timestamp and location
- **Disease labels** — Auto-predicted diagnoses saved per photo
- **Field notes** — Add handwritten observations and treatment notes
- **Favorites system** — Flag important findings for quick reference
- **Cloud sync** — All captures backed up and accessible across devices

### 👥 **Comunidad** — Farmer-Technician Collaboration
Build trusted networks for peer support and expert guidance.

- **Role-based access** — Separate workflows for farmers and technicians
- **Farmer assignment** — Request technical support from certified agronomists
- **Technician management** — Oversee farmer portfolios and provide recommendations
- **Custom user lists** — Group farmers by region or crop variety
- **Profile visibility** — Control which personal information is shared
- **User search & filtering** — Find collaborators by name, organization, or expertise

### 🌍 **Multilingual Interface**
- **Spanish** (Español) — Full coverage ✅
- **English** — Full coverage ✅
- **Tzotzil** (Indigenous Chiapas language) — Community translation in progress ⚠️

### 🔐 **Authentication & Security**
- **Phone-based registration** — 10-digit Mexico phone numbers
- **Guest mode** — Browse without creating an account
- **End-to-end encrypted storage** — Images stored in cloud with server-side access control
- **Role-based permissions** — Server enforces data isolation between farmers and technicians

---

## Tech Stack

### Frontend
- **Language:** Swift 5.0
- **UI Framework:** SwiftUI (declarative, modern)
- **Minimum iOS Version:** 16.0+
- **Platforms:** iOS, iPadOS, macOS, visionOS

### Machine Learning
- **Framework:** CoreML + Vision (on-device)
- **Model:** CoffeeDiseaseClassifier_v100.mlmodel (65 KB)
- **Inference:** Real-time, no external API calls
- **Capabilities:** Image classification for 9 disease/deficiency classes

### Backend & Cloud
- **Platform:** Supabase (PostgreSQL + PostgREST API)
- **Authentication:** Supabase Auth (phone + password)
- **File Storage:** Supabase Storage (image uploads)
- **Database:** PostgreSQL with Row-Level Security (RLS)
- **Edge Functions:** Pre-signed URL generation for secure uploads

### External APIs
- **Weather:** Open-Meteo (free, no API key required)
- **Maps:** MapKit + Core Location
- **Microphone:** AVFoundation (voice notes, if enabled)

### Architecture
- **Pattern:** MVVM + Repository Pattern
- **State Management:** @StateObject, @EnvironmentObject
- **Data Persistence:** UserDefaults, SQLite (local), Supabase (cloud)
- **Navigation:** SwiftUI NavigationStack + TabView

---

## Project Structure

```
KafeCam/
├── Detecta/                 # Disease detection (CoreML camera)
├── Anticipa/                # Weather forecasting & risk alerts
├── DiseaseScreen/           # Encyclopedia (diseases.json)
├── HistoryScreen/           # Photo history & favorites
├── HomeScreen/              # Dashboard & main navigation
├── Map/                      # MapKit integration & plot visualization
├── Plots/                    # Plot CRUD operations
├── Profile/                  # User settings, avatar, community, assignments
├── Login/Register/          # Authentication & onboarding
├── LocalizationKit/         # Multi-language support (ES/EN/TZO)
├── Models/                   # Data Transfer Objects (DTOs)
├── Repositories/            # 6 data repositories (Supabase layer)
├── Services/                # Business logic (CapturesService)
├── Networking/              # Supabase configuration
├── Assets.xcassets/         # Images, icons, disease reference photos
├── KafeCamTests/            # Unit tests (~1000 lines)
├── KafeCamUITests/          # UI integration tests
└── Localizable.strings      # String localization (ES/EN/TZO)
```

**Code Volume:** ~10,361 lines of Swift across 91 Swift files

---

## Getting Started

### Prerequisites
- **Xcode:** 15.0 or later
- **macOS:** 12.0 or later
- **iOS Target:** 16.0+
- **Swift:** 5.0+
- **Supabase Account:** Free tier sufficient for development

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/KafeCam.git
   cd KafeCam
   ```

2. **Install dependencies** (Swift Package Manager is implicit)
   ```bash
   # Open in Xcode 15+
   open KafeCam.xcodeproj
   ```

3. **Configure Supabase credentials**
   - Create a `KafeCamSecrets.xcconfig` file:
     ```
     SUPABASE_URL = https://your-project.supabase.co
     SUPABASE_ANON_KEY = eyJhbGc...
     ```
   - Environment variables automatically injected into `Info.plist` at build time

4. **Run the app**
   ```bash
   # Select iPhone/iPad simulator or connect a device
   # Press Cmd+R to build and run
   ```

5. **Create a test account**
   - Use phone: `1234567890`
   - Password: `test123456`
   - Or sign up with your own phone number

---

## Database Schema

KafeCam uses Supabase PostgreSQL with the following core tables:

| Table | Purpose | Key Fields |
|-------|---------|-----------|
| `profiles` | User accounts | id, phone, name, email, role (farmer/technician), organization, locale, privacy settings |
| `plots` | Coffee plantation plots | id, name, lat, lon, altitude_m, region, owner_user_id |
| `captures` | Photo diagnoses | id, plot_id, uploaded_by_user_id, taken_at, photo_key, notes, device_model |
| `technician_farmers` | Assignment links | technician_id, farmer_id |
| `assignment_requests` | Collaboration requests | id, technician_id, farmer_id, status |

**Row-Level Security (RLS):** Enforced at the database level. Users can only access their own data and data shared explicitly by collaborators.

---

## User Roles

KafeCam has three roles: `farmer`, `technician`, and `admin`.

**Promote a user via Supabase SQL editor**

```sql
-- Promote to technician
UPDATE public.profiles SET role = 'technician' WHERE phone = '9511407969';

-- Promote to admin
UPDATE public.profiles SET role = 'admin' WHERE phone = '9511407969';
```

**Assign a farmer to a technician manually**

```sql
INSERT INTO public.technician_farmers (technician_id, farmer_id)
VALUES ('<TECHNICIAN_UUID>', '<FARMER_UUID>');
```

Technicians can also manage farmers directly from the app under **Profile > Farmers**.

---

## Localization

| Language | Code | Status | Coverage |
|----------|------|--------|----------|
| Spanish | `es` | ✅ Complete | 100% |
| English | `en` | ✅ Complete | 100% |
| Tzotzil | `tzo` | ⚠️ Beta | ~30% |

Switch languages anytime from **Profile > Language**.

### Adding New Strings

Use `NSLocalizedString("key", comment: "description")` in code:

```swift
Text(NSLocalizedString("welcome.title", comment: "Home screen title"))
```

Then add to each `.strings` file in the language's `.lproj` folder.

---

## Machine Learning Model

### CoffeeDiseaseClassifier_v100

**Model Details:**
- **Framework:** CoreML
- **Input:** Image (224×224 RGB)
- **Output:** 9 classes with confidence scores
- **Size:** 65 KB (optimized for on-device inference)
- **Inference Speed:** <100ms on modern iOS devices

**Detected Classes:**
1. Coffee Rust (Roya) — fungal disease
2. Nitrogen Deficiency
3. Iron Deficiency
4. Magnesium Deficiency
5. Manganese Deficiency
6. Healthy Leaf (Control)
7-9. Other/Background classes

---

## Security & Authentication

### Registration Flow
1. User enters phone (10 digits) + password + personal info
2. Supabase Auth creates user account
3. Profile record upserted to `profiles` table
4. JWT token stored securely in Keychain
5. User logged in automatically

### Token Management
- **Storage:** Keychain (secure, device-encrypted)
- **Expiration:** 1 hour (auto-refresh)
- **Scope:** Limited to authenticated user's data only

### Row-Level Security (RLS)

All tables enforce RLS policies at the database level:

```sql
-- Users can only see their own profile
CREATE POLICY "Users can view their own profile"
ON profiles FOR SELECT USING (auth.uid() = id);

-- Farmers can see their technicians
CREATE POLICY "Farmers see their technicians"
ON technician_farmers FOR SELECT USING (
  auth.uid() = farmer_id OR auth.uid() = technician_id
);
```

---

## Development

### Running Tests

```bash
# Open Xcode project
open KafeCam.xcodeproj

# Run all tests
# Press Cmd+U or: Product > Test
```

**Test Coverage:**
- Repository queries and filters
- ViewModel state transitions
- Search and notification logic
- DTO serialization/deserialization

### Debugging

Enable debug logging in code:

```swift
DebugLog("User logged in: \(userId)")  // Only prints in DEBUG builds
```

---

## Known Issues & Limitations

| Issue | Severity | Status |
|-------|----------|--------|
| No offline capture queue | Medium | Backlog |
| History pagination missing | Medium | Backlog |
| No push notifications | Low | Backlog |
| Tzotzil translation incomplete | Low | In Progress |
| Limited error recovery | Low | Backlog |

---

## Contributing

We welcome contributions from developers, translators, and agricultural experts!

### How to Contribute

1. **Fork** the repository
2. **Create a feature branch:** `git checkout -b feature/my-feature`
3. **Commit changes:** `git commit -m "Add: my new feature"`
4. **Push:** `git push origin feature/my-feature`
5. **Open a Pull Request** with description of changes

### Areas for Contribution

- **Bug fixes** and issue reports
- **Feature requests** and suggestions
- **Translation** — Help with Tzotzil, Portuguese, French, or other languages
- **Testing** — Unit tests, UI tests, and field testing
- **Documentation** — Improve README, code comments, API docs
- **Machine Learning** — Help improve disease classifier accuracy

---

## Roadmap

### Version 1.1 (Planned)
- [ ] Offline-first sync — Capture when offline, sync when internet returns
- [ ] Pagination — Load captures in batches instead of all at once
- [ ] Advanced search — Filter by disease, date range, plot

### Version 1.2 (Planned)
- [ ] Push notifications — Real-time alerts for requests and weather warnings
- [ ] Voice notes — Record observations instead of typing
- [ ] Batch processing — Analyze multiple photos at once

### Future
- [ ] Soil sensor integration — Bluetooth connection to sensors
- [ ] Multi-crop support — Extend beyond coffee
- [ ] Market price tracking — Real-time coffee commodity pricing
- [ ] Admin dashboard — Web-based management tools
- [ ] Third-party API — Allow external integrations

---

## Support

### Help & Documentation
- **In-App Help:** Tap the ℹ️ icon in any screen
- **Community Forum:** [forum.kafecam.example.com](https://forum.kafecam.example.com)
- **Contact Us:** support@kafecam.example.com

### Report a Bug

Open an issue on GitHub: [github.com/yourusername/KafeCam/issues](https://github.com/yourusername/KafeCam/issues)

---

## Download

<div align="center">

[![Download on the App Store](https://developer.apple.com/app-store/marketing/guidelines/images/badge-download-on-the-app-store.svg)](https://apps.apple.com/mx/app/kafecam/id6762103541?l=en-GB)

**Version 1.0** — Available on iOS 16+ — Free

</div>

---

## Credits

### Team
- **Creator & Lead Developer:** José Manuel Sánchez Pérez
- **Design & UX:** [Design Team]
- **Agricultural Advisor:** [Agronomist Name]
- **Translation Team:** Community contributors

### Acknowledgments

- 🙏 Coffee farming communities in Chiapas, Mexico for testing and feedback
- 🙏 Supabase for backend infrastructure
- 🙏 Open-Meteo for free weather API
- 🙏 Apple CoreML team for on-device inference

---

## License

KafeCam is distributed under the **MIT License**. See [LICENSE.md](./LICENSE.md) for details.

© 2026 KafeCam. All rights reserved.

---

<div align="center">

### Made with ☕ in Chiapas, Mexico

For farmers, by farmers.

</div>
