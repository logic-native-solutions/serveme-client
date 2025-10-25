import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Make sure you have this setup
import 'package:http/http.dart' as http;
import 'package:client/test_data/address_data.dart';


class ManualAddressEntryScreen extends StatefulWidget {
  final LatLng? initialCoordinates;

  const ManualAddressEntryScreen({super.key, this.initialCoordinates});

  @override
  State<ManualAddressEntryScreen> createState() => _ManualAddressEntryScreenState();
}

class _ManualAddressEntryScreenState extends State<ManualAddressEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _streetCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();

  @override
  void dispose() {
    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _provinceCtrl.dispose();
    _postalCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    final street = _streetCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    final province = _provinceCtrl.text.trim();
    final postal = _postalCtrl.text.trim();
    final description = [street, city, province, postal].where((s) => s.isNotEmpty).join(', ');

    // Return a payload similar to AddressScreen's Confirm button so ProfileScreen can consume it.
    Navigator.pop(context, {
      'description': description,
      // No coordinates for manual entry unless you later add geocoding.
      // Leave them out so callers can treat them as optional.
    });
  }

  InputDecoration _decoration(BuildContext context, String label) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: theme.colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Enter Address Manually',
            style: TextStyle(color: Colors.black),
        ),
        backgroundColor: const Color(0xFFF8FCF7),
        iconTheme: const IconThemeData(
          color: Colors.black,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _streetCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration(context, 'Street'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Street is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cityCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration(context, 'City'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'City is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _provinceCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration(context, 'Province'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Province is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _postalCtrl,
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.number,
                  decoration: _decoration(context, 'Postal Code'),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Postal code is required';
                    if (t.length < 4 || t.length > 6) return 'Enter a valid postal code';
                    return null;
                  },
                  onFieldSubmitted: (_) => _confirm(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _confirm,
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Small helper for predictions - Your existing class is good
class _PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  _PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory _PlacePrediction.fromJson(Map<String, dynamic> j) {
    final s = j['structured_formatting'] ?? {};
    return _PlacePrediction(
      placeId: j['place_id'] as String, // Ensure type safety
      description: j['description'] as String? ?? '',
      mainText: s['main_text'] as String? ??
          (j['description'] as String? ?? ''),
      secondaryText: s['secondary_text'] as String? ?? '',
    );
  }
}

// Assuming InfoTile is a widget you have defined elsewhere.
// If not, here's a basic placeholder:
class InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const InfoTile({super.key,
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ListTile(
      // Align with provider section tiles: add horizontal padding and use a
      // neutral container for the leading icon for consistent layout.
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: cs.onSurfaceVariant),
      ),
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: value,
      trailing: trailing,
      onTap: onTap,
    );
  }
}


// Assuming SectionTitle is a widget you have defined elsewhere.
// If not, here's a basic placeholder:
class SectionTitle extends StatelessWidget {
  final String title;

  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: Theme
            .of(context)
            .textTheme
            .titleLarge,
      ),
    );
  }
}


class AddressScreen extends StatelessWidget {
  const AddressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Address',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: false,
        backgroundColor: const Color(0xFFF8FCF7),
        iconTheme: const IconThemeData(
          color: Colors.black,
        ),
      ),
      body: SafeArea(
          child: _AddressScreenBody()), // Changed to _AddressScreenBody
    );
  }
}

class _AddressScreenBody extends StatefulWidget {
  // Renamed from _AddressScreen
  const _AddressScreenBody();

  @override
  State<_AddressScreenBody> createState() => _AddressScreenBodyState();
}

class _AddressScreenBodyState extends State<_AddressScreenBody> {
  // -------------------- Config --------------------
  // Ensure you have flutter_dotenv setup and your .env file with GOOGLE_MAPS_API_KEY
  late final String _kGoogleApiKey;

  // -------------------- Search state --------------------
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<_PlacePrediction> _predictions = [];
  bool _isLoadingPredictions = false;
  bool _showPredictionsList = false;

