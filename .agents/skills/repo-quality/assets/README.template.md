# Project Name

One or two sentences describing what the app does and who it is for.

![Screenshot of the main screen](docs/images/screenshot-main.png)

## Features

- Feature one, described by the user benefit
- Feature two
- Feature three

## Tech Stack

- Language and UI framework (for example Swift 6, SwiftUI)
- Architecture (for example MVVM with a protocol-based service layer)
- Backend (for example Supabase: Postgres, Auth, Storage)
- Tooling (for example SwiftLint, GitHub Actions)

## Getting Started

### Requirements

- Xcode 16 or later
- iOS 17 or later
- A Supabase project (free tier is fine)
- Supabase CLI (optional, for running migrations)

### Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/username/project-name.git
   cd project-name
   ```
2. Copy the example config and fill in your values:
   ```bash
   cp Config.example.xcconfig Config.xcconfig
   ```
   `SUPABASE_URL` and `SUPABASE_PUBLIC_KEY` are found in your Supabase dashboard under Project Settings, API.
3. Apply the database schema:
   ```bash
   supabase link --project-ref <your-project-ref>
   supabase db push
   ```
4. Open `ProjectName.xcodeproj` in Xcode, select a simulator, and run.

## Architecture

Short description of how the app is organized and why.

```
ProjectName/
  App/            App entry point and dependency wiring
  Features/       One folder per feature (Views, ViewModels, Models, Services)
  Core/           Networking, persistence, shared utilities
  UI/             Reusable components and styling
supabase/
  migrations/     Database schema and RLS policies
  functions/      Edge functions
```

Key decisions:
- Decision one and the reason for it
- Decision two and the reason for it

## Testing

```bash
xcodebuild test -scheme ProjectName -destination 'platform=iOS Simulator,name=iPhone 16'
```

Describe what is covered and what is not.

## Roadmap and Known Limitations

- Planned improvement
- Known limitation

## License

Released under the MIT License. See [LICENSE](LICENSE).
