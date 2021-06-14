library wse_mm;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mm/model.dart';
import 'package:mm/property.dart';
import 'package:mm/view_model.dart';

abstract class WseModel extends Model {
  static String api_server_address = 'http://localhost:3001/api';
  static String? token;

  static Future<List<dynamic>> find (
      WseModelHandler handler,
      dynamic options,
      { dynamic? order_query }
  ) async {
    // call api: get
    final query_params = <String, dynamic>{ 'options': jsonEncode(options) };
    if (order_query != null)
      query_params['order_query'] = jsonEncode(order_query);
    
    final res = await WseApiCall.get(
      '$api_server_address/${handler.path}',
      query_params: query_params,
      token: token,
    );
    
    final res_jsons = (json.decode(res.body)['items'] as List<dynamic>);
    for (final rj in res_jsons) {
      registerByJson(handler, rj);
    }

    return res_jsons;
  }

  static Future<List<dynamic>> findById (
      WseModelHandler handler,
      dynamic id,
      {
        dynamic? options,
        bool?    need_count,
      }
  ) async {
    // call api: get
    final query_params = <String, dynamic>{};
    if (options != null)
      query_params['options'] = jsonEncode(options);
    if (need_count != null)
      query_params['need_count'] = jsonEncode(need_count);
    
    final res = await WseApiCall.get(
      '$api_server_address/${handler.path}/$id',
      query_params: query_params,
      token: token,
    );
    
    final res_jsons = (json.decode(res.body)['items'] as List<dynamic>);
    for (final rj in res_jsons) {
      registerByJson(handler, rj);
    }

    return res_jsons;
  }

  static Model registerByJson (WseModelHandler handler, dynamic json) {
    if (json.containsKey(handler.id_key) == false)
      throw 'no id key for ${handler.model_name}';
    
    final id = json[handler.id_key];
    var m = Model.getModel(handler, id);
    if (m == null) {
      m = handler.newInstance(id);
      Model.putModel(handler, m);
    }
    m.setByJson(json);

    return m;
  }
  

  @override
  void setByJson (dynamic json) {
    // process for results by include
    final wse_mh = handler as WseModelHandler;
    for (final key in json.keys) {
      if (key[0] != '*')
        continue;
      
      if (wse_mh.key_nestedhandler.containsKey(key) == false) {
        print('no nested key "$key" in $model_name');
        continue;
      }

      final nested_mh = wse_mh.key_nestedhandler[key]!;
      final __setObjByJson = (Map<String, dynamic> obj) {
        if (obj.containsKey(nested_mh.id_key) == false) {
          print('no ${nested_mh.model_name}.id of nested key "$key" in $model_name');
          return;
        }
        
        final m = Model.getOrNewModel(nested_mh, obj[nested_mh.id_key]!);
        m.setByJson(obj);
      };

      if (json[key] is List<dynamic>) {
        for (final o in json[key] as List<dynamic>) {
          __setObjByJson(o as Map<String, dynamic>);
        }
      }else {
        __setObjByJson(json[key] as Map<String, dynamic>);
      }

      json.remove(key);
    }

    // set self
    super.setByJson(json);
  }

  @override
  Future<void> onFetch (List<Property> properties) async {
    if (properties.isEmpty)
      return;

    final options = '{"attributes":[${properties.map<String>((e)=>'"'+e.name+'"').join(',')}]}';

    // call api: get by id
    final wse_sel = handler as WseModelHandler;
    final res = await WseApiCall.get(
      '$api_server_address/${wse_sel.path}/$id',
      query_params: {
        "options": options,
      },
      token: token,
    );
    
    final res_json = (json.decode(res.body)['items'] as List<dynamic>)[0];
    setByJson(res_json);

    Model.putModel(handler, this);
  }

  @override
  Future<void> onUpdate (Map<Property, dynamic> property_value_map) async {
    final params = <String, dynamic>{};
    for (final property in property_value_map.keys) {
      final value = property_value_map[property];
      params[property.name] = value;
    }

    // call api: put
    final wse_sel = handler as WseModelHandler;
    final res = await WseApiCall.put(
      '$api_server_address/${wse_sel.path}/$id',
      body: {
        'params': params,
      },
      token: token,
    );
  }
}


