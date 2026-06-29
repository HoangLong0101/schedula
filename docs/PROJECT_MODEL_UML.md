# Project Model UML

This document describes the current Dart domain entities, Firestore data models,
and the main relationships between them. The diagrams use Mermaid and render in
GitHub-flavored Markdown.

## Verification Scope

This UML is synced with the current repository code: Dart entities, data models,
Firestore datasources, Cloud Functions, seed/sync scripts, and local
`firestore.rules`.

Live Firestore data still needs a read-only audit with Firebase credentials:

```bash
cd functions
npm run data:audit
```

The local code audit found one important rules mismatch: the app has a
`products` collection in `CatalogDataSource`, but local `firestore.rules` does
not currently define `match /products/{id}`.

## Domain Model

```mermaid
classDiagram
direction LR

class Tenant {
  +String id
  +BusinessInfo businessInfo
}

class AppUser {
  +String id
  +String email
  +String role
  +String tenantId
  +String normalizedRole
  +bool isOwner
  +bool isReceptionist
  +bool isStaff
  +bool canManageTenant
  +bool canManageBookings
}

class BusinessInfo {
  +String name
  +String type
  +String address
  +String phone
  +String website
  +String hoursWeekday
  +String hoursWeekend
  +String description
  +String planTier
  +DateTime? planStartedAt
  +DateTime? planExpiresAt
}

class UserProfile {
  +String name
  +String phone
  +String email
  +String? avatarUrl
  +bool faceIdEnabled
  +bool fingerprintEnabled
  +bool twoFaEnabled
  +String twoFaMethod
}

class StaffMember {
  +String id
  +String name
  +String role
  +StaffStatus status
  +String color
  +int appointments
  +double rating
  +String phone
  +String email
  +List~String~ specialties
  +Map~String, ShiftValue~ shift
}

class Customer {
  +String id
  +String name
  +String phone
  +String email
  +String birthday
  +String notes
  +String allergies
  +String lastVisit
  +int totalVisits
  +String avatar
  +String color
  +CustomerStatus derivedStatus
  +int futureCount
  +int recent30Count
  +int daysSinceLast
  +int? birthdayInDays
  +int? age
  +String? nextApptDate
}

class ServiceItem {
  +String id
  +String tenantId
  +String name
  +int price
  +int duration
  +String category
  +List~String~ resources
}

class ProductItem {
  +String id
  +String tenantId
  +String name
  +int price
  +String unit
  +String category
}

class Equipment {
  +String id
  +String name
  +EquipmentStatus status
  +String location
  +String lastMaintenance
  +int quantity
}

class Booking {
  +String id
  +String tenantId
  +String staffId
  +String customerId
  +String serviceId
  +DateTime startTime
  +DateTime endTime
  +BookingStatus status
  +String? notes
  +String? createdBy
  +DateTime? createdAt
  +DateTime? updatedAt
  +bool? reminder24Sent
  +bool? reminder1hSent
  +String? customerName
  +String? staffName
  +String? serviceName
  +String? paymentStatus
  +String? paymentId
  +int? paymentAmount
  +int? paymentOrderCode
  +String? paymentCheckoutUrl
  +DateTime? paymentPaidAt
}

class Slot {
  +String id
  +String tenantId
  +String staffId
  +DateTime date
  +List~SlotInterval~ intervals
}

class SlotInterval {
  +DateTime startTime
  +DateTime endTime
  +String? bookingId
}

class AppointmentExtraction {
  +Map~String, dynamic~ fields
  +String? intent
  +String? customerName
  +String? phone
  +String? staffName
  +String? serviceName
  +String? sourceText
  +DateTime? appointmentDate
  +String? ocrFullText
}

class AppointmentImageUpload {
  +Uint8List bytes
  +String filename
  +String? contentType
}

class Payment {
  +String id
  +String tenantId
  +String? bookingId
  +String? type
  +String? planTier
  +String? planName
  +String? billingPeriod
  +int? periodMonths
  +DateTime? planExpiresAt
  +int orderCode
  +int amount
  +String description
  +String status
  +String paymentLinkId
  +String checkoutUrl
  +String? qrCode
  +String createdBy
  +DateTime createdAt
  +DateTime updatedAt
  +DateTime? paidAt
}

class SubscriptionPlan {
  +String id
  +String name
  +int price
  +int? yearlyPrice
  +String? period
  +List~String~ features
}

class BookingStatus {
  <<enumeration>>
  pending
  confirmed
  inProgress
  completed
  cancelled
  noShow
}

class StaffStatus {
  <<enumeration>>
  available
  inSession
  absent
}

class ShiftValue {
  <<enumeration>>
  morning
  afternoon
  full
  off
}

class CustomerStatus {
  <<enumeration>>
  active
  followUp
  newCustomer
  recovery
}

class EquipmentStatus {
  <<enumeration>>
  available
  inUse
  maintenance
}

Tenant "1" o-- "1" BusinessInfo : tenants/{tenantId}
Tenant "1" --> "many" AppUser : users.tenantId
Tenant "1" --> "many" StaffMember : users.tenantId, role=staff
Tenant "1" --> "many" Customer : customers.tenantId
Tenant "1" --> "many" ServiceItem : services.tenantId
Tenant "1" --> "many" ProductItem : products.tenantId
Tenant "1" --> "many" Equipment : equipment.tenantId
Tenant "1" --> "many" Booking : bookings.tenantId
Tenant "1" --> "many" Slot : slots.tenantId
Tenant "1" --> "many" Payment : payments.tenantId

Booking "many" --> "1" StaffMember : staffId
Booking "many" --> "1" Customer : customerId
Booking "many" --> "1" ServiceItem : serviceId
Booking "many" --> "0..1" AppUser : createdBy
Booking --> BookingStatus : status
Payment "many" --> "0..1" Booking : bookingId
Payment "many" --> "0..1" SubscriptionPlan : planTier

Slot "many" --> "1" StaffMember : staffId
Slot "1" *-- "many" SlotInterval : intervals
SlotInterval "0..1" --> "1" Booking : bookingId

StaffMember --> StaffStatus : status
StaffMember --> ShiftValue : shift values
Customer --> CustomerStatus : derivedStatus
Equipment --> EquipmentStatus : status
AppointmentExtraction ..> Booking : pre-fills form
AppointmentImageUpload ..> AppointmentExtraction : scan input
```

