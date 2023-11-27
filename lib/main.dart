import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';

void main() {
  runApp(const CodigosPostalesApp());
}

class PostalCode {
  final String placeName;
  final String state;
  final String country;
  final String imageUrl;

  PostalCode({
    required this.placeName,
    required this.state,
    required this.country,
    required this.imageUrl,
  });

  factory PostalCode.fromJson(Map<String, dynamic> json, String imageUrl) {
    return PostalCode(
      placeName: json['places'][0]['place name'],
      state: json['places'][0]['state'],
      country: json['country'],
      imageUrl: imageUrl,
    );
  }
}

class CodigosPostalesApp extends StatelessWidget {
  const CodigosPostalesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.from(
        colorScheme:const ColorScheme.light().copyWith(
          primary: const Color.fromARGB(255, 243, 33, 131),
         secondary: const Color.fromARGB(255, 226, 67, 120)),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Explora Códigos Postales'),
        ),
        body: const PostalCodeSearch(),
      ),
    );
  }
}

class PostalCodeSearch extends StatefulWidget {
  const PostalCodeSearch({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _PostalCodeSearchState createState() => _PostalCodeSearchState();
}

class _PostalCodeSearchState extends State<PostalCodeSearch> with TickerProviderStateMixin {
 final TextEditingController _controller = TextEditingController();
  PostalCode? _postalCode;
  String _errorMessage = '';
  late AnimationController _resultAnimationController;
  late Animation<Offset> _resultSlideAnimation;
  late AnimationController _searchButtonAnimationController;
  late Animation<double> _searchButtonScaleAnimation;

  @override
  void initState() {
    super.initState();

    _resultAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _resultSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _resultAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _searchButtonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _searchButtonScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(
      CurvedAnimation(
        parent: _searchButtonAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _resultAnimationController.dispose();
    _searchButtonAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Introduce el código postal',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox (height: 16.0),
          AnimatedBuilder(
            animation: _searchButtonScaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _searchButtonScaleAnimation.value,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_controller.text.isEmpty || !isNumeric(_controller.text)) {
                      setState(() {
                        _errorMessage = 'Por favor, introduce un código postal válido.';
                        _postalCode = null;
                        _vibrate();
                      });
                    } else {
                      final postalCode = await fetchPostalCode('es', _controller.text);
                      if (postalCode != null) {
                        setState(() {
                          _postalCode = postalCode;
                          _errorMessage = '';
                        });
                        _animateResult();
                      } else {
                        setState(() {
                          _errorMessage = 'Código postal no encontrado. Verifica la entrada e intenta nuevamente.';
                          _vibrate();
                        });
                      }
                    }
                  },
                  child: const Text('Buscar'),
                ),
              );
            },
          ),
          const SizedBox(height: 8.0),
          Text(
            _errorMessage,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16.0),
          if (_postalCode != null)
            SlideTransition(
              position: _resultSlideAnimation,
              child: Card(
                elevation: 4.0,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Localidad: ${_postalCode!.placeName}'),
                      Text('Provincia: ${_postalCode!.state}'),
                      Text('País: ${_postalCode!.country}'),
                      const SizedBox(height: 16.0),
                      Image.network(_postalCode!.imageUrl, height: 150),
                      ElevatedButton(
                        onPressed: () {
                          launchGoogleMaps(_postalCode!.placeName);
                        },
                        child: const Text('Abrir en Google Maps'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _animateResult() {
    _resultAnimationController.forward();
    _searchButtonAnimationController.forward();
  }

  bool isNumeric(String value) {
    // ignore: unnecessary_null_comparison
    if (value == null) {
      return false;
    }
    return double.tryParse(value) != null;
  }

  Future<PostalCode?> fetchPostalCode(String countryCode, String postalCode) async {
    try {
      final response = await http.get(Uri.parse('https://api.zippopotam.us/$countryCode/$postalCode'));

      if (response.statusCode == 200) {
        final jsonResult = json.decode(response.body);
        final imageUrl = await fetchRandomImageUrl(jsonResult['places'][0]['place name']);
        return PostalCode.fromJson(jsonResult, imageUrl);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

 Future<String> fetchRandomImageUrl(String locationName) async {
  // ignore: prefer_const_declarations
  final unsplashApiKey = 'v4vu4kAOYYN8e-wglbq3Fu6dYqBPCQR_GQ3LsSsBU20'; 
  final query = Uri.encodeComponent('$locationName turismo'); 
  final unsplashApiUrl = 'https://api.unsplash.com/photos/random?query=$query&client_id=$unsplashApiKey';

  try {
    final response = await http.get(Uri.parse(unsplashApiUrl));
    if (response.statusCode == 200) {
      final jsonResult = json.decode(response.body);
      return jsonResult['urls']['regular'];
    } else {
      return '';
    }
  } catch (e) {
    return ''; 
  }
}


  void launchGoogleMaps(String locationName) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$locationName';
    // ignore: deprecated_member_use
    if (await canLaunch(url)) {
      // ignore: deprecated_member_use
      await launch(url);
    } else {
      throw 'No se puede abrir Google Maps';
    }
  }

  void _vibrate() {
    Vibration.vibrate(duration: 300);
  }
}
