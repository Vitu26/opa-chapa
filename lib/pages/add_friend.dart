import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:rxdart/rxdart.dart';

class AddFriend extends StatefulWidget {
  const AddFriend({Key? key});

  @override
  State<AddFriend> createState() => _AddFriendState();
}

class _AddFriendState extends State<AddFriend> {
  // Controlador para o campo de pesquisa
  TextEditingController _searchController = TextEditingController();

  // Lista para armazenar os resultados da pesquisa
  List<DocumentSnapshot> _searchResults = [];

  // Assunto para ouvir as mudanças no campo de pesquisa com debounce
  final _searchSubject = BehaviorSubject<String>();

  // Lista para armazenar os UIDs dos amigos adicionados
  List<String> addedFriendsUIDs = [];

  // Mensagem de feedback
  String _feedbackMessage = '';

  @override
  void initState() {
    super.initState();

    // Configurar um observador para o campo de pesquisa com debounce
    _searchSubject.stream
        .debounceTime(Duration(milliseconds: 300))
        .listen((name) async {
      if (name.length >= 2) {
        // Pesquisar usuários pelo nome e atualizar os resultados
        List<DocumentSnapshot> results = await searchUsersByName(name);
        setState(() {
          _searchResults = results;
        });
      } else {
        setState(() {
          _searchResults = [];
        });
      }
    });
  }

  @override
  void dispose() {
    super.dispose();

    // Fechar o assunto do campo de pesquisa ao sair da tela
    _searchSubject.close();
  }

  // Verifica se um amigo já foi adicionado
  Future<bool> isFriendAdded(String friendUID) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot friendSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('friends')
          .doc(friendUID)
          .get();

