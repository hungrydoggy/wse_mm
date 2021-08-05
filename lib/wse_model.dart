library wse_mm;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mm/model.dart';
import 'package:mm/property.dart';
import 'package:mm/view_model.dart';

abstract class WseModel extends Model {
  static String api_server_address = 'http://localhost:3001/api';
  static String? token;
  static var _name_token_map = <String, String>{};

  static String? getNamedToken (String name) {
    if (_name_token_map.containsKey(name) == false)
      return null;
    return _name_token_map[name];
  }

  static void setNamedToken (String name, String token) {
    _name_token_map[name] = token;
  }

  static void removeNamedToken (String name) {
    _name_token_map.remove(name);
  }

  static void removeAllNamedTokens () {
    _name_token_map.clear();
  }

  static Future<List<dynamic>> find (
      WseModelHandler handler,
      dynamic options,
      {
        String? token_name,
        dynamic? order_query,
      }
  ) async {
    _addIdToAttributes(handler, options);

    final query_params = <String, dynamic>{ 'options': jsonEncode(options, toEncodable: _toJsonEncodable) };
    if (order_query != null)
      query_params['order_query'] = jsonEncode(order_query, toEncodable: _toJsonEncodable);
    
    var token = WseModel.token;
    if (token_name != null)
      token = getNamedToken(token_name);

    final res = await WseApiCall.get(
      '$api_server_address/${handler.path}',
      query_params: query_params,
      token: token,
    );

    final user_data = <String, dynamic>{};
    if (token_name != null)
      user_data['token_name'] = token_name;
    
    final res_jsons = (json.decode(res.body)['items'] as List<dynamic>);
    for (final rj in res_jsons) {
      registerByJson(handler, rj, user_data: user_data);
    }

    return res_jsons;
  }

  static Future<List<dynamic>> findById (
      WseModelHandler handler,
      dynamic id,
      {
        String? token_name,
        dynamic options,
        bool?   need_count,
      }
  ) async {
    // call api: get
    final query_params = <String, dynamic>{};
    if (options != null)
      query_params['options'] = jsonEncode(options, toEncodable: _toJsonEncodable);
    if (need_count != null)
      query_params['need_count'] = jsonEncode(need_count, toEncodable: _toJsonEncodable);

    var token = WseModel.token;
    if (token_name != null)
      token = getNamedToken(token_name);
    
    final res = await WseApiCall.get(
      '$api_server_address/${handler.path}/$id',
      query_params: query_params,
      token: token,
    );

    final user_data = <String, dynamic>{};
    if (token_name != null)
      user_data['token_name'] = token_name;
    
    final res_jsons = (json.decode(res.body)['items'] as List<dynamic>);
    for (final rj in res_jsons) {
      registerByJson(handler, rj, user_data: user_data);
    }

    return res_jsons;
  }

  static Model registerByJson (
      WseModelHandler handler,
      dynamic json,
      {
        Map<String, dynamic>? user_data
      }
  ) {
    if (json.containsKey(handler.id_key) == false)
      throw 'no id key for ${handler.model_name}';
    
    final id = json[handler.id_key];
    var m = Model.getModel(handler, id);
    if (m == null) {
      m = handler.newInstance(id);
      Model.putModel(handler, m);
    }
    m.setByJson(json, user_data: user_data);

    return m;
  }

  static void _addIdToAttributes(WseModelHandler mh, dynamic options) {
    // handle include
    if (options.containsKey('include')) {
      final includes = options['include'];
      if (includes is List == true) {
        for (final inc in includes) {
          if (inc is String)
            continue;
          _addIdToAttributes(mh, inc);
        }
      }
    }


    // handle attributes
    if (options.containsKey('attributes') == false)
      return;

    var attributes = options['attributes'];
    if (attributes is List == false) {
      if (attributes.containsKey('include'))
        attributes = attributes['include'] as List<dynamic>;
      
      if (attributes.containsKey('exclude')) {
        final exc = attributes['exclude'] as List<dynamic>;
        exc.remove(mh.id_key);
      }
    }

    attributes.firstWhere(
        (e) => e==mh.id_key,
        orElse: () { attributes.add(mh.id_key); return ''; },
    );
  }
  

  String? token_name;


  @override
  void setByJson (
      dynamic json,
      {
        Map<String, dynamic>? user_data,
      }
  ) {
    if (user_data != null && user_data.containsKey('token_name'))
      token_name = user_data['token_name'];

    // process for results by include
    final wse_mh = handler as WseModelHandler;
    for (final key in json.keys) {
      if (key[0] != '*')
        continue;
      
      if (wse_mh.key_nestedhandler.containsKey(key) == false) {
        print('no nested key "$key" in $model_name');
        continue;
      }

      if (json[key] == null)
        continue;

      final nested_mh = wse_mh.key_nestedhandler[key]!;
      final __setObjByJson = (Map<String, dynamic> obj) {
        if (obj.containsKey(nested_mh.id_key) == false) {
          print('no ${nested_mh.model_name}.id of nested key "$key" in $model_name');
          return;
        }
        
        final m = Model.getOrNewModel(nested_mh, obj[nested_mh.id_key]!);
        m.setByJson(obj, user_data: user_data);
      };

      if (json[key] is List<dynamic>) {
        for (final o in json[key] as List<dynamic>) {
          __setObjByJson(o as Map<String, dynamic>);
        }
      }else {
        __setObjByJson(json[key] as Map<String, dynamic>);
      }
    }

    // set self
    super.setByJson(json, user_data: user_data);
  }

