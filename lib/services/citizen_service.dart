import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/citizen_model.dart';


class CitizenService {


  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;



  // Get all citizens
  Stream<List<Citizen>> getCitizens() {


    return _firestore
        .collection('citizens')
        .snapshots()
        .map((snapshot) {


      return snapshot.docs.map((doc) {


        return Citizen.fromFirestore(
          doc.data(),
          doc.id,
        );


      }).toList();


    });


  }




  // Total registered citizens count
  Stream<int> getCitizenCount() {


    return _firestore
        .collection('citizens')
        .snapshots()
        .map((snapshot) {


      return snapshot.docs.length;


    });


  }


}