## Firestore DTO Inheritance

The data layer models subclass domain entities and add mapping logic such as
`fromFirestore`, `toFirestore`, or `toJson`.

```mermaid
classDiagram
direction TB

class AppUser
class UserModel {
  +fromAppUser(AppUser user)
  +fromJson(Map json)
  +toJson()
}

class BusinessInfo
class BusinessInfoModel {
  +fromFirestore(DocumentSnapshot doc)
  +toFirestore()
}

class Booking
class BookingModel {
  +fromFirestore(DocumentSnapshot doc)
  +toFirestore()
}

class Slot
class SlotModel {
  +fromFirestore(DocumentSnapshot doc)
  +toFirestore()
}

class SlotInterval
class SlotIntervalModel {
  +fromJson(Map json)
  +toJson()
}

class ServiceItem
class ServiceModel {
  +fromFirestore(DocumentSnapshot doc)
  +toFirestore()
}

class ProductItem
class ProductModel {
  +fromFirestore(DocumentSnapshot doc)
  +toFirestore()
}

class Customer
class CustomerModel {
  +fromFirestore(DocumentSnapshot doc)
  +toFirestore()
}

class DashboardStats
class DashboardStatsModel {
  +fromAggregates(...)
}

class Equipment
class EquipmentModel {
  +fromFirestore(DocumentSnapshot doc)
  +toFirestore()
}

class StaffMember
class StaffModel {
  +fromFirestore(DocumentSnapshot doc)
  +toFirestore()
}

AppUser <|-- UserModel
BusinessInfo <|-- BusinessInfoModel
Booking <|-- BookingModel
Slot <|-- SlotModel
SlotInterval <|-- SlotIntervalModel
ServiceItem <|-- ServiceModel
ProductItem <|-- ProductModel
Customer <|-- CustomerModel
DashboardStats <|-- DashboardStatsModel
Equipment <|-- EquipmentModel
StaffMember <|-- StaffModel
```

