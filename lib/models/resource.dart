class Resource {
  final String title;
  final String url;
  final String? description;

  Resource({required this.title, required this.url, this.description});

  factory Resource.fromJson(Map<String, dynamic> json) {
    return Resource(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'url': url,
    if (description != null) 'description': description,
  };
}
