class Server {
  String url;
  String nickname; // name the user sees
  String localname; // name we use when mappings files to the fs

  // authentication is optional (mstream servers can be public OR private)
  String? username;
  String? password;
  String? jwt;

  Server(this.url, this.nickname, this.username, this.password, this.jwt,
      this.localname);

  Server.fromJson(Map<String, dynamic> json)
      : url = json['url'],
        jwt = json['jwt'],
        username = json['username'],
        password = json['password'],
        localname = json['localname'],
        nickname = json['nickname'];

  Map<String, dynamic> toJson() => {
        'url': url,
        'jwt': jwt,
        'nickname': nickname,
        'username': username,
        'password': password,
        'localname': localname,
      };
}