  // -------------------- Map state --------------------
  GoogleMapController? _mapController;
  static const LatLng _defaultCenter = LatLng(
      -25.7479, 28.2293); // Pretoria CBD
  LatLng _currentMapCenter = _defaultCenter; // For the map's current center
  Marker? _selectedPin;

  // -------------------- Selected Address State --------------------
  String? _currentlySelectedAddressDescription; // To display the chosen address
  LatLng? _currentlySelectedLatLng; // To store coordinates of the selected address

  @override
  void initState() {
    super.initState();
    // It's good practice to load environment variables in initState
    // or ensure they are loaded before the widget tree is built.
    // For this example, assuming dotenv is loaded before runApp.
    _kGoogleApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? "YOUR_API_KEY_HERE";
    if (_kGoogleApiKey == "YOUR_API_KEY_HERE") {
      // Consider showing an error or logging if the key is missing
      print("Warning: GOOGLE_MAPS_API_KEY is not set in .env file.");
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    _mapController?.dispose(); // Dispose map controller
    super.dispose();
  }

  // -------------------- Places: autocomplete --------------------
  void _onSearchChanged(String v) {
    setState(() {
      _query = v;
      _isLoadingPredictions = true;
      _showPredictionsList = v.isNotEmpty; // Show list if typing
      if (v.isEmpty) {
        _predictions = [];
        _isLoadingPredictions = false;
      }
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (_query
          .trim()
          .isEmpty) {
        setState(() {
          _predictions = [];
          _isLoadingPredictions = false;
        });
        return;
      }
      final results = await _fetchPredictions(_query);
      setState(() {
        _predictions = results;
        _isLoadingPredictions = false;
      });
    });
  }

  Future<List<_PlacePrediction>> _fetchPredictions(String input) async {
    // Restrict to South Africa (ZA)
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': input,
        'key': _kGoogleApiKey,
        'components': 'country:za',
        'sessiontoken': DateTime
            .now()
            .millisecondsSinceEpoch
            .toString(), // Recommended for billing
      },
    );
    try {
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        if (data['status'] == 'OK') {
          final preds = (data['predictions'] as List?) ?? [];
          return preds
              .map((p) => _PlacePrediction.fromJson(p as Map<String, dynamic>))
              .toList();
        } else {
          print("Google Places API Error: ${data['status']}");
          print("Error message: ${data['error_message']}");
          return [];
        }
      } else {
        print("HTTP Error fetching predictions: ${res.statusCode}");
        return [];
      }
    } catch (e) {
      print("Exception fetching predictions: $e");
      return [];
    }
  }

  // -------------------- Places: details -> latLng --------------------
  Future<LatLng?> _fetchPlaceLatLng(String placeId) async {
    final uri = Uri.https(
        'maps.googleapis.com', '/maps/api/place/details/json', {
      'place_id': placeId,
      'key': _kGoogleApiKey,
      'fields': 'geometry,formatted_address', // Get formatted_address too
      'sessiontoken': DateTime
          .now()
          .millisecondsSinceEpoch
          .toString(), // Use same session token
    });
    try {
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        if (data['status'] == 'OK' && data['result'] != null) {
          final loc = data['result']?['geometry']?['location'];
          final formattedAddress = data['result']?['formatted_address'] as String?;
          if (loc != null) {
            // Update the selected address description
            if (formattedAddress != null) {
              _searchCtrl.text =
                  formattedAddress; // Update search bar with full address
              _currentlySelectedAddressDescription = formattedAddress;
            }
            return LatLng(
                (loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble());
          }
        } else {
          print("Google Place Details API Error: ${data['status']}");
          print("Error message: ${data['error_message']}");
        }
        return null;
      } else {
        print("HTTP Error fetching place details: ${res.statusCode}");
        return null;
      }
    } catch (e) {
      print("Exception fetching place details: $e");
      return null;
    }
  }

  // -------------------- Map helpers --------------------
  Future<void> _moveCameraAndSetPin(LatLng target,
      {String? addressDescription}) async {
    _currentMapCenter = target;
    _currentlySelectedLatLng = target;
    if (addressDescription != null) {
      _currentlySelectedAddressDescription = addressDescription;
      _searchCtrl.text = addressDescription; // Update search bar
    }

    _selectedPin = Marker(
      markerId: const MarkerId('selectedPin'),
      position: target,
      infoWindow: InfoWindow(title: addressDescription ?? 'Selected Location'),
      draggable: true,
      // Allow users to fine-tune by dragging
      onDragEnd: (newPosition) {
        setState(() {
          _currentMapCenter = newPosition;
          _currentlySelectedLatLng = newPosition;
          // Optionally, you could try to reverse geocode newPosition to get an address
          // For now, let's clear the text field if the pin is dragged to an unknown spot
          _searchCtrl.clear();
          _currentlySelectedAddressDescription = "Custom location";
        });
      },
    );
    setState(() {}); // Update UI with pin and potentially new text

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 16.5)),
    );
  }

  void _onPredictionTap(_PlacePrediction p) async {
    FocusScope.of(context).unfocus(); // Hide keyboard
    setState(() {
      _isLoadingPredictions = true; // Show loading while fetching details
      _showPredictionsList = false; // Hide predictions list
    });

    final latLng = await _fetchPlaceLatLng(p.placeId);
    setState(() => _isLoadingPredictions = false);

    if (latLng != null) {
      // _fetchPlaceLatLng now updates _searchCtrl.text and _currentlySelectedAddressDescription
      await _moveCameraAndSetPin(latLng, addressDescription: p.description);
    } else {
      // Handle error, e.g., show a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not fetch location details.')),
      );
    }
  }

  void _onPreviousAddressTap(Map<String, dynamic> addressData) {
    final String description = addressData['description'] as String;
    final LatLng coords = LatLng(
        addressData['lat'] as double, addressData['lng'] as double);

    setState(() {
      _searchCtrl.text = description;
      _currentlySelectedAddressDescription = description;
      _currentlySelectedLatLng = coords;
      _predictions = []; // Clear any stale predictions
      _showPredictionsList = false;
    });
    _moveCameraAndSetPin(coords, addressDescription: description);
    // Example: If you want to "select" this and pop the screen:
    // Navigator.pop(context, {'description': description, 'latlng': coords});
  }

  void _addAddressManually() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ManualAddressEntryScreen(
              initialCoordinates: _currentlySelectedLatLng ?? _currentMapCenter,
            ),
      ),
    ).then((manualAddressResult) {
      if (manualAddressResult is Map && manualAddressResult['description'] is String) {
        final desc = manualAddressResult['description'] as String;
        setState(() {
          _currentlySelectedAddressDescription = desc;
          _searchCtrl.text = desc;
          _predictions = [];
          _showPredictionsList = false;
          _selectedPin = null; // No coordinates from manual entry
        });
        // Bubble the selection up to the caller (e.g., ProfileScreen)
        Navigator.pop(context, manualAddressResult);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector( // To dismiss keyboard when tapping outside text fields
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          // Make children take full width
          children: [
            // -------------------- Search bar --------------------
            TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search address...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isLoadingPredictions
                    ? const Padding(
                  padding: EdgeInsets.all(10.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : _searchCtrl.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _query = '';
                      _predictions = [];
                      _showPredictionsList = false;
                      // Optionally reset map to default or clear selected pin
                      // _selectedPin = null;
                      // _currentlySelectedAddressDescription = null;
                      // _mapController?.animateCamera(CameraUpdate.newLatLng(_defaultCenter));
                    });
                  },
                )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            // Predictions (overlay-style list under the field)
            if (_showPredictionsList && _predictions.isNotEmpty)
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(top: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  // Use ClampingScrollPhysics
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _predictions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = _predictions[i];
                    return ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(p.mainText),
                      subtitle: Text(
                        p.secondaryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _onPredictionTap(p),
                    );
                  },
                ),
              )
            else
              if (_showPredictionsList && _query.isNotEmpty &&
                  !_isLoadingPredictions && _predictions.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    'No results found for "$_query"',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.hintColor),
                  ),
                ),


            const SizedBox(height: 12),

            // -------------------- Map --------------------
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 300,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _defaultCenter, // Start at default
                    zoom: 12, // Zoom out a bit initially
                  ),
                  onMapCreated: (c) {
                    _mapController = c;
                    // If there's an initial selected address, move map to it
                    if (_currentlySelectedLatLng != null) {
                      _moveCameraAndSetPin(_currentlySelectedLatLng!,
                          addressDescription: _currentlySelectedAddressDescription);
                    }
                  },
                  markers: {_selectedPin}.whereType<Marker>().toSet(),
                  onTap: (pos) async {
                    // When map is tapped, update pin and try to get address (optional)
                    // For now, just moves the pin. You might want to reverse geocode `pos`
                    // to get an address for it.
                    _searchCtrl.clear(); // Clear search as it's a new point
                    _currentlySelectedAddressDescription =
                    "Selected on map"; // Generic description
                    await _moveCameraAndSetPin(pos,
                        addressDescription: _currentlySelectedAddressDescription);
                  },
                  myLocationButtonEnabled: true,
                  // Good to have
                  myLocationEnabled: true,
                  // Ask for permission
                  compassEnabled: false,
                  mapToolbarEnabled: false,
                  zoomControlsEnabled: true, // Useful for map interaction
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (_currentlySelectedAddressDescription != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  _currentlySelectedAddressDescription!,
                  style: theme.textTheme.titleSmall,
                  textAlign: TextAlign.center,
                ),
              ),


            const SizedBox(height: 12),


            const SectionTitle(title: 'Previous Addresses'),
            // Make sure SectionTitle is defined

            // -------------------- Previous addresses --------------------
            if (previousAddresses.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('No previous addresses saved.',
                    textAlign: TextAlign.center),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                // Important in a SingleChildScrollView
                physics: const NeverScrollableScrollPhysics(),
                // List itself shouldn't scroll
                itemCount: previousAddresses.length,
                itemBuilder: (context, index) {
                  final addrData = previousAddresses[index];
                  final String addrDescription = addrData['description'] as String;
                  return InfoTile( // Make sure InfoTile is defined
                    icon: Icons.history, // Changed icon
                    label: addrDescription,
                    onTap: () => _onPreviousAddressTap(addrData),
                  );
                },
              ),

            const SizedBox(height: 24),
            // Button to confirm the selected address
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme
                    .of(context)
                    .primaryColor,
                foregroundColor: Theme
                    .of(context)
                    .colorScheme
                    .onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: (_currentlySelectedLatLng != null &&
                  _currentlySelectedAddressDescription != null)
                  ? () {
                // TODO: Use the selected address
                // For example, return it to the previous screen:
                Navigator.pop(context, {
                  'description': _currentlySelectedAddressDescription,
                  'latitude': _currentlySelectedLatLng!.latitude,
                  'longitude': _currentlySelectedLatLng!.longitude,
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(
                      'Selected: $_currentlySelectedAddressDescription')),
                );
              }
                  : null, // Button disabled if no address is fully selected
              child: const Text('Confirm Address'),
            ),
            const SizedBox(height: 12),

            // -------------------- Manual add --------------------
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: const Text('Add Address Manually'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Theme
                        .of(context)
                        .primaryColor,
                    foregroundColor: Theme
                        .of(context)
                        .colorScheme
                        .onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)
                ),
                onPressed: _addAddressManually,
              ),
            ),

          ],
        ),
      ),
    );
  }
}