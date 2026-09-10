import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../Services/map_service.dart';
import '../widgets/map/disaster_map.dart';

/// Rescue Team Map Screen.
///
/// Shown under the bottom navigation bar's "Map" tab for BOTH
/// the leader and members — same screen, same widget. Two tabs:
///
/// 1. Affected Zones — reuses the same `affected_zones` data
///    that the Citizen app shows (no rescue-specific query needed).
/// 2. Tasks — shows a buffer-circle polygon per active task,
///    scoped to the whole team (leader) or just the tasks
///    assigned to this member.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(
          child: Text("Not logged in."),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('rescueTeamUsers')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final data = snapshot.data!.data() ?? {};
        final bool isLeader = data['isLeader'] ?? false;
        final String teamId = data['teamId'] ?? '';

        // Leader's queries are scoped by teamId; a member's
        // queries are scoped by their own uid (assignedMemberIds).
        final String idValue = isLeader ? teamId : uid;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text(
                'Map',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
              backgroundColor: Colors.green.shade800,
              foregroundColor: Colors.white,
              bottom: const TabBar(
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(text: "Affected Zones"),
                  Tab(text: "Tasks"),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                //--------------------------------------------
                // Tab 1: Affected Zones
                // Same data source as the Citizen app, but the
                // "inside a zone" banner text is rescue-flavored.
                //--------------------------------------------
                const DisasterMap(
                  isAdmin: false,
                  isRescueView: true,
                ),

                //--------------------------------------------
                // Tab 2: Tasks
                // Buffer-circle polygons built from the tasks
                // collection, scoped by role.
                //--------------------------------------------
                DisasterMap(
                  isAdmin: true,
                  zonesStream: MapService.instance.getTaskZones(
                    isLeader: isLeader,
                    idValue: idValue,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}