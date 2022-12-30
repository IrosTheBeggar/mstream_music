class Server {
  String url;
  String localname; // name we use when mappings files to the fs
  bool saveToSdCard = false;

  // authentication is optional (mstream servers can be public OR private)
  String? username;
  String? password;
  String? jwt;

  // Auto DJ
  int? autoDJminRating;
  Map<String, bool> autoDJPaths = {};
  List<String> playlists = [];

  Server(this.url, this.username, this.password, this.jwt, this.localname);

  Server.fromJson(Map<String, dynamic> json)
      : url = json['url'],
        jwt = json['jwt'],
        username = json['username'],
        password = json['password'],
        localname = json['localname'],
        autoDJPaths = json['autoDJPaths']?.cast<String, bool>() ?? {},
        autoDJminRating = json['autoDJminRating'],
        playlists = List<String>.from(json['playlists']) ?? [],
        saveToSdCard = json['saveToSdCard'] ?? false;

  Map<String, dynamic> toJson() => {
        'url': url,
        'jwt': jwt,
        'username': username,
        'password': password,
        'localname': localname,
        'autoDJPaths': autoDJPaths,
        'autoDJminRating': autoDJminRating,
        'playlists': playlists,
        'saveToSdCard': saveToSdCard
      };
}
