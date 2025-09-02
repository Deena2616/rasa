import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:intl/intl.dart';

const String backendUrl = 'http://localhost:3000';
const String rasaUrl = 'http://localhost:5005';

enum ElementType {
  heading, paragraph, button, list, video, card, icon, imageSlider, submitButton, nextButton, backButton, loginButton, image, logo, radioGroup, checkbox, bottomBar, cardRow2, cardRow3, appBar, textField
}

// Video Player Widget Implementation
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final List<String> videoUrls;
  const VideoPlayerWidget({Key? key, required this.videoUrl, required this.videoUrls}) : super(key: key);
  
  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _hasError = false;
  int _currentVideoIndex = 0;
  final Random _rand = Random();
  bool _isPlaying = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  
  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }
  
  void _initializeVideo() {
    if (widget.videoUrls.isNotEmpty) {
      _currentVideoIndex = widget.videoUrls.indexOf(widget.videoUrl);
      if (_currentVideoIndex == -1) _currentVideoIndex = _rand.nextInt(widget.videoUrls.length);
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrls[_currentVideoIndex]))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _controller?.play();
            _controller?.setLooping(true);
            _isPlaying = true;
            _startHideControlsTimer();
          }
        }).catchError((e) {
          if (mounted) setState(() => _hasError = true);
        });
    } else {
      _hasError = true;
    }
  }
  
  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }
  
  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _controller?.play();
        _startHideControlsTimer();
      } else {
        _controller?.pause();
        _hideControlsTimer?.cancel();
      }
    });
  }
  
  void _playNextVideo() {
    if (widget.videoUrls.isNotEmpty) {
      _controller?.dispose();
      _currentVideoIndex = (_currentVideoIndex + 1) % widget.videoUrls.length;
      if (_currentVideoIndex == 0) widget.videoUrls.shuffle(_rand);
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrls[_currentVideoIndex]))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _controller?.play();
            _controller?.setLooping(true);
            _isPlaying = true;
            _startHideControlsTimer();
          }
        }).catchError((e) {
          if (mounted) setState(() => _hasError = true);
        });
    }
  }
  
  @override
  void dispose() {
    _controller?.dispose();
    _hideControlsTimer?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (_hasError || _controller == null) {
      return const Center(child: Text('Error loading video'));
    }
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
          if (_showControls) _startHideControlsTimer();
        });
      },
      onDoubleTap: _playNextVideo,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _controller!.value.isInitialized
              ? AspectRatio(aspectRatio: _controller!.value.aspectRatio, child: VideoPlayer(_controller!))
              : const Center(child: CircularProgressIndicator()),
          if (_showControls)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 32),
                    onPressed: _togglePlayPause,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white, size: 32),
                    onPressed: _playNextVideo,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Image Slider Widget Implementation
class ImageSliderWidget extends StatefulWidget {
  final List<String> imageUrls;
  final double height;
  const ImageSliderWidget({Key? key, required this.imageUrls, required this.height}) : super(key: key);
  
  @override
  _ImageSliderWidgetState createState() => _ImageSliderWidgetState();
}

class _ImageSliderWidgetState extends State<ImageSliderWidget> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;
  
  @override
  void initState() {
    super.initState();
    if (widget.imageUrls.isNotEmpty) _startAutoSlide();
  }
  
  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (widget.imageUrls.isNotEmpty) {
        _currentPage = (_currentPage + 1) % widget.imageUrls.length;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return const Center(child: Text('No images available'));
    }
    
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) => Image.network(
              widget.imageUrls[index],
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) =>
                loadingProgress == null ? child : const Center(child: CircularProgressIndicator()),
              errorBuilder: (context, error, stackTrace) => const Center(child: Text('Error loading image')),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.imageUrls.length, (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index ? Colors.white : Colors.white.withOpacity(0.5),
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }
}

// Chat Message class for Rasa chatbot
class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}


// Page Data
final Map<String, dynamic> pageData = {
  'name': 'Page 1',
  'backgroundColor': '#FFFFFF',
  'elements': [
  ]
};

class GeneratedPage extends StatefulWidget {
  const GeneratedPage({super.key});

  @override
  _GeneratedPageState createState() => _GeneratedPageState();
}

