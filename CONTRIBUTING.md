# 🤝 Contributing to Parkour.Spot

Thank you for your interest in contributing to Parkour.Spot! This guide will help you get started with development and contributing.

## 🚀 Quick Start for Contributors

### 1. **Fork & Clone**
```bash
# Fork the repository on GitHub
# Then clone your fork
git clone https://github.com/YOUR_USERNAME/Parkour.Spot.git
cd Parkour.Spot

# Add the original repository as upstream
git remote add upstream https://github.com/ORIGINAL_OWNER/Parkour.Spot.git
```

### 2. **Setup Development Environment**
```bash
# Run the setup script
chmod +x setup.sh
./setup.sh

# Or manually:
flutter pub get
```

### 3. **Configure Firebase**
1. **Create a Firebase project** at [Firebase Console](https://console.firebase.google.com/)
2. **Copy env.example to .env**:
   ```bash
   cp env.example .env
   ```
3. **Fill in your Firebase configuration** in `.env`
4. **Run FlutterFire configuration**:
   ```bash
   flutterfire configure
   ```

### 4. **Test the App**
```bash
# Web
flutter run -d web

# Android
flutter run -d android

# iOS (macOS only)
flutter run -d ios
```

## 🏗️ Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── spot.dart            # Parkour spot model
│   ├── user.dart            # User model
│   └── rating.dart          # Rating model
├── services/                 # Business logic
│   ├── auth_service.dart    # Authentication
│   ├── spot_service.dart    # Spot management
│   └── share_service_*.dart # Platform-specific sharing
├── screens/                  # UI screens
│   ├── auth/                # Login/signup
│   ├── spots/               # Spot-related screens
│   └── profile/             # User profile
├── widgets/                  # Reusable components
└── router/                  # Navigation and routing
```

## 🔧 Development Guidelines

### **Code Style**
- Follow [Flutter Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions small and focused

### **State Management**
- Use `Provider` for state management
- Keep business logic in services
- Minimize widget rebuilds

### **Testing**
- Write unit tests for services
- Test UI components with widget tests
- Ensure all new features have tests

### **Platform Support**
- Test on both web and mobile
- Use platform-specific services when needed
- Handle platform differences gracefully

## 🐛 Reporting Issues

### **Before Reporting**
1. Check existing issues for duplicates
2. Try to reproduce on latest version
3. Check if it's a platform-specific issue

### **Issue Template**
```markdown
**Description**: Brief description of the issue

**Steps to Reproduce**:
1. Step 1
2. Step 2
3. Step 3

**Expected Behavior**: What should happen

**Actual Behavior**: What actually happens

**Environment**:
- Flutter version: `flutter --version`
- Platform: Web/Android/iOS
- Browser (if web): Chrome/Firefox/Safari

**Screenshots**: If applicable
```

## 🔄 Pull Request Process

### **Before Submitting**
1. **Test thoroughly** on all platforms
2. **Update documentation** if needed
3. **Add tests** for new features
4. **Check code style** with `flutter analyze`

### **PR Template**
```markdown
**Description**: What this PR does

**Type of Change**:
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Refactoring

**Testing**:
- [ ] Tested on Web
- [ ] Tested on Android
- [ ] Tested on iOS
- [ ] Added/updated tests

**Screenshots**: If UI changes
```

### **Review Process**
1. **Automated checks** must pass
2. **Code review** from maintainers
3. **Testing** on multiple platforms
4. **Documentation** updated if needed

## 🚀 Deployment

### **Local Testing**
```bash
# Use the provided scripts
./scripts/run_local.sh
./scripts/build_development.sh
```

### **Production Build**
```bash
# Web
./scripts/build_production.sh

# Android
flutter build apk --release

# iOS
flutter build ios --release
```

## 📚 Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Flutter Widget Catalog](https://flutter.dev/docs/development/ui/widgets)

## 🆘 Getting Help

- **GitHub Issues**: For bugs and feature requests
- **GitHub Discussions**: For questions and discussions
- **Code Review**: Ask questions in PR comments

## 📄 License

By contributing to Parkour.Spot, you agree that your contributions will be licensed under the same license as the project.

---

**Happy coding! 🏃‍♂️✨**
