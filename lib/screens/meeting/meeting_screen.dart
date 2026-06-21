import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class MeetingScreen extends StatefulWidget {
  final String roomName;
  final String displayName;
  final String email;
  final bool audioMuted;
  final bool videoMuted;

  const MeetingScreen({
    super.key,
    required this.roomName,
    required this.displayName,
    this.email = '',
    this.audioMuted = true,
    this.videoMuted = false,
  });

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> {
  late final WebViewController _webViewController;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);

    // Initialize WebView
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            print('Page started: $url');
          },
          onPageFinished: (url) {
            print('Page finished: $url');
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (error) {
            print('WebView error: ${error.description}');
            setState(() {
              _isLoading = false;
              _hasError = true;
              _errorMessage = error.description;
            });
          },
        ),
      )
      ..addJavaScriptChannel(
        'meetingJoined',
        onMessageReceived: (JavaScriptMessage message) {
          print('Meeting joined');
          setState(() {
            _isLoading = false;
          });
        },
      )
      ..addJavaScriptChannel(
        'meetingEnded',
        onMessageReceived: (JavaScriptMessage message) {
          print('Meeting ended');
          _endMeeting();
        },
      )
      ..addJavaScriptChannel(
        'participantJoined',
        onMessageReceived: (JavaScriptMessage message) {
          print('Participant joined: ${message.message}');
        },
      )
      ..addJavaScriptChannel(
        'connectionError',
        onMessageReceived: (JavaScriptMessage message) {
          print('Connection error: ${message.message}');
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = message.message;
          });
        },
      )
      ..loadHtmlString(_buildHtml());
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.microphone].request();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  String _buildHtml() {
    final safeRoom = widget.roomName;
    final safeName = widget.displayName.replaceAll("'", "\\'");
    final safeEmail = widget.email.replaceAll("'", "\\'");

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin:0; padding:0; box-sizing:border-box; }
    body { 
      background: #1a1a1a; 
      overflow: hidden; 
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    }
    #jitsi-container { 
      width: 100vw; 
      height: 100vh; 
      position: fixed; 
      top: 0; 
      left: 0; 
    }
    #loader {
      position: fixed;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      color: white;
      text-align: center;
      z-index: 1000;
    }
    #loader .logo {
      width: 60px;
      height: 60px;
      margin: 0 auto 16px;
      background: #000000;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 28px;
      font-weight: 800;
      color: #ffffff;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    }
    .spinner {
      width: 40px;
      height: 40px;
      border: 3px solid rgba(255,255,255,0.15);
      border-top-color: #000000;
      border-radius: 50%;
      animation: spin 1s linear infinite;
      margin: 0 auto 16px;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
    .loader-text { 
      color: #000000; 
      font-size: 16px; 
      font-weight: 600; 
      letter-spacing: 0.5px;
    }
    .loader-sub { 
      color: rgba(0,0,0,0.5); 
      font-size: 13px; 
      margin-top: 6px; 
      font-weight: 400;
    }
  </style>
</head>
<body>
  <div id="loader">
    <div class="logo">U</div>
    <div class="spinner"></div>
    <div class="loader-text">Meeting</div>
    <div class="loader-sub">$safeRoom</div>
  </div>
  <div id="jitsi-container"></div>

  <script>
    function loadJitsiScript(callback) {
      if (window.JitsiMeetExternalAPI) {
        callback();
        return;
      }
      const script = document.createElement('script');
      script.src = 'https://meet.jit.si/external_api.js';
      script.async = true;
      script.onload = callback;
      script.onerror = function() {
        console.error('Failed to load Jitsi script');
        if (window.meetingJoined) {
          window.meetingJoined.postMessage('ERROR: Failed to load Jitsi');
        }
      };
      document.head.appendChild(script);
    }

    loadJitsiScript(function() {
      console.log('Jitsi script loaded');
      try {
        const options = {
          roomName: '$safeRoom',
          parentNode: document.getElementById('jitsi-container'),
          width: '100%',
          height: '100%',
          userInfo: { displayName: '$safeName' },
          configOverwrite: {
            startWithAudioMuted: ${widget.audioMuted},
            startWithVideoMuted: ${widget.videoMuted},
            disableDeepLinking: true,
            prejoinPageEnabled: false,
          },
          interfaceConfigOverwrite: {
            TOOLBAR_BUTTONS: ['microphone','camera','desktop','fullscreen','fodeviceselection','hangup','chat','raisehand','videoquality','tileview','settings'],
            SHOW_JITSI_WATERMARK: false,
            SHOW_WATERMARK_FOR_GUESTS: false,
          }
        };

        const api = new JitsiMeetExternalAPI('meet.jit.si', options);
        console.log('Jitsi API created');

        api.addEventListener('videoConferenceJoined', function() {
          console.log('Joined meeting');
          document.getElementById('loader').style.display = 'none';
          if (window.meetingJoined) {
            window.meetingJoined.postMessage('JOINED');
          }
        });

        api.addEventListener('readyToClose', function() {
          console.log('Meeting ended');
          if (window.meetingEnded) {
            window.meetingEnded.postMessage('ENDED');
          }
        });

        api.addEventListener('participantJoined', function(event) {
          if (window.participantJoined && event.displayName) {
            window.participantJoined.postMessage(event.displayName + ' joined');
          }
        });

        setTimeout(function() {
          document.getElementById('loader').style.display = 'none';
        }, 15000);

      } catch (error) {
        console.error('Error:', error);
        if (window.connectionError) {
          window.connectionError.postMessage(error.message);
        }
      }
    });
  </script>
</body>
</html>
''';
  }

  void _endMeeting() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          WebViewWidget(controller: _webViewController),

          if (_isLoading)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Static black logo
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'U',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Meeting',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.roomName,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: _endMeeting,
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_hasError)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 60),
                    const SizedBox(height: 16),
                    const Text(
                      'Could not connect',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        _errorMessage.isNotEmpty ? _errorMessage : 'Check your internet connection',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _endMeeting,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}