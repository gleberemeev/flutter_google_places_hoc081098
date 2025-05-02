import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_google_places_hoc081098/flutter_google_places_hoc081098.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';

const kGoogleApiKey = 'AIzaSyAX35jFUW-ElHGkDfDwPO_Q8QQNbH2u64I';

void main() => runApp(const RoutesWidget());

final customTheme = ThemeData(
  primarySwatch: Colors.blue,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSwatch(
    primarySwatch: Colors.blue,
    brightness: Brightness.dark,
    accentColor: Colors.redAccent,
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(4.00)),
    ),
    contentPadding: EdgeInsets.symmetric(
      vertical: 12.50,
      horizontal: 10.00,
    ),
  ),
  useMaterial3: true,
);

class RoutesWidget extends StatelessWidget {
  const RoutesWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      theme: customTheme,
      routes: {
        '/': (_) => const MyApp(),
        '/search': (_) => CustomSearchScaffold(),
      },
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Mode _mode = Mode.overlay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _buildDropdownMenu(),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _handlePressButton,
              child: const Text('Search places'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/search');
              },
              child: const Text('Custom'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownMenu() {
    return DropdownButton<Mode>(
      value: _mode,
      items: const <DropdownMenuItem<Mode>>[
        DropdownMenuItem<Mode>(
          value: Mode.overlay,
          child: Text('Overlay'),
        ),
        DropdownMenuItem<Mode>(
          value: Mode.fullscreen,
          child: Text('Fullscreen'),
        ),
      ],
      onChanged: (m) {
        if (m != null) {
          setState(() => _mode = m);
        }
      },
    );
  }

  Future<void> _handlePressButton() async {
    void onError(object) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unknown error'),
        ),
      );
    }

    // show input autocomplete with selected mode
    // then get the Prediction selected
    final p = await PlacesAutocomplete.show(
      context: context,
      apiKey: kGoogleApiKey,
      onError: onError,
      mode: _mode,
      countries: ['th'],
      resultTextStyle: Theme.of(context).textTheme.titleMedium,
      origin: const LatLng(lat: 13.7563, lng: 100.5018),
      types: [PlaceTypeFilter.ESTABLISHMENT],
    );

    await displayPrediction(p, ScaffoldMessenger.of(context));
  }
}

Future<void> displayPrediction(AutocompletePrediction? p, ScaffoldMessengerState messengerState) async {
  if (p == null) {
    return;
  }

  // get detail (lat/lng)
  final _places = FlutterGooglePlacesSdk(kGoogleApiKey);

  final detail = await _places.fetchPlace(p.placeId, fields: [PlaceField.Location]);
  final geometry = detail.place?.latLng;
  final lat = geometry?.lat;
  final lng = geometry?.lng;

  messengerState.showSnackBar(
    SnackBar(
      content: Text('${p.primaryText} - $lat/$lng'),
    ),
  );
}

// custom scaffold that handle search
// basically your widget need to extends [GooglePlacesAutocompleteWidget]
// and your state [GooglePlacesAutocompleteState]
class CustomSearchScaffold extends PlacesAutocompleteWidget {
  CustomSearchScaffold({Key? key})
      : super(key: key, apiKey: kGoogleApiKey, types: [PlaceTypeFilter.ESTABLISHMENT], countries: ['th']);

  @override
  _CustomSearchScaffoldState createState() => _CustomSearchScaffoldState();
}

class _CustomSearchScaffoldState extends PlacesAutocompleteState {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppBarPlacesAutoCompleteTextField(
          textStyle: null,
          textDecoration: null,
          cursorColor: null,
        ),
      ),
      body: PlacesAutocompleteResult(
        onTap: (p) => displayPrediction(p, ScaffoldMessenger.of(context)),
        logo: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [FlutterLogo()],
        ),
      ),
    );
  }

  @override
  void onResponseError(List<AutocompletePrediction> response) {
    super.onResponseError(response);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unknown error')),
    );
  }

  @override
  void onResponse(List<AutocompletePrediction> response) {
    super.onResponse(response);

    if (response.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Got answer')),
      );
    }
  }
}
