class Booking {
  final String jobId;           // Backend job identifier
  final String? assignedProviderId; // Null until assigned
  final String title;
  final String when;
  final bool isUpcoming;
  final String imagePath; // thumbnail from assets
  final String status;    // e.g., 'Upcoming', 'Completed'
  final String price;     // e.g., 'R350' or 'R180/hr'
  final String provider;  // e.g., 'Thabo M.'
  final double? rating;   // optional rating

  const Booking({
    required this.jobId,
    required this.assignedProviderId,
    required this.title,
    required this.when,
    required this.isUpcoming,
    required this.imagePath,
    this.status = '',
    this.price = '',
    this.provider = '',
    this.rating,
  });
}