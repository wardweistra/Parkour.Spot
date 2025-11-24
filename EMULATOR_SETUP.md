# Firebase Emulator Setup for Local Development

This guide explains how to develop locally **without needing access to the production Firebase account**.

## What are Firebase Emulators?

Firebase Emulators are local versions of Firebase services (Firestore, Auth, Storage, Functions) that run on your machine. They allow you to:
- Develop and test features without affecting production data
- Work offline
- Test without needing Firebase credentials
- Reset data easily

## Prerequisites

1. **Firebase CLI** - Install with: `npm install -g firebase-tools`
2. **Java** (required for some emulators) - Install Java if you don't have it
3. **Flutter** with web support enabled

## Quick Start

### Option 1: Run with Emulators (Recommended for Local Development)

1. **Start the Firebase Emulators** (in one terminal):
   ```bash
   ./scripts/start_emulators.sh
   ```
   This will start all emulators and the Emulator UI at http://localhost:4000

2. **Run the Flutter app** (in another terminal):
   ```bash
   ./scripts/run_local_with_emulators.sh
   ```
   This will:
   - Create a `.env.emulator` file with dummy Firebase values (if it doesn't exist)
   - Start the Flutter web app on http://localhost:8080
   - Connect the app to the local emulators

### Option 2: Run with Production Firebase

If you have access to the production Firebase account:
```bash
./scripts/run_local.sh
```

## Emulator Ports

- **Firestore**: 8082
- **Auth**: 9099
- **Storage**: 9199
- **Functions**: 5001
- **Emulator UI**: 4000
- **Flutter Web App**: 8080

## Emulator UI

Access the Emulator UI at http://localhost:4000 to:
- View and edit Firestore data
- Manage Auth users
- Monitor Storage files
- View Function logs
- Import/export emulator data

## How It Works

1. When you run `run_local_with_emulators.sh`, it sets the `USE_EMULATOR=true` flag
2. The app detects this flag in `main.dart` and connects to local emulators instead of production
3. All Firebase operations (database, auth, storage, functions) use the local emulators

## Data Persistence

By default, emulator data is stored in memory and lost when you stop the emulators. To persist data:

1. Create a `.firebaserc` file (if not exists) or add to `firebase.json`:
   ```json
   {
     "emulators": {
       "firestore": {
         "port": 8082,
         "host": "localhost"
       }
     }
   }
   ```

2. Use the Emulator UI to export/import data as needed

## Troubleshooting

### Port Already in Use
If you get a "port already in use" error:
- Check what's using the port: `lsof -i :PORT_NUMBER`
- Kill the process or change the port in `firebase.json`

### Emulators Not Connecting
- Make sure emulators are running before starting the Flutter app
- Check the browser console for connection errors
- Verify the ports match in `firebase.json` and `main.dart`

### Functions Not Working
- Make sure Functions emulator is running
- Check that the region matches (`europe-west1` in this project)
- View function logs in the Emulator UI

## Notes

- Emulator data is separate from production - you can test freely
- The `.env.emulator` file contains dummy values - they don't need to be real
- You can reset emulator data by restarting the emulators
- Hot reload works normally when using emulators

