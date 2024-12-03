import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:user_application/screens/home_page.dart' ;

Future<void> saveActiveRide(String rideId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('activeRideId', rideId);
  }

class BookingService{
  // Function to save ride information

  static Future<String> bookRide(pickupController, pickupLatLng, destinationController, destinationLatLng, auth, isShareable, selectedDateTime, fareAmount) async {
    final DatabaseReference userRideRef = FirebaseDatabase.instance.ref().child('user_ride/${auth.currentUser?.uid}');
    final ref = FirebaseDatabase.instance.ref().child('rides').push();
    Map<String, dynamic> pickup = {
      'latitude': pickupLatLng.latitude,
      'longitude': pickupLatLng.longitude,
    };
    Map<String, dynamic> destination = {
      'latitude': destinationLatLng.latitude,
      'longitude': destinationLatLng.longitude,
    };

    print(auth.currentUser?.uid);

    try{
    await ref.set({
      'pickup': pickupController.text,
      'pickup_location': pickup,
      'destination': destinationController.text,
      'destination_location': destination,
      'user': auth.currentUser?.uid,
      'share': isShareable,
      'assigned': false,
      'participant_count': 1,
      'fare': fareAmount,
      'time': selectedDateTime?.toIso8601String(),
    }); 
    await ref.child('participants').set({
      'user' : auth.currentUser?.uid,
    });
    }catch(e){
      print('Failed to upload ride data: $e');
    }
    if (ref.key != null) {
      saveActiveRide(ref.key!);
    } else {
      print('Error: Ride ID is null.');
    }

    try {
      await userRideRef.set({
        'currentRideId': ref.key!,
        'paid': false,
      });
      print('Ride booked successfully for user: ${auth.currentUser?.uid}');
    } catch (e) {
      print('Error booking ride: $e');
    }

    return ref.key! ;
  }

  static Future<void> cancelRide(String rideId, auth) async {
    // Construct the reference to the ride in the Realtime Database
    final rideRef = FirebaseDatabase.instance
        .ref()
        .child('rides')
        .child(rideId);
    final userrideRef = FirebaseDatabase.instance
        .ref()
        .child('user_ride')
        .child(auth.currentUser?.uid);
    final partRef = FirebaseDatabase.instance
        .ref()
        .child('rides')
        .child(rideId)
        .child('participants');
    DatabaseEvent event = await rideRef.once();
    DataSnapshot snapshot = event.snapshot;

    DatabaseEvent eventp = await partRef.once();
    DataSnapshot snapshotp = eventp.snapshot;

    if (snapshot.value != null) {
      // Cast snapshot.value to Map<dynamic, dynamic> and then to Map<String, dynamic>
      Map<String, dynamic> rideData = Map<String, dynamic>.from(snapshot.value as Map<dynamic, dynamic>);
      Map<String, dynamic> partData = Map<String, dynamic>.from(snapshotp.value as Map<dynamic, dynamic>);
      int pc = rideData['participant_count'] ;

      // Delete the ride
      if(pc == 1){
        await rideRef.remove();
      }
      else{
        if(rideData['user'] == auth.currentUser!.uid){
          await rideRef.update({
            'user' : partData['userId1'],
            'participant_count' : pc-1,
          });
          if(pc==2){
            await rideRef.child('participants').update({
              'user': partData['userId1'],
              'userId1': null,
            });
          }
          else{
            await rideRef.child('participants').update({
              'user': partData['userId1'],
              'userId1': partData['userId2'],
              'userId2': null,
            });
          }
        }
        else{
          await rideRef.update({
            'participant_count' : pc-1,
          });
          if(pc==2){
            await rideRef.child('participants').update({
              'userId1': null,
            });
          }
          else{
            if(partData['userId1'] == auth.currentUser!.uid){
              await rideRef.child('participants').update({
                'userId1': partData['userId2'],
                'userId2': null,
              });
            }
            else{
              await rideRef.child('participants').update({
                'userId2': null,
              });
            }
          }
        }
      }
    }
    await userrideRef.remove();
    // await HomeScreenState.getRideData() ;
  }
}