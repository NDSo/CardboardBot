import 'dart:async';
import 'dart:collection';

import 'package:cardboard_bot/repository.dart';
import 'package:nyxx/nyxx.dart';

import 'action.dart';

abstract class ActionService<A extends Action> {
  Map<int, SplayTreeMap<String, A>> _actionStoreCache = {};
  INyxxWebsocket bot;
  final Repository<A> _repository;

  ActionService(this.bot, this._repository) {
    _boot();
  }

  void bootAction(A? action);

  void shutdownAction(A? action);

  A actionFromJson(Map<String, dynamic> json);

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
    await _repository.upsert(objects: [newAction], ids: [newAction.getId()]);
    return newAction;
  }

  Future<A?> delete(Snowflake ownerId, String id) async {
    //Update Store
    A? action = _actionStoreCache[ownerId.id]?.remove(id);

    //Detach Action
    shutdownAction(action);

    //Update Persisted Storage
    if (action != null) await _repository.delete({action.getId()});
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

  Future<ActionService<A>> _boot() async {
    // Get actions from repository
    var actions = await _repository.getAll();

    // create fast cache
    _actionStoreCache = {
      for (var ownerIdString in actions.map<int>((e) => e.ownerId.id).toSet())
        ownerIdString: SplayTreeMap.from(
          {
            for (var action in actions.where((A element) => element.ownerId.id == ownerIdString)) action.getId(): action,
          },
        )
    };

    getActions().forEach((action) {
      shutdownAction(action);
      bootAction(action);
    });
    return this;
  }
}