class _GeneratedPageState extends State<GeneratedPage> {
  final Map<String, TextEditingController> _controllers = {};
  bool _isSubmitting = false;
  final List<ChatMessage> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late FlutterTts _flutterTts;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _selectedLanguage = 'en';
  bool _isTyping = false;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _initChatbot();
  }

  void _initControllers() {
    for (var el in pageData['elements']) {
      if (el['type'] == ElementType.textField) {
        _controllers[el['fieldId']] = TextEditingController();
      }
    }
  }

  void _initChatbot() {
    _flutterTts = FlutterTts();
    _speech = stt.SpeechToText();
    _flutterTts.setLanguage('en-US');
    _flutterTts.setSpeechRate(0.5);
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);
    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });

    // Add a welcome message
    _addMessage(ChatMessage(text: 'Hello! I'm your product assistant. How can I help you today?', isUser: false));
  }

  void _addMessage(ChatMessage message) {
    setState(() {
      _messages.insert(0, message);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;
    
    final userMessage = _messageController.text;
    _messageController.clear();
    _addMessage(ChatMessage(text: userMessage, isUser: true));
    setState(() => _isTyping = true);
    
    try {
      final response = await http.post(
        Uri.parse('http://localhost:5005/webhooks/rest/webhook'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender': 'flutter_app_${DateTime.now().millisecondsSinceEpoch}',
          'message': userMessage,
          'metadata': {
            'language': _selectedLanguage,
          },
        }),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        List<dynamic> responses = result;
        for (var response in responses) {
          _addMessage(ChatMessage(text: response['text'], isUser: false));
          // Text to speech
          setState(() => _isSpeaking = true);
          await _flutterTts.speak(response['text']);
        }
      } else {
        _addMessage(ChatMessage(text: 'Error: Rasa returned status ${response.statusCode}', isUser: false));
      }
    } catch (e) {
      _addMessage(ChatMessage(text: 'Error: ${e.toString()}', isUser: false));
    } finally {
      setState(() => _isTyping = false);
    }
  }

  void _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (val) => print('onStatus: $val'),
      onError: (val) => print('onError: $val'),
    );
    
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (val) => setState(() {
          _messageController.text = val.recognizedWords;
        }),
        localeId: _getLanguageCode(_selectedLanguage),
      );
    }
  }

  void _stopListening() {
    setState(() => _isListening = false);
    _speech.stop();
    // Automatically send the message if there's text
    if (_messageController.text.trim().isNotEmpty) {
      _sendMessage();
    }
  }

  void _stopSpeaking() async {
    await _flutterTts.stop();
    setState(() => _isSpeaking = false);
  }

  String _getLanguageCode(String language) {
    switch (language.toLowerCase()) {
      case 'tamil':
      case 'ta':
        return 'ta-IN';
      case 'hindi':
      case 'hi':
        return 'hi-IN';
      case 'tanglish':
      case 'en':
      default:
        return 'en-US';
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _messageController.dispose();
    _scrollController.dispose();
    _speech.stop();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _submitForm() async {
    // Prevent multiple submissions
    if (_isSubmitting) return;
    
    setState(() {
      _isSubmitting = true;
    });
    
    // Map to backend expected fields
    final Map<String, dynamic> formData = {};
    bool hasUsername = false;
    bool hasEmail = false;
    bool hasPassword = false;
    
    // Collect all text field values
    for (var el in pageData['elements']) {
      if (el['type'] == ElementType.textField) {
        final fieldId = el['fieldId'] as String;
        final fieldName = el['fieldName'] as String?;
        final value = _controllers[fieldId]?.text ?? '';
        
        // Map to standard fields if fieldName matches expected patterns
        if (fieldName != null) {
          if (fieldName.toLowerCase().contains('name')) {
            formData['username'] = value;
            if (value.trim().isNotEmpty) hasUsername = true;
          } else if (fieldName.toLowerCase().contains('mail')) {
            formData['email'] = value;
            if (value.trim().isNotEmpty) hasEmail = true;
          } else if (fieldName.toLowerCase().contains('pass')) {
            formData['password'] = value;
            if (value.trim().isNotEmpty) hasPassword = true;
          } else {
            // For other fields, use the field name as key
            formData[fieldName] = value;
          }
        } else {
          // If no field name, use field ID
          formData[fieldId] = value;
        }
      }
    }
    
    // Ensure required fields exist for backend
    if (!formData.containsKey('username')) formData['username'] = '';
    if (!formData.containsKey('email')) formData['email'] = '';
    if (!formData.containsKey('password')) formData['password'] = '';
    
    // Validate required fields
    if (!hasUsername) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a username")),
      );
      setState(() { _isSubmitting = false; });
      return;
    }
    
    if (!hasEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an email")),
      );
      setState(() { _isSubmitting = false; });
      return;
    }
    
    if (!hasPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a password")),
      );
      setState(() { _isSubmitting = false; });
      return;
    }
    
    print("Submitting form to: " + backendUrl + "/submit-form");
    print("Form data: " + formData.toString());
    
    try {
      final response = await http.post(
        Uri.parse(backendUrl + "/submit-form"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(formData),
      ).timeout(const Duration(seconds: 30));
      
      print("Response status: " + response.statusCode.toString());
      print("Response body: " + response.body);
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Form submitted successfully! ID: " + (result["id"] ?? "unknown").toString())),
        );
      } else {
        print("❌ Backend response: " + response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: " + response.body)),
        );
      }
    } on TimeoutException catch (e) {
      print("❌ Form submission timed out: " + e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection timed out. Please check your network connection.")),
      );
    } on http.ClientException catch (e) {
      print("❌ Client exception: " + e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to connect to server. Please check if the server is running.")),
      );
    } catch (e) {
      print("❌ Error submitting form: " + e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: " + e.toString())),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Color(0xFFFFFF),
        child: ListView(
          children: [
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showChatbotDialog(context),
        child: const Icon(Icons.chat),
      ),
    );
  }
  void _showChatbotDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.chat),
            const SizedBox(width: 10),
            const Text('Product Assistant'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: message.isUser ? Colors.blue[100] : Colors.grey[200],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(message.text),
                                  if (!message.isUser && _isSpeaking) const SizedBox(height: 8),
                                  if (!message.isUser && _isSpeaking) Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      SizedBox(width: 8),
                                      Text('Speaking...'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (_isTyping) const Padding(
                padding: EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('Typing...'),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Ask about our products...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                              onPressed: _isListening ? _stopListening : _startListening,
                              color: _isListening ? Colors.red : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.send),
                              onPressed: _sendMessage,
                            ),
                          ],
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Language: '),
                  DropdownButton<String>(
                    value: _selectedLanguage,
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                      DropdownMenuItem(value: 'ta', child: Text('Tamil')),
                      DropdownMenuItem(value: 'tanglish', child: Text('Tanglish')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedLanguage = value;
                          _flutterTts.setLanguage(_getLanguageCode(value));
                        });
                      }
                    },
                  ),
                  const Spacer(),
                  if (_isSpeaking)
                    IconButton(
                      icon: const Icon(Icons.stop_circle),
                      onPressed: _stopSpeaking,
                      color: Colors.red,
                      tooltip: 'Stop speaking',
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Generated App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const GeneratedPage(),
    );
  }
}