      return friendSnapshot.exists;
    }
    return false;
  }

  // Pesquisa usuários pelo nome
  Future<List<DocumentSnapshot>> searchUsersByName(String name) async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('name', isEqualTo: name)
        .get();

    for (DocumentSnapshot userDoc in querySnapshot.docs) {
      if (await isFriendAdded(userDoc.id)) {
        if (!addedFriendsUIDs.contains(userDoc.id)) {
          addedFriendsUIDs.add(userDoc.id);
        }
      }
    }

    return querySnapshot.docs;
  }

  // Adiciona um amigo a outro usuário
  Future addAsFriendToOtherUser(String yourUID, String friendUID) async {
    // Obtém uma referência para o documento do usuário atual pelo UID
    DocumentSnapshot userSnapshot =
        await FirebaseFirestore.instance.collection('users').doc(yourUID).get();

    // Verifica se o documento do usuário atual existe
    if (userSnapshot.exists) {
      // Obtém os detalhes do usuário atual a partir dos dados do documento
      Map<String, dynamic> userDetails =
          userSnapshot.data()! as Map<String, dynamic>;

      // Define um documento na coleção 'friends' do usuário amigo (friendUID)
      // Este documento representa a entrada de amizade entre o usuário atual e o amigo
      await FirebaseFirestore.instance
          .collection('users')
          .doc(friendUID)
          .collection('friends')
          .doc(yourUID)
          .set({
        'friendName': userDetails['name'], // Nome do amigo
        'friendLastName': userDetails['last name'], // Sobrenome do amigo
        'friendEmail': userDetails['email'], // E-mail do amigo
        'friendPhone': userDetails['phone'], // Número de telefone do amigo
        'friendUID': yourUID, // UID do usuário atual (para referência)
        // Outros campos relevantes (se houver)
      });
    } else {
      // Se o documento do usuário atual não existe, imprime uma mensagem de erro
      print("Nenhum usuário encontrado com UID: $yourUID");
    }
  }

  // Lidar com a pesquisa de amigos
  Future<void> handleSearch() async {
    String nameToSearch = _searchController.text.trim();
    List<DocumentSnapshot> results = await searchUsersByName(nameToSearch);

    // Verificar os amigos já adicionados
    for (DocumentSnapshot userDoc in results) {
      if (await isFriendAdded(userDoc.id)) {
        if (!addedFriendsUIDs.contains(userDoc.id)) {
          addedFriendsUIDs.add(userDoc.id);
        }
      }
    }

    setState(() {
      _searchResults = results;
    });
  }

  // Adicionar um amigo a um usuário
  Future<void> addFriendToUser(String friendUID) async {
    // Imprime uma mensagem para indicar que está tentando adicionar um amigo com um determinado UID
    print("Tentando adicionar amigo com UID: $friendUID");

    // Obtém o usuário atualmente autenticado
    final User? user = FirebaseAuth.instance.currentUser;

    // Verifica se o usuário está autenticado
    if (user != null) {
      try {
        // Obtém um DocumentSnapshot que representa o documento do amigo com base no seu UID
        DocumentSnapshot friendSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(friendUID)
            .get();

        // Verifica se o documento do amigo existe
        // Verifica se o documento do amigo existe
        if (friendSnapshot.exists) {
          // Extrai os detalhes do amigo dos dados do DocumentSnapshot
          Map<String, dynamic> friendDetails =
              friendSnapshot.data()! as Map<String, dynamic>;

          // Define um novo documento na coleção 'friends' do usuário atual
          // para representar a amizade com o amigo
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid) // Usuário atual
              .collection('friends') // Coleção 'friends' do usuário atual
              .doc(friendUID) // Documento identificado pelo UID do amigo
              .set({
            'friendName': friendDetails['name'], // Nome do amigo
            'friendLastName': friendDetails['last name'], // Sobrenome do amigo
            'friendEmail': friendDetails['email'], // E-mail do amigo
            'friendPhone':
                friendDetails['phone'], // Número de telefone do amigo
            'friendUID': friendUID, // UID do amigo
            'friendProfilePictureUrl':
                friendDetails.containsKey('profile_picture_url')
                    ? friendDetails['profile_picture_url']
                    : null,
            // Outros campos relevantes (se houver)
          });

          // Define uma mensagem de feedback indicando que o amigo foi adicionado com sucesso
          setState(() {
            _feedbackMessage = 'Amigo adicionado com sucesso!';
          });

          // Chama o método addAsFriendToOtherUser para também adicionar o usuário atual
          // como amigo do amigo (bidirecional)
          await addAsFriendToOtherUser(user.uid, friendUID);
        } else {
          // Define uma mensagem de feedback indicando que nenhum usuário foi encontrado com o UID especificado
          setState(() {
            _feedbackMessage = 'Nenhum usuário encontrado com UID: $friendUID';
          });
        }
      } catch (error) {
        // Define uma mensagem de feedback indicando que ocorreu um erro ao adicionar o amigo
        setState(() {
          _feedbackMessage = 'Erro ao adicionar amigo: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Procurar por nome',
                    ),
                    onChanged: (value) {
                      _searchSubject.add(value.trim());
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.search),
                  onPressed: handleSearch,
                ),
              ],
            ),
            // Exibir feedback sobre a ação (adicionar amigo)
            _feedbackMessage.isNotEmpty
                ? Text(
                    _feedbackMessage,
                    style: TextStyle(
                      color: _feedbackMessage.startsWith('Erro')
                          ? Colors.red
                          : Colors.green,
                    ),
                  )
                : SizedBox(),
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  DocumentSnapshot userDoc = _searchResults[index];
                  bool isAdded = addedFriendsUIDs.contains(userDoc.id);

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: (userDoc.data() as Map<String, dynamic>)
                              .containsKey('profilePictureUrl')
                          ? NetworkImage(userDoc['profilePictureUrl'])
                              as ImageProvider<Object>?
                          : AssetImage(
                              'assets/images/gato-obeso.jpg'), // Corrigido o caminho para a imagem

                      radius: 25.0,
                    ),
                    title: Text(userDoc['name']),
                    subtitle: Text(userDoc['email']),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAdded ? Colors.green : null,
                      ),
                      onPressed: isAdded
                          ? null
                          : () async {
                              await addFriendToUser(userDoc.id);
                              if (!addedFriendsUIDs.contains(userDoc.id)) {
                                addedFriendsUIDs.add(userDoc.id);
                                setState(() {});
                              }
                            },
                      child: isAdded
                          ? Icon(Icons.check, color: Colors.white)
                          : Text('Adicionar'),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
