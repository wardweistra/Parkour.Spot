# ParkourSpot URL System

This document explains how the stable sharable URLs work in the ParkourSpot app.

## URL Structure

The app supports two URL formats for spots:

1. **Full format**: `https://parkour.spot/spot/{spotId}`
2. **Short format**: `https://parkour.spot/s/{spotId}`

### Examples
- `https://parkour.spot/spot/abc123def456`
- `https://parkour.spot/s/abc123def456`

## Features

### 1. Deep Linking
- Users can tap on spot URLs to open them directly in the app
- Works on both mobile and web platforms
- Handles invalid or non-existent spot IDs gracefully

### 2. Sharing
- Share button in the spot detail screen
- Multiple sharing options:
  - **Share Spot**: Opens system share dialog
  - **Copy Link**: Copies URL to clipboard
  - **Open in Browser**: Opens URL in external browser

### 3. Cross-Platform Support
- **Android**: Deep linking via intent filters
- **iOS**: Universal links via Associated Domains
- **Web**: Direct URL access and navigation

## Implementation Details

### Router Configuration
The app uses `go_router` for navigation and deep linking:

```dart
GoRoute(
  path: '/spot/:spotId',
  builder: (context, state) {
    final spotId = state.pathParameters['spotId']!;
    return SpotDetailRoute(spotId: spotId);
  },
),
```

### URL Service
The `UrlService` class provides utilities for:
- Generating spot URLs
- Sharing spots
- Copying URLs to clipboard
- Opening URLs in browser
- Extracting spot IDs from URLs

### Deep Link Handling
1. **URL Parsing**: Extracts spot ID from incoming URLs
2. **Spot Loading**: Fetches spot data from Firestore
3. **Navigation**: Routes to spot detail screen
4. **Error Handling**: Shows appropriate error messages for invalid URLs

## Setup Requirements

### 1. Domain Configuration
- Configure your domain `parkour.spot` to point to your hosting service
- Set up SSL certificates for HTTPS support

### 2. Firebase Configuration
- Ensure Firestore security rules allow public read access to spots
- Configure Firebase Hosting for web deployment

### 3. Platform-Specific Setup

#### Android
- Intent filters in `AndroidManifest.xml`
- App links verification for automatic opening

#### iOS
- Associated domains in `Info.plist`
- Universal links configuration

#### Web
- Proper base URL configuration
- Service worker for offline support

## Usage Examples

### Sharing a Spot
```dart
// Generate URL
final url = UrlService.generateSpotUrl(spot.id!);

// Share via system dialog
await UrlService.shareSpot(spot.id!, spot.name);

// Copy to clipboard
await UrlService.copySpotUrl(spot.id!);
```

### Opening a Spot from URL
```dart
// Extract spot ID
final spotId = UrlService.extractSpotIdFromUrl(url);

// Navigate to spot
if (spotId != null) {
  context.go('/spot/$spotId');
}
```

## Security Considerations

1. **Public Access**: Spot URLs are publicly accessible
2. **Rate Limiting**: Consider implementing rate limiting for spot fetching
3. **Content Moderation**: Ensure spots comply with community guidelines
4. **Privacy**: Be mindful of location data exposure

## Future Enhancements

1. **Custom Domains**: Allow users to set custom subdomains
2. **URL Analytics**: Track click-through rates and sharing metrics
3. **Social Media Integration**: Direct sharing to social platforms
4. **QR Code Generation**: Generate QR codes for spot URLs
5. **Offline Support**: Cache spot data for offline viewing

## Troubleshooting

### Common Issues

1. **Deep Links Not Working**
   - Check platform-specific configuration
   - Verify domain ownership and SSL setup
   - Test with different URL formats

2. **Spot Not Found**
   - Verify spot ID exists in Firestore
   - Check Firestore security rules
   - Ensure proper error handling

3. **Sharing Not Working**
   - Check platform permissions
   - Verify share_plus package integration
   - Test on different devices

### Debug Mode
Enable debug logging to troubleshoot URL handling:

```dart
// In your main.dart
if (kDebugMode) {
  print('URL: ${Uri.base}');
  print('Path: ${Uri.base.path}');
}
```

### Testing Deep Links Locally

1. **Run the app locally**:
   ```bash
   flutter run -d chrome
   ```

2. **Use the test file**: Open `test_deep_link.html` in your browser

3. **Test different URLs**:
   - `http://localhost:3000/spot/{spotId}`
   - `http://localhost:3000/s/{spotId}`

4. **Check browser console** for debug logs

### Recent Fixes

#### Issue: URLs redirecting to root instead of opening spots
**Problem**: The `SplashScreen` was hardcoded to navigate to home/login after 2 seconds, ignoring deep links.

**Solution**: Updated `SplashScreen` to:
- Check for deep links in the current route
- Navigate directly to spot URLs when detected
- Use `go_router` instead of `Navigator.pushReplacement`

**Code Changes**:
```dart
// In SplashScreen._checkAuthStatus()
final currentPath = GoRouterState.of(context).uri.path;

// If we have a spot URL, navigate directly to it
if (currentPath.startsWith('/spot/') || currentPath.startsWith('/s/')) {
  context.go(currentPath);
  return;
}
```

## Support

For issues related to the URL system:
1. Check this documentation
2. Review platform-specific logs
3. Test with different URL formats
4. Verify Firebase configuration
5. Use the test file for local debugging
6. Check browser console for debug logs
