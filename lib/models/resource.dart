class Resource {
  final String title;
  final String url;

  Resource({required this.title, required this.url});

  factory Resource.fromJson(Map<String, dynamic> json) {
    return Resource(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
    );
  }
}
