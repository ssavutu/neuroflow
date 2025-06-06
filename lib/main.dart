import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'dart:convert';

Future<void> main() async{
    WidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: ".env");
    runApp(const MyApp());
}

Future<String> getToken() async {
    final secret = dotenv.env["CLIENT_SECRET"];
    final id = dotenv.env["CLIENT_ID"];
    var logger = Logger();
    final url = Uri.https("accounts.spotify.com", "api/token");
    var response = await http.post(
        url,
        headers: {
            "Content-Type" : "application/x-www-form-urlencoded"
        },
        body: {
            "grant_type":"client_credentials",
            "client_id":"$id",
            "client_secret":"$secret",
        },
    );
    Map decodedResponse = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
    logger.d(decodedResponse);
    return decodedResponse["access_token"];
}

Future<List<dynamic>> searchArtist(String artist, String token) async {
  final Uri url = Uri.parse("https://api.spotify.com/v1/search?q=artist:$artist&type=artist");
  var logger = Logger();
  var response = await http.get(
      url,
      headers: {
          "Authorization" : "Bearer $token"
      }
  );
  Map decodedResponse = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
  logger.d(decodedResponse);
  return decodedResponse["artists"]["items"];
}

Future<Map> getArtist(String artistID, String token) async {
  final Uri url = Uri.parse("https://api.spotify.com/v1/artists/$artistID");
  var logger = Logger();
  var response = await http.get(
      url,
      headers: {
          "Authorization" : "Bearer $token"
      }
  );
  Map decodedResponse = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
  logger.d(decodedResponse);
  return decodedResponse;
}

Future<Card> spawnCard(artistID, token) async{
  Map artist = await getArtist(artistID, token);
  return Card(
    child: Text(artist["name"])
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neuroflow',
      theme: ThemeData(
        colorScheme: ColorScheme(
            brightness: Brightness.dark,
            primary: Color(0xFF1db954),
            onPrimary: Color(0xFF1db954),
            secondary: Color(0xFF1db954), 
            onSecondary: Color(0xFFFFFFFF), 
            error: Color(0xFFED4337),
            onError: Color(0xFFFFFFFF),
            surface: Color(0xFF212121),
            onSurface: Color(0xFFFFFFFF),
        )
      ),
      home: MyHomePage(title: 'Neuroflow'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final SearchController controller = SearchController();
  Future<List<dynamic>>? cachedArtists;
  String selectedArtistID = "";
  var logger = Logger();
  late Future<String> token;
  String publicToken = "";
  
  @override
  void initState() {
    super.initState();
    token = getToken();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Color(0xFF121212),
        body: SafeArea(
            child: CustomScrollView(
                slivers: [
                    SliverAppBar(
                        backgroundColor: Color(0xFF121212),
                        clipBehavior: Clip.none,
                        scrolledUnderElevation: 0.0,
                        titleSpacing: 0.0,
                        toolbarHeight: 120,
                        floating: false,
                        title: SearchAnchor(
                            searchController: controller,
                            builder: (BuildContext context, SearchController controller) {
                                return SearchBar(
                                    controller: controller,
                                    padding: const WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.all(16)),
                                    onTap: () {
                                        controller.openView();
                                    },
                                    leading: const Icon(Icons.search),
                                );
                            }, 
                            suggestionsBuilder: (BuildContext context, SearchController controller) async {
                                String useToken = await token;
                                setState( () {
                                    cachedArtists = searchArtist(controller.value.text, useToken);
                                });
                                logger.d("suggestionsBuilder triggered");
                                List<dynamic> listArtists = await cachedArtists!;
                                return List<ListTile>.generate(listArtists.length, (int index) {
                                    String artist = listArtists[index]["name"];
                                    return ListTile(
                                        title: Text(artist),
                                        onTap: () {
                                            setState(() {
                                              controller.closeView(artist);
                                              selectedArtistID = listArtists[index]["id"];
                                              publicToken = useToken;
                                            });
                                        },
                                    );
                                });
                            }
                        )
                    ),
                    if (selectedArtistID != "")
                      FutureBuilder(
                        future: getArtist(selectedArtistID, publicToken),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const SliverToBoxAdapter(child: CircularProgressIndicator());
                          }
                          else if (snapshot.hasError) {
                            return SliverToBoxAdapter(child: Text("Error: ${snapshot.error}"));
                          }
                          else if (snapshot.hasData) {
                            final Map artist = snapshot.data!;
                            return SliverToBoxAdapter(
                              child: Card(
                                child: Container(
                                  height: MediaQuery.of(context).size.height*0.7,
                                  width: MediaQuery.of(context).size.width*0.7,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Text(artist["name"]),
                                      Text("Followers: ${artist["followers"]["total"]}"),
                                      Image.network(artist["images"][0]["url"])
                                    ]
                                  )
                                )
                              )
                            );
                          }
                          else {
                            return SliverToBoxAdapter(child:Text("No data, error occured"));
                          }
                        }
                      )
                ]
            )
        )
    );
  }
}
