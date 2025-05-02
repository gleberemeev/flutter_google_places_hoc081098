import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc_pattern/flutter_bloc_pattern.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:listenable_stream/listenable_stream.dart';
import 'package:rxdart_ext/single.dart';
import 'package:rxdart_ext/state_stream.dart';

class PlacesAutocompleteWidget extends StatefulWidget {
  /// The API key to use for the Places API.
  final String apiKey;

  /// The mode of the autocomplete widget.
  final Mode mode;

  /// The hint text to show in the search field.
  /// Default is 'Search'.
  final String? hint;

  /// The initial text to show in the search field.
  final String? startText;

  /// The BorderRadius used for the dialog in [Mode.overlay].
  final BorderRadius? overlayBorderRadius;

  /// The origin point from which to calculate straight-line distance
  /// to the destination (returned as distance_meters).
  /// If this value is omitted, straight-line distance will not be returned.
  ///
  /// See [autocomplete docs](https://developers.google.com/maps/documentation/places/web-service/autocomplete#origin).
  final LatLng? origin;

  /// You can restrict results from a Place Autocomplete request
  /// to be of a certain type by passing the types parameter.
  ///
  /// This parameter specifies a type or a type collection, as listed in Place Types.
  /// If nothing is specified, all types are returned.
  ///
  /// See [autocomplete docs](https://developers.google.com/maps/documentation/places/web-service/autocomplete#types).
  final List<PlaceTypeFilter> types;

  ///A list of countries to which you would like to restrict your results;
  final List<String> countries;

  /// The logo to display.
  /// Default is the `powered by Google` logo.
  final Widget? logo;

  /// The callback will be called when the autocomplete has an error.
  final ValueChanged<Object>? onError;

  /// The debounce time for the search query.
  /// Default is 300ms.
  final Duration? debounce;

  /// This defines the space between the screen's edges and the dialog.
  /// This is only used in Mode.overlay.
  final EdgeInsets? insetPadding;

  /// The back arrow icon in the leading of the appbar.
  /// This is only used in [Mode.overlay].
  ///
  /// If not provided, the following icons will be used:
  /// - [Icons.arrow_back_ios] will be used on iOS
  /// - [Icons.arrow_back] on other platforms.
  final Widget? backArrowIcon;

  /// Decoration for search text field
  final InputDecoration? textDecoration;

  /// Text style for search text field
  final TextStyle? textStyle;

  /// The color of the cursor of the search text field.
  final Color? cursorColor;

  /// Text style for each result's text.
  final TextStyle? resultTextStyle;

  const PlacesAutocompleteWidget({
    super.key,
    required this.apiKey,
    required this.types,
    required this.countries,
    this.mode = Mode.fullscreen,
    this.hint = 'Search',
    this.insetPadding,
    this.backArrowIcon,
    this.overlayBorderRadius,
    this.origin,
    this.logo,
    this.onError,
    this.startText,
    this.debounce,
    this.textDecoration,
    this.textStyle,
    this.cursorColor,
    this.resultTextStyle,
  });

  @override
  // ignore: no_logic_in_create_state
  State<PlacesAutocompleteWidget> createState() =>
      mode == Mode.fullscreen ? _PlacesAutocompleteScaffoldState() : _PlacesAutocompleteOverlayState();

  static PlacesAutocompleteState of(BuildContext context) =>
      context.findAncestorStateOfType<PlacesAutocompleteState>()!;
}

class _PlacesAutocompleteScaffoldState extends PlacesAutocompleteState {
  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      title: AppBarPlacesAutoCompleteTextField(
        textDecoration: widget.textDecoration,
        textStyle: widget.textStyle,
        cursorColor: widget.cursorColor,
      ),
    );
    final body = PlacesAutocompleteResult(
      onTap: Navigator.of(context).pop,
      logo: widget.logo,
      textStyle: widget.resultTextStyle,
    );
    return Scaffold(
      appBar: appBar,
      body: body,
      backgroundColor: Colors.green,
    );
  }
}

class _PlacesAutocompleteOverlayState extends PlacesAutocompleteState {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final headerTopLeftBorderRadius = widget.overlayBorderRadius?.topLeft ?? const Radius.circular(2);

