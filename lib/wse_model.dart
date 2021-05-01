import 'dart:convert';

import 'package:mm/model.dart';
import 'package:mm/property.dart';


abstract class WseModel extends Model {

  static Future<List<T>> find<T extends Model> (
      WseModelSelector selector,
      Map<String, dynamic> options,
      Map<String, dynamic> order_query,
  ) async {
    final res = '[{"id":1, "name":"john Kim", "age": 35},{"id":2, "name":"gh Seo", "age": 36}]';
    final res_jsons = json.decode(res) as List<dynamic>;
    return res_jsons.map<T>((e) {
      final id = e[selector.id_key];
      var m = Model.getModel(selector, id) as T?;
      if (m == null) {
        m = selector.newInstance(id) as T?;
        Model.putModel(selector, m!);
      }
      m.setByJson(e);
      return m;
    }).toList();
  }

  @override
  Future<void> onFetch (List<Property> properties) async {
    final options = '{"attributes":[${properties.map<String>((e)=>'"'+e.name+'"').join(',')}]}';

    // TODO call api: get by id
    final res = '[{"name": "john Kim", "age": 35}]';  // FIXME
    await Future.delayed(Duration(milliseconds: 2000));
    final res_json = (json.decode(res) as List<dynamic>)[0];
    setByJson(res_json);

    Model.putModel(selector, this);
  }

  @override
  Future<void> onUpdate (Map<Property, dynamic> property_value_map) async {
    final params = '{${property_value_map.keys.map<String>((e)=>'"${e.name}":${(property_value_map[e] is String)? ('"'+property_value_map[e]+'"'): property_value_map[e]}').join(',')}}';

    // TODO call api: put
    print(params);
  }
}


abstract class WseModelSelector extends ModelSelector {
  String get path;
  String get id_key;

  @override
  Future<T?> onCreate<T extends Model>(Map<Property, dynamic> property_value_map) async {
    final params = '{${property_value_map.keys.map<String>((e)=>'"${e.name}": ${(property_value_map[e] is String)? '"${property_value_map[e]}"': property_value_map[e]}').join(',')}}';

    // TODO call api: post
    print(params);
    return null;
  }

  @override
  Future<void> onDelete(id) async {
    // TODO call api: delete
  }
}