abstract class WseModelHandler extends ModelHandler {
  String get path;
  String get id_key;
  Map<String, WseModelHandler> get key_nestedhandler;

  @override
  Future<T?> onCreate<T extends Model>(Map<Property, dynamic> property_value_map) async {
    final params = <String, dynamic>{};
    for (final property in property_value_map.keys) {
      final value = property_value_map[property];
      params[property.name] = value;
    }

    // call api: post
    final res = await WseApiCall.post(
      '${WseModel.api_server_address}/$path',
      body: {
        'params': params,
      },
      token: WseModel.token,
    );

    final res_json = (json.decode(res.body)['items'] as List<dynamic>)[0];
    final m = newInstance(res_json['id']);
    m.setByJson(res_json);

    return m as T;
  }

  @override
  Future<void> onDelete(id) async {
    // call api: delete
    final res = await WseApiCall.delete(
      '${WseModel.api_server_address}/$path/$id',
      token: WseModel.token,
    );
  }
}


class WseApiCall {

  static Future<http.Response> get (
      String path,
      {
        dynamic query_params = const <String, dynamic>{},
        String? token,
      }
  ) async {
    final uri = Uri.parse(path);
    final res = await http.get(
        Uri(
          scheme: uri.scheme,
          host: uri.host,
          port: uri.port,
          path: uri.path,
          queryParameters: query_params,
        ),
        headers: _makeHeaders(token),
    );
    if (res.statusCode ~/ 100 != 2)
      throw WseApiCallExeption(res);
    
    return res;
  }

  static Future<http.Response> delete (
      String path,
      {
        dynamic query_params = const <String, dynamic>{},
        String? token,
      }
  ) async {
    final uri = Uri.parse(path);
    final res = await http.delete(
        Uri(
          scheme: uri.scheme,
          host: uri.host,
          port: uri.port,
          path: uri.path,
          queryParameters: query_params,
        ),
        headers: _makeHeaders(token),
    );
    if (res.statusCode ~/ 100 != 2)
      throw WseApiCallExeption(res);
    
    return res;
  }

  static Future<http.Response> post (
      String path,
      {
        dynamic body = const <String, dynamic>{},
        String? token,
      }
  ) async {
    final uri = Uri.parse(path);
    final res = await http.post(
        Uri(
          scheme: uri.scheme,
          host: uri.host,
          port: uri.port,
          path: uri.path,
        ),
        headers: _makeHeaders(token),
        body: jsonEncode(body),
    );
    if (res.statusCode ~/ 100 != 2)
      throw WseApiCallExeption(res);
    
    return res;
  }

  static Future<http.Response> put (
      String path,
      {
        dynamic body = const <String, dynamic>{},
        String? token,
      }
  ) async {
    final uri = Uri.parse(path);
    final res = await http.put(
        Uri(
          scheme: uri.scheme,
          host: uri.host,
          port: uri.port,
          path: uri.path,
        ),
        headers: _makeHeaders(token),
        body: jsonEncode(body),
    );
    if (res.statusCode ~/ 100 != 2)
      throw WseApiCallExeption(res);
    
    return res;
  }

  static Map<String, String> _makeHeaders (String? token) {
    final headers = {
      'Content-type': 'application/json',
    };
    if (token != null)
      headers['x-api-key'] = token;
    
    return headers;
  }
}


class WseApiCallExeption implements Exception {
  final http.Response _response;
  int    _status     = 0;
  String _error_code = '';
  String _message    = '';

  WseApiCallExeption (this._response) {
    _status     = _response.statusCode;
    try {
      final body = jsonDecode(_response.body);
      if (body['error_code'] != null)
        _error_code = body['error_code'];
      if (body['message'] != null)
        _message = body['message'];
      
    // ignore: empty_catches
    }catch (e) {
    }
  }

  @override
  String toString() {
    return '# WseApiCallExeption\nstatus: $_status\nerror_code: $_error_code\nmessage: $_message';
  }
}