    final headerTopRightBorderRadius = widget.overlayBorderRadius?.topRight ?? const Radius.circular(2);

    final header = Column(children: <Widget>[
      Material(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: headerTopLeftBorderRadius, topRight: headerTopRightBorderRadius),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              IconButton(
                padding: const EdgeInsets.all(8.0).copyWith(top: 12.0),
                color: theme.brightness == Brightness.light ? Colors.black45 : null,
                icon: _iconBack,
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0, left: 10.0),
                  child: _textField(context),
                ),
              ),
            ],
          )),
      const Divider(),
    ]);

    final bodyBottomLeftBorderRadius = widget.overlayBorderRadius?.bottomLeft ?? const Radius.circular(2);

    final bodyBottomRightBorderRadius = widget.overlayBorderRadius?.bottomRight ?? const Radius.circular(2);

    final container = Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 30.0),
      child: Stack(
        children: <Widget>[
          header,
          Padding(
            padding: const EdgeInsets.only(top: 48.0),
            child: RxStreamBuilder<_SearchState>(
              stream: _state$,
              builder: (context, state) {
                final response = state.predictions;

                if (state.isSearching) {
                  return Stack(
                    alignment: FractionalOffset.bottomCenter,
                    children: <Widget>[_Loader()],
                  );
                } else if (state.text.isEmpty || response.isEmpty) {
                  return Material(
                    color: theme.dialogBackgroundColor,
                    borderRadius: BorderRadius.only(
                      bottomLeft: bodyBottomLeftBorderRadius,
                      bottomRight: bodyBottomRightBorderRadius,
                    ),
                    child: widget.logo ?? const PoweredByGoogleImage(),
                  );
                } else {
                  return SingleChildScrollView(
                    child: Material(
                      borderRadius: BorderRadius.only(
                        bottomLeft: bodyBottomLeftBorderRadius,
                        bottomRight: bodyBottomRightBorderRadius,
                      ),
                      color: theme.dialogBackgroundColor,
                      child: ListBody(
                        children: response
                            .map(
                              (p) => PredictionTile(
                                prediction: p,
                                onTap: Navigator.of(context).pop,
                                textStyle: widget.resultTextStyle,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );

    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return Padding(padding: widget.insetPadding ?? const EdgeInsets.only(top: 8.0), child: container);
    }

    return Padding(
      padding: widget.insetPadding ?? EdgeInsets.zero,
      child: container,
    );
  }

  Widget get _iconBack {
    if (widget.backArrowIcon != null) return widget.backArrowIcon!;
    return Theme.of(context).platform == TargetPlatform.iOS
        ? const Icon(Icons.arrow_back_ios)
        : const Icon(Icons.arrow_back);
  }

  Widget _textField(BuildContext context) => TextField(
        controller: _queryTextController,
        autofocus: true,
        style: widget.textStyle ??
            TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.black87 : null, fontSize: 16.0),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(
            color: Theme.of(context).brightness == Brightness.light ? Colors.black45 : null,
            fontSize: 16.0,
          ),
          border: InputBorder.none,
        ),
      );
}

class _Loader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 2.0),
      child: LinearProgressIndicator(
        color: Theme.of(context).colorScheme.secondary,
      ),
    );
  }
}

class PlacesAutocompleteResult extends StatelessWidget {
  final bool? shouldShow;
  final ValueChanged<AutocompletePrediction> onTap;
  final Widget? logo;
  final Widget? icon;
  final TextStyle? textStyle;
  final String? outOfAreaText;
  final Widget? outOfAreaIcon;
  final TextStyle? outOfAreaTextStyle;

  const PlacesAutocompleteResult(
      {super.key,
      required this.onTap,
      required this.logo,
      this.icon,
      this.textStyle,
      this.shouldShow = true,
      this.outOfAreaText,
      this.outOfAreaIcon,
      this.outOfAreaTextStyle});

  @override
  Widget build(BuildContext context) {
    final state = PlacesAutocompleteWidget.of(context);

    return RxStreamBuilder<_SearchState>(
      stream: state._state$,
      builder: (context, state) {
        final response = state.predictions;

        if (state.predictions.isEmpty && shouldShow == true) {
          return Container(
              margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top, left: 10),
              alignment: Alignment.centerLeft,
              height: 50,
              width: 388,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5)),
              child: Row(
                children: [
                  if (outOfAreaIcon != null) outOfAreaIcon!,
                  if (response.isEmpty == true)
                    Text(outOfAreaText ?? 'Looks like you’re out of our service area.',
                        style: outOfAreaTextStyle ?? const TextStyle(fontWeight: FontWeight.bold))
                ],
              ));
        }
        if (state.text.isEmpty || response.isEmpty) {
          return Stack(
            children: [if (state.isSearching) _Loader(), logo ?? const PoweredByGoogleImage()],
          );
        }
        return shouldShow == true
            ? PredictionsListView(predictions: response, onTap: onTap, icon: icon, textStyle: textStyle)
            : Container();
      },
    );
  }
}

