# Fix Firebase Storage CORS Issue

The image loading error you're experiencing is likely due to CORS (Cross-Origin Resource Sharing) configuration issues with Firebase Storage when running on web.

## Solution: Configure CORS for Firebase Storage

### Option 1: Using Firebase CLI (Recommended)

1. Install Firebase CLI if you haven't already:
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```bash
   firebase login
   ```

3. Navigate to your project directory and initialize Firebase (if not already done):
   ```bash
   firebase init
   ```

4. Apply the CORS configuration:
   ```bash
   gsutil cors set cors.json gs://YOUR_BUCKET_NAME
   ```
   
   Replace `YOUR_BUCKET_NAME` with your actual Firebase Storage bucket name (e.g., `parkourspot-93c90.appspot.com`)

### Option 2: Using Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your Firebase project
3. Navigate to Cloud Storage > Browser
4. Select your bucket
5. Go to Permissions tab
6. Add the CORS configuration from `cors.json`

### Option 3: Using Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to Storage
4. Click on Rules tab
5. The CORS configuration might need to be set via Google Cloud Console

## What the CORS Configuration Does

The `cors.json` file allows:
- All origins (`*`) to access your storage bucket
- GET, HEAD, PUT, POST, DELETE methods
- Proper headers for cross-origin requests
- 1-hour cache for CORS preflight requests

## After Applying CORS

1. Wait a few minutes for the changes to propagate
2. Clear your browser cache
3. Try creating a new spot with an image
4. The image should now load properly

## Alternative Solution: Use Firebase Storage Rules

If CORS configuration doesn't work, you can also try updating your storage rules to be more permissive:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

## Debugging

The updated code now includes:
- Better error handling with `errorBuilder`
- Loading states with `loadingBuilder`
- Debug logging to console
- CORS headers in the image request

Check your browser's developer console for any error messages after applying the CORS configuration.
