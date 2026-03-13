# CareLog Hospital Database Structure

## 🔥 Firebase Collections to Create

### 1. **users** Collection

Create these documents in the `users` collection:

#### Document: `9mHqVgEqCnOPnntCAAmBubZHrVw2` (Admin)
```json
{
  "uid": "9mHqVgEqCnOPnntCAAmBubZHrVw2",
  "name": "Hospital Administrator",
  "email": "admin@test.com",
  "role": "admin",
  "isActive": true,
  "createdAt": "[current timestamp]"
}
```

#### Document: `tKOyBQpe0ka8dm26OVqLdLMMuSi1` (Cashier)
```json
{
  "uid": "tKOyBQpe0ka8dm26OVqLdLMMuSi1",
  "name": "Sarah Johnson",
  "email": "cashier@test.com",
  "role": "cashier",
  "isActive": true,
  "createdAt": "[current timestamp]"
}
```

#### Document: `nHKclyq9XJfpLSCYhXofGQIyFmj1` (Nurse)
```json
{
  "uid": "nHKclyq9XJfpLSCYhXofGQIyFmj1",
  "name": "Mary Williams",
  "email": "nurse@test.com",
  "role": "nurse",
  "isActive": true,
  "createdAt": "[current timestamp]"
}
```

### 2. **patients** Collection

#### Patient 1: Auto-generated ID
```json
{
  "name": "John Smith",
  "admissionNumber": "ADM001",
  "ward": "General Ward A",
  "type": "In-patient",
  "status": "active",
  "outstandingBalance": 15000,
  "createdAt": "[current timestamp]"
}
```

#### Patient 2: Auto-generated ID
```json
{
  "name": "Emma Davis",
  "admissionNumber": "ADM002",
  "ward": "Pediatric Ward",
  "type": "In-patient",
  "status": "active",
  "outstandingBalance": 0,
  "createdAt": "[current timestamp]"
}
```

#### Patient 3: Auto-generated ID
```json
{
  "name": "Michael Brown",
  "admissionNumber": "OUT001",
  "ward": "Outpatient Clinic",
  "type": "Out-patient",
  "status": "active",
  "outstandingBalance": 8500,
  "createdAt": "[current timestamp]"
}
```

### 3. **Sub-collections under patients**

For Patient 1 (John Smith), create these sub-collections:

#### **treatments** sub-collection:

**Treatment 1:**
```json
{
  "patientId": "[Patient 1 ID]",
  "nurseId": "nHKclyq9XJfpLSCYhXofGQIyFmj1",
  "nurseName": "Mary Williams",
  "items": [
    {
      "name": "Normal Saline",
      "quantity": 2,
      "unitPrice": 1500
    },
    {
      "name": "Ceftriaxone 1g",
      "quantity": 1,
      "unitPrice": 4500
    },
    {
      "name": "Paracetamol IV",
      "quantity": 1,
      "unitPrice": 3000
    }
  ],
  "totalCharge": 10500,
  "timestamp": "[2 days ago]",
  "shift": "morning"
}
```

**Treatment 2:**
```json
{
  "patientId": "[Patient 1 ID]",
  "nurseId": "nHKclyq9XJfpLSCYhXofGQIyFmj1",
  "nurseName": "Mary Williams",
  "items": [
    {
      "name": "Metronidazole (Metro)",
      "quantity": 1,
      "unitPrice": 1200
    },
    {
      "name": "Vitamin B Complex",
      "quantity": 1,
      "unitPrice": 1000
    }
  ],
  "totalCharge": 2200,
  "timestamp": "[1 day ago]",
  "shift": "evening"
}
```

For Patient 2 (Emma Davis):

#### **treatments** sub-collection:
```json
{
  "patientId": "[Patient 2 ID]",
  "nurseId": "nHKclyq9XJfpLSCYhXofGQIyFmj1",
  "nurseName": "Mary Williams",
  "items": [
    {
      "name": "Amoxicillin",
      "quantity": 1,
      "unitPrice": 800
    },
    {
      "name": "Vitamin C",
      "quantity": 1,
      "unitPrice": 800
    }
  ],
  "totalCharge": 1600,
  "timestamp": "[current timestamp]",
  "shift": "morning"
}
```

#### **payments** sub-collection:
```json
{
  "patientId": "[Patient 2 ID]",
  "cashierId": "tKOyBQpe0ka8dm26OVqLdLMMuSi1",
  "cashierName": "Sarah Johnson",
  "amount": 1600,
  "paymentMethod": "Cash",
  "paymentType": "full",
  "timestamp": "[current timestamp]"
}
```

For Patient 3 (Michael Brown):

#### **treatments** sub-collection:
```json
{
  "patientId": "[Patient 3 ID]",
  "nurseId": "nHKclyq9XJfpLSCYhXofGQIyFmj1",
  "nurseName": "Mary Williams",
  "items": [
    {
      "name": "X-Ray",
      "quantity": 1,
      "unitPrice": 8000
    },
    {
      "name": "Blood Test",
      "quantity": 1,
      "unitPrice": 3000
    }
  ],
  "totalCharge": 11000,
  "timestamp": "[current timestamp]",
  "shift": "afternoon"
}
```

#### **payments** sub-collection:
```json
{
  "patientId": "[Patient 3 ID]",
  "cashierId": "tKOyBQpe0ka8dm26OVqLdLMMuSi1",
  "cashierName": "Sarah Johnson",
  "amount": 2500,
  "paymentMethod": "Transfer",
  "paymentType": "partial",
  "originalBillAmount": 11000,
  "notes": "Patient requested partial payment due to financial constraints",
  "timestamp": "[current timestamp]"
}
```

## 🚀 Quick Setup Instructions

1. Go to Firebase Console → Firestore Database
2. Create each collection and document as shown above
3. Replace `[current timestamp]` with actual Firebase timestamps
4. Replace `[Patient X ID]` with the actual patient document IDs

## 📱 Test Data Summary

**Users created:**
- Admin: admin@test.com / test123
- Cashier: cashier@test.com / test123
- Nurse: nurse@test.com / test123

**Patients created:**
- John Smith (ADM001) - ₦15,000 outstanding
- Emma Davis (ADM002) - ₦0 outstanding (paid in full)
- Michael Brown (OUT001) - ₦8,500 outstanding (partial payment)

This gives you a realistic dataset to test all app features!