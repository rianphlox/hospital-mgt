# CareLog Flutter App - Login Credentials

The app now uses **email/password authentication** instead of Google Sign-In.

## Test User Accounts

### Admin User
- **Email:** `admin@carelog.com`
- **Password:** `admin123`
- **Firebase UID:** `TnQDj0cOtMVzt6CjePD3Rm9MMa73`
- **Role:** Admin
- **Access:** Full system overview and management

### Cashier User
- **Email:** `cashier@carelog.com`
- **Password:** `cashier123`
- **Firebase UID:** `6o6P81i54XeWoU4mkwX1NPAJkE93`
- **Role:** Cashier
- **Access:** Billing and payment processing

### Nurse User
- **Email:** `nurse@carelog.com`
- **Password:** `nurse123`
- **Firebase UID:** `RQ3OxfxE4SYlgLnwFF15xf3KJxb2`
- **Role:** Nurse
- **Access:** Patient management and treatment logging

## How to Use

1. **Launch the app**: `flutter run`

2. **Login Screen Features:**
   - **Quick Select Dropdown**: Choose from predefined test users
   - **Manual Entry**: Enter email and password manually
   - **Auto-fill**: Selecting from dropdown automatically fills credentials

3. **User Experience:**
   - Each user will see their role-specific dashboard
   - Real-time data synchronization across all sessions
   - Proper authentication and session management

## Firebase Setup

These user accounts need to be created in your Firebase Authentication console with the specified UIDs and email/password combinations. The app will automatically create user profiles in Firestore on first login.

## Security Notes

- These are test credentials for development
- In production, use proper user management
- UIDs are mapped to specific roles in the application
- All data is shared with the React version using the same Firebase backend