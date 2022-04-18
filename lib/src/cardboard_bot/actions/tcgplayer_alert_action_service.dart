import 'package:cardboard_bot/nyxx_bot_actions.dart';
import 'package:cardboard_bot/tcgplayer_caching_service.dart';
import 'package:nyxx/nyxx.dart';
import 'tcgplayer_alert_action.dart';

class TcgPlayerAlertActionService extends ActionService<TcgPlayerAlertAction> {
  final TcgPlayerCachingService _tcgPlayerService;

  TcgPlayerAlertActionService(INyxxWebsocket bot, this._tcgPlayerService) : super(bot);

  @override
  TcgPlayerAlertAction actionFromJson(Map<String, dynamic> json) {
    return TcgPlayerAlertAction.fromJson(json);
  }

  @override
  String getName() => "tcgplayer_alert";

  @override
  void bootAction(TcgPlayerAlertAction? action) {
    if (action == null) return;
    _tcgPlayerService.registerHighPrioritySkuId(action.skuId);
    action.boot(bot, _tcgPlayerService);
  }

  @override
  void shutdownAction(TcgPlayerAlertAction? action) {
    if (action == null) return;
    action.shutdown();
    if (getActions().any((a) => a.skuId == action.skuId && a.getId() != action.getId())) {
      _tcgPlayerService.unregisterHighPrioritySkuId(action.skuId);
    }
  }
}
