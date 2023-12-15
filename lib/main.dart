import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

void main() {
  runApp(MyApp());
}

class Post {
  final String id;
  final String content;
  final String imageUrl;
  int likes;
  bool isLiked;

  Post({
    required this.id,
    required this.content,
    required this.imageUrl,
    this.likes = 0,
    this.isLiked = false,
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: PostFeed(),
    );
  }
}

class PostFeed extends StatefulWidget {
  @override
  _PostFeedState createState() => _PostFeedState();
}

class _PostFeedState extends State<PostFeed> {
  late Future<List<Post>> futurePosts;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    futurePosts = fetchPosts();
  }

  Future<List<Post>> fetchPosts() async {
    final response = await http.get(
      Uri.parse(
          'https://crudoperation1-default-rtdb.firebaseio.com/posts.json'),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic>? data = json.decode(response.body);
      List<Post> posts = [];

      if (data != null) {
        data.forEach((postId, postData) {
          final imageUrl = postData['imageUrl'] ?? '';
          posts.add(Post(
            id: postId,
            content: postData['content'],
            imageUrl: imageUrl,
            likes: postData['likes'] ?? 0,
            isLiked: false,
          ));
        });
      }
      return posts;
    } else {
      throw Exception('Failed to load posts');
    }
  }

  Future<String?> getImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      return pickedFile.path;
    } else {
      return null;
    }
  }

  void addPost(String content, String imageUrl) async {
    final response = await http.post(
      Uri.parse(
          'https://crudoperation1-default-rtdb.firebaseio.com/posts.json'),
      body: json.encode({
        'content': content,
        'imageUrl': imageUrl,
        'likes': 0,
      }),
    );

    if (response.statusCode == 200) {
      setState(() {
        futurePosts = fetchPosts();
      });
    } else {
      print('Failed to add post');
    }
  }

  void likePost(String postId) async {
    final postIndex = await _getPostIndex(postId);
    if (postIndex != -1) {
      setState(() {
        futurePosts.then((posts) {
          if (posts != null) {
            if (posts[postIndex].isLiked) {
              posts[postIndex].likes--;
              posts[postIndex].isLiked = false;
            } else {
              posts[postIndex].likes++;
              posts[postIndex].isLiked = true;
            }
          }
        });
      });
    }
  }

  Future<int> _getPostIndex(String postId) async {
    final posts = await futurePosts;
    if (posts != null) {
      for (int i = 0; i < posts.length; i++) {
        if (posts[i].id == postId) {
          return i;
        }
      }
    }
    return -1;
  }

  void deletePost(String postId) async {
    final response = await http.delete(
      Uri.parse(
          'https://crudoperation1-default-rtdb.firebaseio.com/posts/$postId.json'),
    );

    if (response.statusCode == 200) {
      setState(() {
        futurePosts = fetchPosts();
      });
    } else {
      print('Failed to delete post');
    }
  }

  void addPostWithImageOrText() async {
    final textController = TextEditingController();
    String? imageUrl;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.yellow[200],
          title: Text('Add Post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              MaterialButton(
                color: Colors.yellow,
                onPressed: () async {
                  imageUrl = await getImage();
                  setState(() {});
                },
                child: Text('Select Image'),
              ),
              SizedBox(height: 10),
              TextField(
                controller: textController,
                decoration: InputDecoration(
                  hintText: 'Enter your post...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            MaterialButton(
              color: Colors.yellow,
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            MaterialButton(
              color: Colors.yellow,
              onPressed: () {
                Navigator.pop(context, textController.text);
              },
              child: Text('Post'),
            ),
          ],
        );
      },
    ).then((value) {
      if (value != null && value.toString().isNotEmpty) {
        addPost(value.toString(), imageUrl ?? '');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.yellow[200],
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        title: Center(
          child: Text(
            'Post Feed',
          ),
        ),
      ),
      body: FutureBuilder<List<Post>>(
        future: futurePosts,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No Posts Available'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final post = snapshot.data![index];
                return Column(
                  children: [
                    if (post.imageUrl.isNotEmpty)
                      Container(
                        height: 430,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: FileImage(File(post.imageUrl)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ListTile(
                      title: Text(
                        post.content,
                      ),
                      subtitle: Text(
                        'Likes: ${post.likes}',
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            post.isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: post.isLiked ? Colors.red : null,
                          ),
                          onPressed: () {
                            likePost(post.id);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () {
                            deletePost(post.id);
                          },
                        ),
                      ],
                    ),
                    Divider(),
                  ],
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.yellow,
        onPressed: () {
          addPostWithImageOrText();
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
