# 🧊 Smart Cold Chain Monitoring Contract

A Clarity smart contract for monitoring temperature-sensitive shipments with automated insurance claims and IoT oracle integration.

## 🚀 Features

- **📦 Shipment Management**: Create and track cold chain shipments with custom temperature thresholds
- **🌡️ Temperature Monitoring**: Real-time temperature recording from authorized IoT oracles
- **🚨 Violation Alerts**: Automatic alerts when temperature breaches occur
- **💰 Insurance Claims**: Automated insurance claim processing for temperature violations
- **🔐 Oracle Authorization**: Secure oracle management for temperature data input
- **📊 Reading History**: Complete temperature reading history with timestamps

## 📋 Contract Functions

### Public Functions

#### `create-shipment`
Creates a new shipment with temperature requirements and insurance coverage.
```clarity
(create-shipment "New York" "Los Angeles" 2 8 u1000)
```

#### `record-temperature`
Records temperature data (only authorized oracles can call this).
```clarity
(record-temperature u1 5)
```

#### `deliver-shipment`
Marks a shipment as delivered (only shipment owner can call this).
```clarity
(deliver-shipment u1)
```

#### `claim-insurance`
Claims insurance for shipments with temperature violations.
```clarity
(claim-insurance u1)
```

#### `authorize-oracle`
Authorizes an oracle to record temperature data (only contract owner).
```clarity
(authorize-oracle 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

#### `revoke-oracle`
Revokes oracle authorization (only contract owner).
```clarity
(revoke-oracle 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

### Read-Only Functions

#### `get-shipment`
Retrieves complete shipment information.
```clarity
(get-shipment u1)
```

#### `get-temperature-reading`
Gets specific temperature reading by shipment and reading ID.
```clarity
(get-temperature-reading u1 u0)
```

#### `get-shipment-reading-count`
Returns total number of temperature readings for a shipment.
```clarity
(get-shipment-reading-count u1)
```

#### `is-oracle-authorized`
Checks if a principal is an authorized oracle.
```clarity
(is-oracle-authorized 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

#### `get-violation-count`
Returns number of temperature violations for a shipment.
```clarity
(get-violation-count u1)
```

#### `is-insurance-eligible`
Checks if a shipment is eligible for insurance claim.
```clarity
(is-insurance-eligible u1)
```

## 🔧 Usage Instructions

### 1. Deploy the Contract
Deploy the contract to your Stacks network using Clarinet:
```bash
clarinet deploy
```

### 2. Authorize Oracles
The contract owner must authorize IoT oracles before they can record temperature data:
```clarity
(contract-call? .smart-cold-chain-monitoring-contract authorize-oracle 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

### 3. Create Shipments
Create shipments with temperature requirements:
```clarity
(contract-call? .smart-cold-chain-monitoring-contract create-shipment "Warehouse A" "Store B" 2 8 u5000)
```

### 4. Monitor Temperature
Authorized oracles record temperature data:
```clarity
(contract-call? .smart-cold-chain-monitoring-contract record-temperature u1 6)
```

### 5. Handle Violations
When temperature violations occur, alerts are automatically triggered and insurance becomes claimable.

### 6. Claim Insurance
Shipment owners can claim insurance for violated shipments:
```clarity
(contract-call? .smart-cold-chain-monitoring-contract claim-insurance u1)
```

## 🏗️ Data Structures

### Shipment
- `owner`: Principal who created the shipment
- `origin`: Starting location
- `destination`: End location
- `min-temp`/`max-temp`: Temperature thresholds (°C)
- `current-temp`: Latest recorded temperature
- `created-at`: Block height when created
- `delivered-at`: Block height when delivered (optional)
- `insurance-amount`: Insurance coverage amount
- `insurance-claimed`: Whether insurance was claimed
- `violation-count`: Number of temperature violations
- `status`: Current shipment status

### Temperature Reading
- `temperature`: Recorded temperature value
- `timestamp`: Block height when recorded
- `oracle`: Principal that recorded the temperature

## 🔒 Security Features

- Only authorized oracles can record temperature data
- Only shipment owners can deliver shipments and claim insurance
- Only contract owner can manage oracle authorization
- Temperature violations are automatically tracked and cannot be manipulated
- Insurance can only be claimed once per shipment

## 🚨 Error Codes

- `u100`: Owner only operation
- `u101`: Not authorized
- `u102`: Invalid temperature
- `u103`: Shipment not found
- `u104`: Shipment already exists
- `u105`: Oracle not authorized
- `u106`: Insurance already claimed
- `u107`: Shipment already delivered

## 🧪 Testing

Run the test suite:
```bash
clarinet test
```

## 📄 License

This project is licensed under the MIT License.