class AppBarPlacesAutoCompleteTextField extends StatefulWidget {
  final InputDecoration? textDecoration;
  final TextStyle? textStyle;
  final Color? cursorColor;
  final Color focusColor;
  final Color borderColor;
  final Color inputContainerColor;
  final Widget? iconRight;
  final Widget? iconLeft;
  final PlacesAutoCompleteTextFieldController? addressController;
  final Function(String value)? onChangeQueryText;
  final Function()? onClearText;

  const AppBarPlacesAutoCompleteTextField(
      {super.key,
      required this.textDecoration,
      required this.textStyle,
      required this.cursorColor,
      this.focusColor = Colors.grey,
      this.borderColor = Colors.grey,
      this.inputContainerColor = Colors.grey,
      this.iconRight,
      this.iconLeft,
      this.addressController,
      this.onChangeQueryText,
      this.onClearText});

  @override
  State<AppBarPlacesAutoCompleteTextField> createState() => _AppBarPlacesAutoCompleteTextFieldState(addressController);
}

class _AppBarPlacesAutoCompleteTextFieldState extends State<AppBarPlacesAutoCompleteTextField> {
  FocusNode inputFocusNode = FocusNode();
  bool isFocus = false;

  _AppBarPlacesAutoCompleteTextFieldState(PlacesAutoCompleteTextFieldController? controller) {
    controller?.setAddressText = setAddressText;
    controller?.requestUnFocus = requestUnFocus;
  }

  @override
  void initState() {
    super.initState();
    inputFocusNode.addListener(() {
      setState(() {
        isFocus = inputFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    inputFocusNode.dispose();
    super.dispose();
  }

  void onIconClearPress(TextEditingController controller) {
    controller.text = '';
    inputFocusNode.requestFocus();
  }

  void setAddressText(String addressText) {
    PlacesAutocompleteWidget.of(context)._queryTextController.text = addressText;
  }

  void requestUnFocus() {
    inputFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = PlacesAutocompleteWidget.of(context);

    return Container(
      margin: EdgeInsets.only(top: !kIsWeb && Platform.isAndroid ? 20 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: InkWell(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Navigator.of(context).pop();
                },
                child: const Icon(Icons.arrow_back_ios_rounded)),
          ),
          Expanded(
            child: Container(
                alignment: Alignment.topLeft,
                decoration: BoxDecoration(
                    border: Border.all(width: 0.75, color: isFocus ? widget.focusColor : widget.borderColor),
                    color: widget.inputContainerColor,
                    borderRadius: BorderRadius.circular(30)),
                margin: const EdgeInsets.only(right: 26),
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  children: [
                    if (widget.iconLeft != null) widget.iconLeft!,
                    Expanded(
                        child: TextField(
                      onChanged: widget.onChangeQueryText,
                      autofocus: true,
                      focusNode: inputFocusNode,
                      controller: state._queryTextController,
                      style: widget.textStyle ?? _defaultStyle(),
                      decoration: widget.textDecoration ?? _defaultDecoration(state.widget.hint),
                      cursorColor: widget.cursorColor,
                    )),
                    if (!isFocus) const SizedBox(width: 14),
                    if (isFocus)
                      IconButton(
                          onPressed: () {
                            if (widget.onClearText != null) {
                              widget.onClearText!();
                            }
                            onIconClearPress(state._queryTextController);
                          },
                          icon: widget.iconRight ?? const Icon(Icons.clear_sharp))
                  ],
                )),
          ),
        ],
      ),
    );
  }

