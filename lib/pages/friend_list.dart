import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:msg_app/model/friend_profile.dart';
import 'package:msg_app/pages/friend_profile.dart';

class FriendsList extends StatefulWidget {
  @override
  State<FriendsList> createState() => _FriendsListState();
}

class _FriendsListState extends State<FriendsList> {
  List<DocumentSnapshot> _friends = [];

  @override
  void initState() {
    super.initState();
    fetchFriends();
  }

  Future<void> fetchFriends() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('friends')
          .get();

      setState(() {
        _friends = querySnapshot.docs;
      });
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _friends.isEmpty
            ? Center(
                child: Text(
                  'Não possui amigos',
                  style: TextStyle(fontSize: 18),
                ),
              )
            : GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, // 3 itens por linha
                  crossAxisSpacing: 16, // Espaçamento entre itens
                  mainAxisSpacing: 16, // Espaçamento vertical
                ),
                itemCount: _friends.length,
                itemBuilder: (context, index) {
                  DocumentSnapshot friendDoc = _friends[index];
                  Map<String, dynamic>? data =
                      friendDoc.data() as Map<String, dynamic>?;

                  // Crie um objeto FriendProfile
                  FriendProfile friendProfile = FriendProfile(
                    profilePictureUrl: data?['friendProfilePictureUrl'],
                    name: data?['friendName'],
                    lastName: data?['friendLastName'],
                    email: data?['friendEmail'],
                    phone: data?['friendPhone'],
                    uid: data?['friendUID'] ?? '',
                  );
                  String? profilePictureUrl = data?[
                      'friendProfilePictureUrl']; // Obtenha a URL da foto de perfil

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              FriendProfilePage(friendProfile: friendProfile),
                        ),
                      );
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: profilePictureUrl != null
                              ? CachedNetworkImageProvider(
                                  profilePictureUrl,
                                ) // Use CachedNetworkImageProvider para carregar a imagem da URL
                              : AssetImage('assets/images/gato-obeso.jpg')
                                  as ImageProvider<
                                      Object>?, // Se não houver foto, use uma imagem padrão
                        ),
                        SizedBox(height: 8),
                        Text(data?['friendName'] ?? ''),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