  @override
  Future<void> onFetch (
      List<Property> properties,
      Map<String, dynamic>? user_data,
  ) async {
    if (properties.isEmpty)
      return;
    
    user_data ??= {};
    if (user_data.containsKey('token_name'))
      token_name = user_data['token_name'];
    user_data['token_name'] = token_name;

    var token = WseModel.token;
    if (token_name != null)
      token = getNamedToken(token_name!);

    // call api: get by id
    final options = '{"attributes":[${properties.map<String>((e)=>'"'+e.name+'"').join(',')},"id"]}';
    final wse_sel = handler as WseModelHandler;
    final res = await WseApiCall.get(
      '$api_server_address/${wse_sel.path}/$id',
      query_params: {
        "options": options,
      },
      token: token,
    );
    
    final res_json = (json.decode(res.body)['items'] as List<dynamic>)[0];
    setByJson(res_json, user_data: user_data);

    Model.putModel(handler, this);

    if (user_data.containsKey('postOnFetch')) {
      user_data['postOnFetch'](res_json);
    }
  }

  @override
  Future<void> onUpdate (
      Map<Property, dynamic> property_value_map,
      Map<String, dynamic>? user_data,
  ) async {
    final params = <String, dynamic>{};
    for (final property in property_value_map.keys) {
      final value = property_value_map[property];
      params[property.name] = value;
    }

    user_data ??= {};
    if (user_data.containsKey('token_name'))
      token_name = user_data['token_name'];

    var token = WseModel.token;
    if (token_name != null)
      token = getNamedToken(token_name!);

    // call api: put
    final wse_sel = handler as WseModelHandler;
    final res = await WseApiCall.put(
      '$api_server_address/${wse_sel.path}/$id',
      body: {
        'params': params,
      },
      token: token,
    );

    if (user_data.containsKey('postOnFetch')) {
      user_data['postOnFetch'](id);
    }
  }
}


abstract class WseModelHandler extends ModelHandler {
  String get path;
  String get id_key;
  Map<String, WseModelHandler> get key_nestedhandler;

  @override
  bool isValidKey (String key) {
    return key_nestedhandler.containsKey(key) || super.isValidKey(key);
  }

  @override
  Future<T?> onCreate<T extends Model>(
      Map<Property, dynamic> property_value_map,
      Map<String, dynamic>? user_data,
  ) async {
    final params = <String, dynamic>{};
    for (final property in property_value_map.keys) {
      final value = property_value_map[property];
      params[property.name] = value;
    }

    String? token_name;
    user_data ??= {};
    if (user_data.containsKey('token_name'))
      token_name = user_data['token_name'];
    user_data['token_name'] = token_name;

    var token = WseModel.token;
    if (token_name != null)
      token = WseModel.getNamedToken(token_name);

    // call api: post
    final res = await WseApiCall.post(
      '${WseModel.api_server_address}/$path',
      body: {
        'params': params,
      },
      token: token,
    );

    final res_json = (json.decode(res.body)['items'] as List<dynamic>)[0];
    final m = newInstance(res_json['id']);
    m.setByJson(res_json, user_data: user_data);

    if (user_data.containsKey('postOnCreate')) {
      user_data['postOnCreate'](m, res_json);
    }

    return m as T;
  }

  @override
  Future<void> onDelete(
      id,
      Map<String, dynamic>? user_data,
  ) async {
    String? token_name;
    user_data ??= {};
    if (user_data.containsKey('token_name'))
      token_name = user_data['token_name'];

    var token = WseModel.token;
    if (token_name != null)
      token = WseModel.getNamedToken(token_name);
    
    // call api: delete
    final res = await WseApiCall.delete(
      '${WseModel.api_server_address}/$path/$id',
      token: token,
    );

    if (user_data.containsKey('postOnDelete')) {
      user_data['postOnDelete'](id);
    }
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
    for (final k in query_params.keys) {
      final v = query_params[k];
      if (v is int || v is double)
        query_params[k] = v.toString();
    }

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
    for (final k in query_params.keys) {
      final v = query_params[k];
      if (v is int || v is double)
        query_params[k] = v.toString();
    }

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
        body: jsonEncode(body, toEncodable: _toJsonEncodable),
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
        body: jsonEncode(body, toEncodable: _toJsonEncodable),
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
  dynamic _body;

  int     get status     => _status;
  String  get error_code => _error_code;
  String  get message    => _message;
  dynamic get body       => _body;

  WseApiCallExeption (this._response) {
    _status     = _response.statusCode;
    try {
      final body = jsonDecode(_response.body);
      if (body['error_code'] != null)
        _error_code = body['error_code'];
      if (body['message'] != null)
        _message = body['message'];
      
      _body = body;
      
    // ignore: empty_catches
    }catch (e) {
    }
  }

  @override
  String toString() {
    return '# WseApiCallExeption\nstatus: $_status\nerror_code: $_error_code\nmessage: $_message';
  }
}


Object? _toJsonEncodable (Object? obj) {
  if (obj is DateTime)
    return obj.toIso8601String();
  return obj;
}