## Dashboard Aggregate Model

Dashboard statistics are not a single Firestore document in the domain layer.
`DashboardStatsModel.fromAggregates` builds them from bookings, staff, customers,
and daily stats queries. The scripts also maintain supporting analytics
collections such as `tenantStatsDaily`, `staffStatsDaily`, `serviceStatsDaily`,
`aiInsights`, `dashboardChartData`, and `weeklyRevenue`.

```mermaid
classDiagram
direction LR

class DashboardStats {
  +int totalBookings
  +int completedBookings
  +int cancelledBookings
  +int noShowBookings
  +int upcomingBookings
  +int totalRevenue
  +List~int~ hourlyBookingCounts
  +List~BookingHeatmapCell~ heatmap
  +List~BookingTrendPoint~ dailyTrend
  +List~DashboardAppointment~ todayAppointments
  +List~StaffAvailability~ staffAvailability
  +CustomerOverview customerOverview
  +double cancellationRate
  +int peakHeatmapCount
  +int peakDailyTrendCount
}

class BookingHeatmapCell {
  +int weekday
  +BookingPeriod period
  +int count
}

class BookingTrendPoint {
  +DateTime date
  +int count
}

class DashboardAppointment {
  +String id
  +String customerName
  +String staffName
  +String serviceName
  +DateTime startTime
}

class StaffAvailability {
  +String id
  +String name
  +String status
  +bool inSession
  +int bookingCount
}

class CustomerOverview {
  +int totalCustomers
  +int returningCustomers
  +int needsFollowUpCustomers
}

class BookingPeriod {
  <<enumeration>>
  morning
  afternoon
  evening
}

DashboardStats "1" *-- "many" BookingHeatmapCell : heatmap
DashboardStats "1" *-- "many" BookingTrendPoint : dailyTrend
DashboardStats "1" *-- "many" DashboardAppointment : todayAppointments
DashboardStats "1" *-- "many" StaffAvailability : staffAvailability
DashboardStats "1" *-- "1" CustomerOverview : customerOverview
BookingHeatmapCell --> BookingPeriod : period
DashboardAppointment ..> Booking : projected from
StaffAvailability ..> StaffMember : projected from
CustomerOverview ..> Customer : aggregated from
```

## Firebase Collections

```mermaid
classDiagram
direction LR

class tenants {
  name
  type
  address
  phone
  website
  hoursWeekday
  hoursWeekend
  description
  planTier
  planStartedAt
  planExpiresAt
  ownerUid
  timezone
}

class users {
  tenantId
  role
  role_title
  specialty
  name
  email
  phone
  status
  avatarUrl
  workingHours
  shift
}

class bookings {
  tenantId
  staffId
  customerId
  serviceId
  startTime
  endTime
  status
  paymentStatus
  paymentId
  customerName
  staffName
  serviceName
}

class customers {
  tenantId
  name
  phone
  email
  visitCount
  lastVisit
  notes
  allergies
}

class services {
  tenantId
  name
  price
  duration
  durationMin
  category
  resources
  equipment
  isActive
}

class products {
  tenantId
  name
  price
  unit
  category
}

class equipment {
  tenantId
  name
  status
  location
  lastMaintenance
  quantity
}

class slots {
  tenantId
  staffId
  date
  intervals
}

class payments {
  tenantId
  bookingId
  type
  planTier
  orderCode
  amount
  status
  paymentLinkId
  checkoutUrl
}

class notifications {
  tenantId
  bookingId
  type
  scheduledAt
  sentAt
  status
}

class tenantStatsDaily {
  tenantId
  date
  totalBookings
  completedBookings
  cancelledBookings
  noShowBookings
  revenue
}

class staffStatsDaily {
  tenantId
  staffId
  date
  totalBookings
  completedBookings
  revenue
}

class serviceStatsDaily {
  tenantId
  serviceId
  date
  totalBookings
  completedBookings
  revenue
}

class subscriptionPlans {
  name
  price
  yearlyPrice
  period
  features
}

tenants "1" --> "many" users : tenantId
tenants "1" --> "many" bookings : tenantId
tenants "1" --> "many" customers : tenantId
tenants "1" --> "many" services : tenantId
tenants "1" --> "many" products : tenantId
tenants "1" --> "many" equipment : tenantId
tenants "1" --> "many" slots : tenantId
tenants "1" --> "many" payments : tenantId
tenants "1" --> "many" notifications : tenantId
tenants "1" --> "many" tenantStatsDaily : tenantId
users "1" <-- "many" bookings : staffId
customers "1" <-- "many" bookings : customerId
services "1" <-- "many" bookings : serviceId
bookings "1" <-- "many" payments : bookingId
bookings "1" <-- "many" notifications : bookingId
users "1" <-- "many" staffStatsDaily : staffId
services "1" <-- "many" serviceStatsDaily : serviceId
subscriptionPlans "1" <-- "many" payments : planTier
```

