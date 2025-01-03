# Google Sheet Search

A native macOS application that enables quick and efficient searching through Google Sheets data.

## 🚀 Features

- Real-time search through Google Sheets content
- Native macOS interface for seamless performance
- Desktop-optimized experience
- Data retrieval via SwiftSoup and URLImage libraries
- Secure integration with Google Sheets for data management
- Google Forms for user account creation and data input

## 📋 Prerequisites

- macOS 13.3+
- Xcode 13.0+
- Swift 5.0+

## ⚙️ Installation

### For Users
1. Download the latest release from the [Releases](https://github.com/mvb2307/GoogleSheetSearch/releases) page.
2. Open the `.dmg` file.
3. Drag the application to your **Applications** folder.
4. Launch **Google Sheet Search** from your **Applications** folder.

### For Developers
1. Clone the repository:
   ```bash
git clone https://github.com/mvb2307/GoogleSheetSearch.git
   ```
2. Navigate to the project directory:
   ```bash
cd GoogleSheetSearch
   ```
3. Open `GoogleSheetSearch.xcodeproj` in Xcode.
4. Add your Google Sheets URL and relevant configurations in the project settings.

## 🔑 Configuration

1. Create a Google Sheet for data storage.
2. Use Google Forms for data input and user account creation.
3. Ensure proper access permissions for the Google Sheet.
4. Update the relevant URLs in the project configuration.

## 🛠️ Usage

1. Launch the application.
2. Authenticate (if required).
3. Enter your search query in the search bar.
4. View and interact with the search results.

## 💻 Screenshots

[Add screenshots of your macOS app here]

## 🏗️ Architecture

This project follows the MVVM (Model-View-ViewModel) architecture pattern and uses:
- AppKit/SwiftUI for the user interface
- Combine for reactive programming
- SwiftSoup for parsing and extracting sheet data
- URLImage for image rendering

## 📄 Data Handling

- **Google Sheets**: Used for data storage and retrieval.
- **Google Forms**: Used for user account creation and data input.

No Google Sheets API is used in this project.

## 🤝 Contributing

1. Fork the repository.
2. Create your feature branch (`git checkout -b feature/AmazingFeature`).
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4. Push to the branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.

## 📝 License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.

## 👤 Author

**MVB** - [@mvb2307](https://github.com/mvb2307)

## 🙏 Acknowledgments

- SwiftSoup
- URLImage
- Google Sheets
- Google Forms

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

### 🔒 Security Enhancements
- [ ] Secure data storage
- [ ] Cached content encryption
- [ ] Proper authentication flow

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

⭐️ If you find this project helpful, please consider giving it a star!

