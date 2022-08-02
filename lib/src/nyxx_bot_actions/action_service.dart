import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:cardboard_bot/src/google_cloud_services/google_cloud_service.dart';
import 'package:nyxx/nyxx.dart';

import 'action.dart';

abstract class ActionService<A extends Action> {
  final JsonEncoder _jsonEncoder = JsonEncoder.withIndent("  ");
  Map<int, SplayTreeMap<String, A>> _actionStoreCache = {};
  INyxxWebsocket bot;

  ActionService(this.bot);

  String getName();

  void bootAction(A? action);

  void shutdownAction(A? action);

  A actionFromJson(Map<String, dynamic> json);

  String getFileName() => getName();

  Future<A> upsert(A newAction) async {
    //Update Store
    _actionStoreCache
        .putIfAbsent(
      newAction.ownerId.id,
      () => SplayTreeMap<String, A>(),
    )
        .update(
      newAction.getId(),
      (A oldAction) {
        shutdownAction(oldAction);
        return newAction;
      },
      ifAbsent: () {
        return newAction;
      },
    );

    //Attach action
    bootAction(newAction);

    //Update Persisted Storage
    // await _persistToStorage();
    await _persistToCloudStorage();
    return newAction;
  }

  Future<A?> delete(Snowflake ownerId, String id) async {
    //Update Store
    A? action = _actionStoreCache[ownerId.id]?.remove(id);

    //Detach Action
    shutdownAction(action);

    //Update Persisted Storage
    // if (action != null) await _persistToStorage();
    if (action != null) await _persistToCloudStorage();
    return action;
  }

  List<A> getActions({Snowflake? ownerId}) {
    if (ownerId != null) return _actionStoreCache[ownerId.id]?.values.toList() ?? <A>[];
    return _actionStoreCache.values
        .expand<A>(
          (element) => element.values,
        )
        .toList();
  }

  Future<ActionService<A>> boot() async {
    // await _loadFromStorage();
    await _readFromCloudStorage();
    getActions().forEach((action) {
      shutdownAction(action);
      bootAction(action);
    });
    return this;
  }

  Future<void> _readFromCloudStorage() async {
    List<A>? actions = await GoogleCloudService().readList<A>(
      fromJson: (dynamic d) => actionFromJson(d as Map<String, dynamic>),
      name: getFileName(),
    );
    _actionStoreCache = actions == null
        ? {}
        : {
            for (var ownerIdString in actions.map<int>((e) => e.ownerId.id).toSet())
              ownerIdString: SplayTreeMap.from(
                {
                  for (var action in actions.where((A element) => element.ownerId.id == ownerIdString)) action.getId(): action,
                },
              )
          };
  }

  Future<void> _persistToCloudStorage() async {
    await GoogleCloudService().write(
      name: getFileName(),
      object: _actionStoreCache.values.expand<A>((element) => element.values).toList(),
    );
  }

  Future<void> _persistToStorage() async {
    var file = await File('cardboard_bot/data/actions/${getFileName()}.json').create(recursive: true);
    await file.writeAsString(_encode(_actionStoreCache));
  }

  Future<void> _loadFromStorage() async {
    var file = File('cardboard_bot/data/actions/${getFileName()}.json');
    if (await file.exists()) {
      _actionStoreCache = _decode(await file.readAsString());
    } else {
      _actionStoreCache = <int, SplayTreeMap<String, A>>{};
    }
  }

  Map<int, SplayTreeMap<String, A>> _decode(String string) {
    List<A> actions = (json.decode(string) as List)
        .cast<Map<String, dynamic>>()
        .map<A>(
          (e) => actionFromJson(e),
        )
        .toList();
    return {
      for (var ownerIdString in actions.map<int>((e) => e.ownerId.id).toSet())
        ownerIdString: SplayTreeMap.from(
          {
            for (var action in actions.where((A element) => element.ownerId.id == ownerIdString)) action.getId(): action,
          },
        )
    };
  }

  String _encode(Map<int, SplayTreeMap<String, A>> map) {
    return _jsonEncoder.convert(
      map.values
          .expand(
            (element) => element.values,
          )
          .toList(),
    );
  }
}
