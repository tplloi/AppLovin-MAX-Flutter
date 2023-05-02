import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:applovin_max/applovin_max.dart';
import 'package:flutter/material.dart';

enum AdLoadState { notLoaded, loading, loaded }

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

// Create constants
const String _sdkKey =
    "e75FnQfS9XTTqM1Kne69U7PW_MBgAnGQTFvtwVVui6kRPKs5L7ws9twr5IQWwVfzPKZ5pF2IfDa7lguMgGlCyt";

final String _interstitialAdUnitId =
    Platform.isAndroid ? "f4a542a4bda4c5f1" : "IOS_INTER_AD_UNIT_ID";
final String _bannerAdUnitId =
    Platform.isAndroid ? "aed1455d708c540e" : "IOS_BANNER_AD_UNIT_ID";

// Create states
var _isInitialized = false;
var _interstitialLoadState = AdLoadState.notLoaded;
var _interstitialRetryAttempt = 0;
var _isProgrammaticBannerCreated = false;
var _isProgrammaticBannerShowing = false;
var _isWidgetBannerShowing = false;

var _statusText = "";

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    initializePlugin();
  }

  // NOTE: Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initializePlugin() async {
    logStatus("Initializing SDK...");

    Map? configuration = await AppLovinMAX.initialize(_sdkKey);
    if (configuration != null) {
      _isInitialized = true;

      logStatus("SDK Initialized: $configuration");

      attachAdListeners();
    }
  }

  void attachAdListeners() {
    /// Interstitial Ad Listeners
    AppLovinMAX.setInterstitialListener(InterstitialListener(
      onAdLoadedCallback: (ad) {
        _interstitialLoadState = AdLoadState.loaded;

        // Interstitial ad is ready to be shown. AppLovinMAX.isInterstitialAdReady(_interstitial_ad_unit_id) will now return 'true'
        logStatus('Interstitial ad loaded from ${ad.networkName}');

        // Reset retry attempt
        _interstitialRetryAttempt = 0;
      },
      onAdLoadFailedCallback: (adUnitId, error) {
        _interstitialLoadState = AdLoadState.notLoaded;

        // Interstitial ad failed to load
        // We recommend retrying with exponentially higher delays up to a maximum delay (in this case 64 seconds)
        _interstitialRetryAttempt = _interstitialRetryAttempt + 1;

        int retryDelay = pow(2, min(6, _interstitialRetryAttempt)).toInt();
        logStatus(
            'Interstitial ad failed to load with code ${error.code} - retrying in ${retryDelay}s');

        Future.delayed(Duration(milliseconds: retryDelay * 1000), () {
          AppLovinMAX.loadInterstitial(_interstitialAdUnitId);
        });
      },
      onAdDisplayedCallback: (ad) {
        logStatus('Interstitial ad displayed');
      },
      onAdDisplayFailedCallback: (ad, error) {
        _interstitialLoadState = AdLoadState.notLoaded;
        logStatus(
            'Interstitial ad failed to display with code ${error.code} and message ${error.message}');
      },
      onAdClickedCallback: (ad) {
        logStatus('Interstitial ad clicked');
      },
      onAdHiddenCallback: (ad) {
        _interstitialLoadState = AdLoadState.notLoaded;
        logStatus('Interstitial ad hidden');
      },
      onAdRevenuePaidCallback: (ad) {
        logStatus('Interstitial ad revenue paid: ${ad.revenue}');
      },
    ));

    /// Banner Ad Listeners
    AppLovinMAX.setBannerListener(AdViewAdListener(onAdLoadedCallback: (ad) {
      logStatus('Banner ad loaded from ${ad.networkName}');
    }, onAdLoadFailedCallback: (adUnitId, error) {
      logStatus(
          'Banner ad failed to load with error code ${error.code} and message: ${error.message}');
    }, onAdClickedCallback: (ad) {
      logStatus('Banner ad clicked');
    }, onAdExpandedCallback: (ad) {
      logStatus('Banner ad expanded');
    }, onAdCollapsedCallback: (ad) {
      logStatus('Banner ad collapsed');
    }, onAdRevenuePaidCallback: (ad) {
      logStatus('Banner ad revenue paid: ${ad.revenue}');
    }));
  }

  String getInterstitialButtonTitle() {
    if (_interstitialLoadState == AdLoadState.notLoaded) {
      return "Load Interstitial";
    } else if (_interstitialLoadState == AdLoadState.loading) {
      return "Loading...";
    } else {
      return "Show Interstitial"; // adLoadState.loaded
    }
  }

  String getProgrammaticBannerButtonTitle() {
    return _isProgrammaticBannerShowing
        ? 'Hide Programmatic Banner'
        : 'Show Programmatic Banner';
  }

  String getWidgetBannerButtonTitle() {
    return _isWidgetBannerShowing ? 'Hide Widget Banner' : 'Show Widget Banner';
  }

  void logStatus(String status) {
    /// ignore: avoid_print
    print(status);

    setState(() {
      _statusText = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            title: const Text("AppLovin MAX Demo"),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                '$_statusText\n',
                style: const TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),

              //Mediation Debugger
              ElevatedButton(
                onPressed: _isInitialized
                    ? () {
                        AppLovinMAX.showMediationDebugger();
                      }
                    : null,
                child: const Text("Mediation Debugger"),
              ),

              //Interstitial
              ElevatedButton(
                onPressed: (_isInitialized &&
                        _interstitialLoadState != AdLoadState.loading)
                    ? () async {
                        bool isReady = (await AppLovinMAX.isInterstitialReady(
                            _interstitialAdUnitId))!;
                        if (isReady) {
                          AppLovinMAX.showInterstitial(_interstitialAdUnitId);
                        } else {
                          logStatus('Loading interstitial ad...');
                          _interstitialLoadState = AdLoadState.loading;
                          AppLovinMAX.loadInterstitial(_interstitialAdUnitId);
                        }
                      }
                    : null,
                child: Text(getInterstitialButtonTitle()),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  //Programmatic banner
                  ElevatedButton(
                    onPressed: (_isInitialized && !_isWidgetBannerShowing)
                        ? () async {
                            if (_isProgrammaticBannerShowing) {
                              AppLovinMAX.hideBanner(_bannerAdUnitId);
                            } else {
                              if (!_isProgrammaticBannerCreated) {
                                //
                                // Programmatic banner creation - banners are automatically sized to 320x50 on phones and 728x90 on tablets
                                //
                                AppLovinMAX.createBanner(_bannerAdUnitId,
                                    AdViewPosition.bottomCenter);

                                // Set banner background color to black - PLEASE USE HEX STRINGS ONLY
                                AppLovinMAX.setBannerBackgroundColor(
                                    _bannerAdUnitId, '#000000');

                                _isProgrammaticBannerCreated = true;
                              }

                              AppLovinMAX.showBanner(_bannerAdUnitId);
                            }

                            setState(() {
                              _isProgrammaticBannerShowing =
                                  !_isProgrammaticBannerShowing;
                            });
                          }
                        : null,
                    child: Text(getProgrammaticBannerButtonTitle()),
                  ),

                  //widget banner
                  ElevatedButton(
                    onPressed: (_isInitialized && !_isProgrammaticBannerShowing)
                        ? () async {
                            setState(() {
                              _isWidgetBannerShowing = !_isWidgetBannerShowing;
                            });
                          }
                        : null,
                    child: Text(getWidgetBannerButtonTitle()),
                  )
                ],
              ),
              if (_isWidgetBannerShowing)
                Container(
                  margin: const EdgeInsets.only(top: 100),
                  color: Colors.red,
                  child: MaxAdView(
                      adUnitId: _bannerAdUnitId,
                      adFormat: AdFormat.banner,
                      listener: AdViewAdListener(onAdLoadedCallback: (ad) {
                        logStatus(
                            'Banner widget ad loaded from ${ad.networkName}');
                      }, onAdLoadFailedCallback: (adUnitId, error) {
                        logStatus(
                            'Banner widget ad failed to load with error code ${error.code} and message: ${error.message}');
                      }, onAdClickedCallback: (ad) {
                        logStatus('Banner widget ad clicked');
                      }, onAdExpandedCallback: (ad) {
                        logStatus('Banner widget ad expanded');
                      }, onAdCollapsedCallback: (ad) {
                        logStatus('Banner widget ad collapsed');
                      }, onAdRevenuePaidCallback: (ad) {
                        logStatus('Banner widget ad revenue paid: ${ad.revenue}');
                      })),
                ),

            ],
          )),
    );
  }
}
