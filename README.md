# CareLog Hospital Management System

A comprehensive Flutter-based hospital management system designed for efficient patient care, treatment tracking, and billing management. Built with Firebase for real-time data synchronization and role-based access control.

## 🏥 Features

### 👩‍⚕️ Nurse Dashboard
- **Patient Management**: Add new patients with admission numbers and ward assignments
- **Treatment Logging**: Record medications, procedures, and services with categorized drug selection
- **Real-time Updates**: Instant synchronization across all connected devices
- **Shift Integration**: Track treatments across different nursing shifts

### 💰 Cashier Dashboard
- **Billing Management**: Generate bills from nurse-logged treatments
- **Payment Processing**: Support for multiple payment methods (Cash, Transfer, Card)
- **Partial Payments**: Allow patients to pay partial amounts with outstanding balance tracking
- **PDF Receipts**: Professional receipts with hospital branding and proper currency formatting
- **Treatment Visibility**: View all treatments and medications administered to patients

### 👨‍💼 Admin Dashboard
- **User Management**: Control access for nurses, cashiers, and administrators
- **Debt Forgiveness**: Authority to forgive outstanding patient balances
- **System Analytics**: Overview of hospital operations and financial metrics
- **Audit Trail**: Track all system activities and modifications

### 💳 Advanced Payment System
- **Full & Partial Payments**: Flexible payment options for patients
- **Outstanding Balance Tracking**: Balances persist across visits for years
- **Multiple Payment Methods**: Cash, bank transfer, and card payments
- **Payment History**: Complete transaction history for each patient
- **Debt Management**: Admin-controlled debt forgiveness functionality

## 🛠️ Technical Stack

- **Frontend**: Flutter/Dart with Material Design
- **Backend**: Firebase (Firestore, Authentication)
- **State Management**: Provider pattern
- **PDF Generation**: Professional receipts with Unicode support
- **Real-time Sync**: Firestore real-time listeners
- **Security**: Role-based authentication and access control

## 📱 Supported Platforms

- Android (Primary target)
- iOS
- Web
- Windows
- macOS
- Linux

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (>= 3.9.2)
- Android Studio or VS Code
- Firebase project setup
- Android/iOS device or emulator

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/rianphlox/hospital-mgt.git
   cd hospital-mgt
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Enable Firestore Database and Authentication
   - Download `google-services.json` for Android
   - Copy the template file `android/app/google-services.json.template` to `android/app/google-services.json`
   - Replace the placeholder values with your actual Firebase configuration
   - Update Firebase configuration in `lib/config/firebase_config.dart` if needed

4. **Run the application**
   ```bash
   flutter run
   ```

### Default Login Credentials

Check `LOGIN_CREDENTIALS.md` for default user accounts.

## 📋 Key Models

### Patient
```dart
class Patient {
  final String id;
  final String name;
  final String admissionNumber;
  final String ward;
  final PatientType type; // In-patient/Out-patient
  final PatientStatus status; // Active/Discharged
  final int outstandingBalance; // Persistent across visits
}
```

### Treatment
```dart
class Treatment {
  final String patientId;
  final String nurseId;
  final List<TreatmentItem> items; // Medications/procedures
  final int totalCharge;
  final DateTime timestamp;
}
```

### Payment
```dart
class Payment {
  final String patientId;
  final String cashierId;
  final int amount;
  final PaymentType paymentType; // Full/Partial
  final String paymentMethod; // Cash/Transfer/Card
  final int? originalBillAmount; // For partial payments
}
```

## 🔐 User Roles & Permissions

| Role | Permissions |
|------|-------------|
| **Nurse** | Add patients, log treatments, view patient details |
| **Cashier** | View treatments, process payments, generate receipts, discharge patients |
| **Admin** | All permissions + user management + debt forgiveness |

## 🏗️ Project Structure

```
lib/
├── config/           # Firebase and app configuration
├── models/           # Data models (Patient, Treatment, Payment)
├── providers/        # State management (Auth, Data)
├── screens/          # UI screens for each role
├── services/         # Firebase services and API calls
└── widgets/          # Reusable UI components
```

## 🔧 Build & Deployment

### Debug Build
```bash
flutter build apk --debug
```

### Release Build
```bash
flutter build apk --release
```

### Optimized Build (Recommended)
```bash
flutter build apk --split-per-abi
```
This creates separate APKs for different architectures, reducing file size.

## 📊 Key Features in Detail

### Partial Payment System
- Patients can pay any amount up to their outstanding balance
- Remaining balance automatically calculated and stored
- Outstanding balances persist across multiple visits
- Admin approval required for debt forgiveness

### Real-time Synchronization
- All data changes sync instantly across devices
- Nurses see treatment updates immediately
- Cashiers receive real-time billing information
- No data loss with offline capability (coming soon)

### Professional PDF Receipts
- Hospital branding with logo
- Proper currency formatting (Nigerian Naira ₦)
- Itemized treatment breakdown
- Payment history and outstanding balances

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-feature`)
3. Commit changes (`git commit -am 'Add new feature'`)
4. Push to branch (`git push origin feature/new-feature`)
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For support and questions:
- Create an issue in the GitHub repository
- Contact the development team
- Check the documentation in the `/docs` folder

## 🎯 Future Enhancements

- [ ] Inventory management system
- [ ] Appointment scheduling
- [ ] Laboratory integration
- [ ] Insurance claims processing
- [ ] Mobile app notifications
- [ ] Advanced reporting and analytics
- [ ] Offline mode support
- [ ] Multi-language support

---

**CareLog Hospital Management System** - Streamlining healthcare operations with modern technology.