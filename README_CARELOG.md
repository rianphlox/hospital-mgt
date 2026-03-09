# CareLog Hospital Management System - Flutter Edition

A comprehensive hospital management system built with Flutter and Firebase, converted from the original React application.

## Features

### Role-Based Access Control
- **Nurse Dashboard**: Patient management, treatment logging, and ward operations
- **Cashier Dashboard**: Billing, payment processing, and financial tracking
- **Admin Dashboard**: System overview and management capabilities

### Core Functionality
- **Patient Management**: Add new patients, track admissions, discharge patients
- **Treatment Logging**: Record medications, procedures, and associated costs
- **Billing System**: Track charges, process payments, generate receipts
- **Real-time Data**: Firebase integration for live updates across all devices

## Project Structure

```
lib/
├── config/
│   └── firebase_config.dart       # Firebase configuration
├── models/
│   ├── patient_models.dart        # Patient, Treatment, Payment models
│   └── user_models.dart           # User profile models
├── providers/
│   ├── auth_provider.dart         # Authentication state management
│   └── data_provider.dart         # Data state management
├── screens/
│   ├── admin/
│   │   └── admin_dashboard.dart   # Admin overview screen
│   ├── cashier/
│   │   ├── billing_detail_screen.dart
│   │   └── cashier_dashboard.dart
│   ├── nurse/
│   │   ├── nurse_dashboard.dart
│   │   └── patient_detail_screen.dart
│   ├── dashboard_screen.dart      # Main dashboard router
│   ├── login_screen.dart          # Google authentication
│   └── splash_screen.dart         # Loading screen
├── services/
│   ├── auth_service.dart          # Authentication logic
│   ├── data_service.dart          # Firestore operations
│   └── firebase_service.dart      # Firebase initialization
├── widgets/
│   ├── add_patient_dialog.dart    # Patient admission dialog
│   ├── add_treatment_dialog.dart  # Treatment logging dialog
│   ├── patient_card.dart          # Patient list item widget
│   └── record_payment_dialog.dart # Payment recording dialog
└── main.dart                      # App entry point
```

## Setup Instructions

### Prerequisites
- Flutter SDK (3.35.4 or higher)
- Android Studio or VS Code with Flutter extension
- Firebase project with Firestore and Authentication enabled

### Installation
1. Clone the repository and navigate to the Flutter project:
   ```bash
   cd carelog-hospital-management/carelog_flutter
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure Firebase:
   - The Firebase configuration is already set up in `lib/config/firebase_config.dart`
   - Ensure your Firebase project has the correct configuration

4. Run the app:
   ```bash
   flutter run
   ```

## Key Features Implemented

### Authentication
- Google Sign-In integration
- Role-based access control (Nurse, Cashier, Admin)
- Automatic user profile creation

### Patient Management
- Patient admission with type (In-patient/Out-patient)
- Ward assignment
- Discharge functionality
- Search and filtering capabilities

### Treatment System
- Multiple treatment items per session
- Quick drug selection with preset pricing
- Real-time cost calculation
- Treatment history tracking

### Billing System
- Itemized billing with treatment breakdown
- Multiple payment methods (Cash, Transfer, Card)
- Payment tracking and history
- Balance calculation

### UI/UX Features
- Material Design 3 theming
- Responsive layout
- Smooth animations and transitions
- Consistent color scheme (Emerald green primary)
- Role-specific navigation

## Technology Stack

- **Frontend**: Flutter (Dart)
- **State Management**: Provider pattern
- **Backend**: Firebase Firestore
- **Authentication**: Firebase Auth + Google Sign-In
- **UI Framework**: Material Design 3

## Data Models

### Patient
- Personal information (name, admission number)
- Ward assignment and patient type
- Status tracking (active/discharged)
- Timestamps for admission and discharge

### Treatment
- Associated patient and nurse
- Multiple treatment items with quantities and prices
- Total charge calculation
- Timestamp tracking

### Payment
- Patient and cashier association
- Payment amount and method
- Payment processing timestamps

## Future Enhancements

- PDF generation for receipts and bills
- Detailed financial reporting
- Staff management system
- Inventory tracking
- Push notifications
- Offline support enhancement

## Development Notes

The application follows Flutter best practices:
- Separation of concerns with dedicated service layers
- Reactive UI with Provider state management
- Proper error handling and user feedback
- Consistent theming and styling
- Type-safe data models

## Firebase Security

The app uses Firebase security rules to ensure:
- User authentication requirements
- Role-based data access
- Data validation and integrity
- Real-time synchronization

---

This Flutter application successfully converts the React-based CareLog system to a mobile-first platform while maintaining all core functionality and improving the user experience with native mobile patterns.