  InputDecoration _defaultDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Theme.of(context).brightness == Brightness.light ? Colors.white30 : Colors.black38,
      hintStyle: TextStyle(
        color: Theme.of(context).brightness == Brightness.light ? Colors.black38 : Colors.white30,
        fontSize: 16.0,
      ),
      border: InputBorder.none,
    );
  }

  TextStyle _defaultStyle() {
    return TextStyle(
      color: Theme.of(context).brightness == Brightness.light
          ? Colors.black.withOpacity(0.9)
          : Colors.white.withOpacity(0.9),
      fontSize: 16.0,
    );
  }
}

class PoweredByGoogleImage extends StatelessWidget {
  final _poweredByGoogleWhite = 'packages/flutter_google_places_hoc081098/assets/google_white.png';
  final _poweredByGoogleBlack = 'packages/flutter_google_places_hoc081098/assets/google_black.png';

  const PoweredByGoogleImage({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
      Padding(
          padding: const EdgeInsets.all(16.0),
          child: Image.asset(
            Theme.of(context).brightness == Brightness.light ? _poweredByGoogleWhite : _poweredByGoogleBlack,
            scale: 2.5,
          ))
    ]);
  }
}

class PredictionsListView extends StatelessWidget {
  final List<AutocompletePrediction> predictions;
  final ValueChanged<AutocompletePrediction> onTap;
  final Widget? icon;
  final TextStyle? textStyle;

  const PredictionsListView({super.key, required this.predictions, required this.onTap, this.icon, this.textStyle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.transparent,
          height: MediaQuery.of(context).padding.top - 10,
        ),
        Container(
            height: 340,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              color: Colors.white,
            ),
            // color: Colors.blue,
            child: ListView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.zero,
              children: predictions
                  .map((AutocompletePrediction p) =>
                      PredictionTile(prediction: p, onTap: onTap, icon: icon, textStyle: textStyle))
                  .toList(growable: false),
            )),
      ],
    );
  }
}

class PredictionWithDistance {
  AutocompletePrediction prediction;
  double distance;

  PredictionWithDistance(this.prediction, this.distance);
}

class PredictionTile extends StatelessWidget {
  final AutocompletePrediction prediction;
  final ValueChanged<AutocompletePrediction> onTap;
  final Widget? icon;
  final TextStyle? textStyle;

  const PredictionTile({super.key, required this.prediction, required this.onTap, this.icon, this.textStyle});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Container(
        child: InkWell(
          onTap: () {
            onTap(prediction);
          },
          child: Container(
              height: 68,
              margin: const EdgeInsets.only(left: 20, right: 40),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(width: 1, color: Color.fromRGBO(221, 221, 221, 1)))),
              child: Column(
                children: [
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24, top: 15),
                        child: icon ?? const Icon(Icons.access_alarm),
                      ),
                      Expanded(
                          child: Container(
                        padding: const EdgeInsets.only(top: 10),
                        margin: const EdgeInsets.only(left: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(prediction.primaryText.split(', ').first,
                                style: textStyle?.copyWith(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1),
                            const SizedBox(height: 4),
                            Text(
                              '${((prediction.distanceMeters ?? 0) * 0.001).toStringAsFixed(1)}km • ${prediction.primaryText.split(", ").sublist(1).join(', ').trim()}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ],
              )),
        ),
      ),
    );
  }
}

enum Mode { overlay, fullscreen }

