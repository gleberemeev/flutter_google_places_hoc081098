import 'package:flutter/material.dart';
import 'package:flutter_google_places_hoc081098/flutter_google_places_hoc081098.dart';
import 'package:flutter_google_places_hoc081098/google_maps_webservice_places.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';

import 'main.dart';

// custom scaffold that handle search
// basically your widget need to extends [GooglePlacesAutocompleteWidget]
// and your state [GooglePlacesAutocompleteState]
class CustomSearchScaffold extends PlacesAutocompleteWidget {
  CustomSearchScaffold({Key? key})
      : super(
          key: key,
          apiKey: kGoogleApiKey,
          countries: ['th'],
          types: [PlaceTypeFilter.ESTABLISHMENT],
        );

  @override
  _CustomSearchScaffoldState createState() => _CustomSearchScaffoldState();
}

class _CustomSearchScaffoldState extends PlacesAutocompleteState {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppBarPlacesAutoCompleteTextField(
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
        textStyle: Theme.of(context).textTheme.titleMedium,
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