## Repository Boundaries

```mermaid
classDiagram
direction TB

class AuthRepository {
  <<interface>>
  +watchCurrentUser()
  +signIn(email, password)
  +signInWithGoogle()
  +signOut()
}

class AccountRepository {
  <<interface>>
  +watchBusinessInfo(tenantId)
  +updateBusinessInfo(tenantId, info)
}

class BookingRepository {
  <<interface>>
  +createBooking(params)
  +watchBookings(params)
  +watchSlots(params)
  +updateBookingStatus(params)
  +markBookingPaid(params)
  +cancelBooking(params)
}

class CatalogRepository {
  <<interface>>
  +watchServices(tenantId)
  +watchProducts(tenantId)
  +createService(service)
  +updateService(service)
  +deleteService(id)
  +createProduct(product)
  +updateProduct(product)
  +deleteProduct(id)
}

class CustomerRepository {
  <<interface>>
  +watchCustomers(tenantId)
  +createCustomer(tenantId, customer)
  +updateCustomer(customer)
  +deleteCustomer(id)
}

class DashboardRepository {
  <<interface>>
  +getDashboardStats(params)
}

class EquipmentRepository {
  <<interface>>
  +watchEquipment(tenantId)
  +createEquipment(tenantId, equip)
  +updateEquipment(equip)
  +deleteEquipment(id)
}

class StaffRepository {
  <<interface>>
  +watchStaff(tenantId)
  +createStaff(tenantId, staff)
  +updateStaff(staff)
  +deleteStaff(id)
}

AuthRepository ..> AppUser
AccountRepository ..> BusinessInfo
BookingRepository ..> Booking
BookingRepository ..> Slot
CatalogRepository ..> ServiceItem
CatalogRepository ..> ProductItem
CustomerRepository ..> Customer
DashboardRepository ..> DashboardStats
EquipmentRepository ..> Equipment
StaffRepository ..> StaffMember
```

## Relationship Notes

- `Tenant` is a conceptual Firestore aggregate root (`tenants/{tenantId}`), not a
  dedicated Dart entity. Most tenant-owned documents carry a `tenantId` field.
- Staff profiles are stored in `users` documents with `role = staff`, while
  authenticated users are represented in Dart by `AppUser`.
- `Booking.staffId`, `Booking.customerId`, and `Booking.serviceId` are the core
  scheduling relationships. `customerName`, `staffName`, and `serviceName` are
  denormalized display fields.
- `Slot` is staff/day availability. Each `SlotInterval.bookingId` optionally
  points back to the booking occupying that interval.
- Catalog `ServiceItem.resources` currently stores resource names or ids as
  strings; seed/sync scripts also support the legacy Firestore field
  `equipment`.
- `ProductItem` and `ProductModel` exist in Dart and use the `products`
  collection, but local `firestore.rules` does not yet expose product read/write
  permissions.
- `Payment` and `SubscriptionPlan` are represented in Cloud Functions and
  Firestore, but not currently as Dart domain entities.
- Dashboard models are read-side projections. They summarize bookings, staff,
  and customers rather than owning those records.
