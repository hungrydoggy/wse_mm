library wse_mm;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mm/model.dart';
import 'package:mm/property.dart';

abstract class WseModel extends Model {
  static String api_server_address = 'http://localhost:3001/api';
  static String? token = null;

  static Future<List<T>> find<T extends Model> (
      WseModelHandler handler,
      Map<String, dynamic> options,
      Map<String, dynamic> order_query,
  ) async {
    // TODO call api: get by id
    final res = '[{"id":1, "name":"john Kim", "age": 35},{"id":2, "name":"gh Seo", "age": 36}]';
    final res_jsons = json.decode(res) as List<dynamic>;
    return res_jsons.map<T>((e) {
      final id = e[handler.id_key];
      var m = Model.getModel(handler, id) as T?;
      if (m == null) {
        m = handler.newInstance(id) as T?;
        Model.putModel(handler, m!);
      }
      m.setByJson(e);
      return m;
    }).toList();
  }

  @override
  Future<void> onFetch (List<Property> properties) async {
    final options = '{"attributes":[${properties.map<String>((e)=>'"'+e.name+'"').join(',')}]}';

    // call api: get by id
    final wse_sel = handler as WseModelHandler;
    final res = await http.get(
        Uri(
          path:'$api_server_address/${wse_sel.path}/$id',
          queryParameters: {
            options: options,
          },
        ),
        headers: _makeHeaders(token),
    );
    if (res.statusCode ~/ 100 != 2)
      throw WseApiCallExeption(res);
    
    final res_json = (json.decode(res.body) as List<dynamic>)[0];
    setByJson(res_json);

    Model.putModel(handler, this);
  }

  @override
  Future<void> onUpdate (Map<Property, dynamic> property_value_map) async {
    final params = '{${property_value_map.keys.map<String>((e)=>'"${e.name}":${(property_value_map[e] is String)? ('"'+property_value_map[e]+'"'): property_value_map[e]}').join(',')}}';

    // call api: put
    final wse_sel = handler as WseModelHandler;
    final res = await http.put(
        Uri(
          path:'$api_server_address/${wse_sel.path}/$id',
        ),
        headers: _makeHeaders(token),
        body: {
          params: params,
        },
    );
    if (res.statusCode ~/ 100 != 2)
      throw WseApiCallExeption(res);
  }
}


abstract class WseModelHandler extends ModelHandler {
  String get path;
  String get id_key;

  @override
  Future<T?> onCreate<T extends Model>(Map<Property, dynamic> property_value_map) async {
    final params = '{${property_value_map.keys.map<String>((e)=>'"${e.name}": ${(property_value_map[e] is String)? '"${property_value_map[e]}"': property_value_map[e]}').join(',')}}';

    // call api: post
    final res = await http.post(
        Uri(
          path:'$WseModel.api_server_address/$path',
        ),
        headers: _makeHeaders(WseModel.token),
        body: {
          params: params,
        },
    );
    if (res.statusCode ~/ 100 != 2)
      throw WseApiCallExeption(res);

    final res_json = (json.decode(res.body) as List<dynamic>)[0];
    final m = newInstance(res_json.id);
    m.setByJson(res_json);

    return m as T;
  }

  @override
  Future<void> onDelete(id) async {
    // call api: delete
    final res = await http.delete(
        Uri(
          path:'$WseModel.api_server_address/$path/$id',
        ),
        headers: _makeHeaders(WseModel.token),
    );
    if (res.statusCode ~/ 100 != 2)
      throw WseApiCallExeption(res);
  }
}

class WseApiCallExeption implements Exception {
  final http.Response _response;
  int    _status     = 0;
  String _error_code = '';
  String _message    = '';

  WseApiCallExeption (this._response) {
    final body = jsonDecode(_response.body);
    _status     = _response.statusCode;
    _error_code = body.error_code;
    _message    = body.message;
  }

  @override
  String toString() {
    return '# WseApiCallExeption\nstatus: $_status\nerror_code: $_error_code\nmessage: $_message';
  }
}


Map<String, String> _makeHeaders (String? token) {
  final headers = {
    'Content-type': 'application/json',
  };
  if (token != null)
    headers['x-api-key'] = token;
  
  return headers;
}