abstract class PlacesAutocompleteState extends State<PlacesAutocompleteWidget> {
  late final TextEditingController _queryTextController = TextEditingController(text: widget.startText)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.startText?.length ?? 0,
    );

  late final StateConnectableStream<_SearchState> _state$ =
      Single.fromCallable(() => FlutterGooglePlacesSdk(widget.apiKey))
          .exhaustMap(
            (places) => _queryTextController
                .toValueStream(replayValue: true)
                .map((v) => v.text)
                .debounceTime(widget.debounce ?? const Duration(milliseconds: 300))
                .distinct()
                .switchMap((s) => _doSearch(s, places)),
          )
          .publishState(const _SearchState(false, '', []));

  StreamSubscription<void>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = _state$.connect();
  }

  Stream<_SearchState> _doSearch(String value, FlutterGooglePlacesSdk places) async* {
    yield _SearchState(true, value, []);

    assert(() {
      debugPrint('''[flutter_google_places_hoc081098] input='$value', origin=${widget.origin}''');
      return true;
    }());

    try {
      final FindAutocompletePredictionsResponse res = await places.findAutocompletePredictions(
        value,
        placeTypesFilter: widget.types,
        countries: widget.countries,
        origin: widget.origin,
      );

      yield _SearchState(
        false,
        value,
        _sorted(res.predictions),
      );
    } catch (e, s) {
      assert(() {
        debugPrint('[flutter_google_places_hoc081098] ERROR $e $s');
        return true;
      }());
      yield _SearchState(false, value, []);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _queryTextController.dispose();

    super.dispose();
  }

  @mustCallSuper
  void onResponseError(List<AutocompletePrediction> res) {
    if (!mounted) return;
    widget.onError?.call(res);
  }

  @mustCallSuper
  void onResponse(List<AutocompletePrediction> res) {}

  static List<AutocompletePrediction> _sorted(List<AutocompletePrediction> predictions) {
    if (predictions.isEmpty || predictions.every((e) => e.distanceMeters == null)) {
      return predictions;
    }

    final sorted = predictions.sortedBy<num>((e) => e.distanceMeters ?? 0);

    assert(() {
      debugPrint(
          '[flutter_google_places_hoc081098] sorted=${sorted.map((e) => e.distanceMeters).toList(growable: false)}');
      return true;
    }());

    return sorted;
  }
}

class _SearchState {
  final String text;
  final bool isSearching;
  final List<AutocompletePrediction> predictions;

  const _SearchState(this.isSearching, this.text, this.predictions);

  @override
  String toString() => '_SearchState{text: $text, isSearching: $isSearching, predictions: $predictions}';
}

abstract class PlacesAutocomplete {
  PlacesAutocomplete._();

  /// See [PlacesAutocompleteWidget] for more details about the various parameters.
  static Future<AutocompletePrediction?> show(
      {required BuildContext context,
      required String apiKey,
      required LatLng origin,
      required List<String> countries,
      required List<PlaceTypeFilter> types,
      Mode mode = Mode.fullscreen,
      String? hint = 'Search',
      BorderRadius? overlayBorderRadius,
      Widget? logo,
      ValueChanged<Object>? onError,
      String? startText,
      Duration? debounce,
      InputDecoration? textDecoration,
      TextStyle? textStyle,
      Color? cursorColor,
      EdgeInsets? insetPadding,
      Widget? backArrowIcon,
      TextStyle? resultTextStyle}) {
    PlacesAutocompleteWidget builder(BuildContext context) => PlacesAutocompleteWidget(
          apiKey: apiKey,
          mode: mode,
          overlayBorderRadius: overlayBorderRadius,
          types: types,
          hint: hint,
          logo: logo,
          onError: onError,
          startText: startText,
          debounce: debounce,
          origin: origin,
          textDecoration: textDecoration,
          textStyle: textStyle,
          cursorColor: cursorColor,
          insetPadding: insetPadding,
          backArrowIcon: backArrowIcon,
          resultTextStyle: resultTextStyle,
          countries: countries,
        );

    switch (mode) {
      case Mode.overlay:
        return showDialog<AutocompletePrediction>(context: context, builder: builder);
      case Mode.fullscreen:
        return Navigator.push<AutocompletePrediction>(context, MaterialPageRoute(builder: builder));
    }
  }
}

class PlacesAutoCompleteTextFieldController {
  late void Function(String addressText) setAddressText;
  late void Function() requestUnFocus;
}
