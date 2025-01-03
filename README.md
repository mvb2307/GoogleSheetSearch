# Google Sheet Search

A native macOS application that enables quick and efficient searching through Google Sheets data.

## 🚀 Features

- Search through Google Sheets content in real-time
- Native macOS interface
- Secure Google Sheets API implementation
- Desktop-optimized experience

## 📋 Prerequisites

- macOS 13.3+
- Xcode 13.0+
- Swift 5.0+

## ⚙️ Installation

### For Users
1. Download the latest release from the [Releases](https://github.com/mvb2307/GoogleSheetSearch/releases) page
2. Open the .dmg file
3. Drag the application to your Applications folder
4. Launch Google Sheet Search from your Applications folder

### For Developers
1. Clone the repository
   bash
git clone https://github.com/mvb2307/GoogleSheetSearch.git

2. Navigate to the project directory
   bash
cd GoogleSheetSearch


3. Open `GoogleSheetSearch.xcodeproj` in Xcode

4. Add your Google Sheets API credentials in `GoogleService-Info.plist`

## 🔑 Configuration

1. Create a project in Google Cloud Console
2. Enable Google Sheets API
3. Create credentials (OAuth 2.0 Client ID)
4. Download and add the credentials file to your project
5. Update the bundle identifier in Xcode to match your Google Cloud Console settings

## 🛠️ Usage

1. Launch the application
2. Authenticate with Google (first time only)
3. Enter your search query in the search bar
4. View and interact with search results

## 💻 Screenshots

[Add screenshots of your macOS app here]

## 🏗️ Architecture

This project follows the MVVM (Model-View-ViewModel) architecture pattern and uses:
- AppKit/SwiftUI for the user interface
- Combine for reactive programming
- Google Sheets API for data fetching

## 📄 API Reference

The application uses the following Google Sheets API endpoints:
- `spreadsheets.get`
- `spreadsheets.values.get`

For more information, visit [Google Sheets API Documentation](https://developers.google.com/sheets/api)

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## 👤 Author

MVB - [@mvb2307](https://github.com/mvb2307)

## 🙏 Acknowledgments

- Google Sheets API
- Swift Package Manager
- [Any other libraries or resources used]

## 📞 Support

For support, please create an issue in the GitHub repository.

## 🗺️ Detailed Roadmap

### 🔍 Search Filters
- [ ] Search by specific columns
- [ ] Advanced filtering options (date ranges, numeric ranges)
- [ ] Regex search support

### 🎨 User Interface Enhancements
- [ ] Search history
- [ ] Search suggestions
- [ ] Favorites system for frequently accessed sheets
- [ ] Dark/light mode toggle

### 💾 Data Management
- [ ] Offline search results caching
- [ ] Export functionality (CSV, PDF)
- [ ] Batch operations for multiple sheets
- [ ] Search results sorting capabilities

### 📑 Sheet Management
- [ ] Multiple Google Sheets management
- [ ] Sheet preview functionality
- [ ] Quick-access bookmarks for specific ranges

### 🔄 Integration Features
- [ ] Share functionality
- [ ] Real-time collaboration features
- [ ] Sheet update notifications
- [ ] Integration with other Google services (Drive, Docs)

### ⚡ Performance Optimization
- [ ] Pagination for large datasets
- [ ] Request caching
- [ ] Search algorithm optimization
- [ ] Background fetch for large sheets

### 🏗️ Code Architecture
- [ ] Enhanced MVVM architecture implementation
- [ ] Dependency injection
- [ ] Improved error handling
- [ ] Comprehensive unit tests
- [ ] Proper logging system

### 🔒 Security Enhancements
- [ ] OAuth 2.0 authentication
- [ ] Secure API key storage
- [ ] Cached content encryption
- [ ] API rate limiting

### ♿ Accessibility
- [ ] VoiceOver support
- [ ] Dynamic type implementation
- [ ] Keyboard shortcuts
- [ ] Improved color contrast

### 👨‍💻 Developer Experience
- [ ] Comprehensive documentation
- [ ] SwiftLint integration
- [ ] CI/CD pipeline
- [ ] Development guidelines

## Current Status

The application is currently in active development. Features will be implemented based on priority and community feedback. Progress can be tracked through our [Issues](https://github.com/mvb2307/GoogleSheetSearch/issues) page.

## Contributing

We welcome contributions to help implement any of the planned features. Please check our [Contributing Guidelines](CONTRIBUTING.md) for more information on how to get started.

⭐️ If you find this project helpful, please consider giving it a star!

