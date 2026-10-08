import 'package:flutter/material.dart';

/// Registered on MaterialApp (see main.dart) so menu-context screens can
/// mix in RouteAware and get a `didPopNext()` callback exactly when the
/// user navigates back to them -- e.g. to resume the menu music. A plain
/// `initState()` call isn't enough for this: popping a route back to an
/// existing screen does NOT re-run that screen's initState (the widget was
/// never disposed, just covered), so returning to the home screen after a
/// lesson needs this instead.
final RouteObserver<PageRoute> appRouteObserver = RouteObserver<PageRoute>();
