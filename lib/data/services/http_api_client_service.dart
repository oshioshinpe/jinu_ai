import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// HTTP API Client Service for AI to make HTTP requests
class HttpApiClientService {
  final http.Client _httpClient = http.Client();
  
  // Default timeout for requests
  static const Duration _defaultTimeout = Duration(seconds: 30);
  
  // Maximum response size to prevent memory issues (5MB)
  static const int _maxResponseSize = 5 * 1024 * 1024;

  HttpApiClientService();

  /// Dispose the HTTP client
  void dispose() {
    _httpClient.close();
  }

  /// Make a GET request
  Future<Map<String, dynamic>> makeGetRequest({
    required String url,
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Duration? timeout,
  }) async {
    try {
      // Build URL with query parameters
      final uri = _buildUri(url, queryParameters);
      
      // Prepare headers
      final requestHeaders = _prepareHeaders(headers);
      
      debugPrint('Making GET request to: $uri');
      debugPrint('Headers: $requestHeaders');
      
      // Make the request
      final response = await _httpClient
          .get(uri, headers: requestHeaders)
          .timeout(timeout ?? _defaultTimeout);
      
      return _processResponse(response, 'GET', url);
    } catch (e) {
      return _handleError(e, 'GET', url);
    }
  }

  /// Make a POST request
  Future<Map<String, dynamic>> makePostRequest({
    required String url,
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    dynamic body,
    Duration? timeout,
  }) async {
    try {
      // Build URL with query parameters
      final uri = _buildUri(url, queryParameters);
      
      // Prepare headers and body
      final requestHeaders = _prepareHeaders(headers);
      final requestBody = _prepareBody(body, requestHeaders);
      
      debugPrint('Making POST request to: $uri');
      debugPrint('Headers: $requestHeaders');
      debugPrint('Body: ${requestBody?.substring(0, (requestBody.length > 200) ? 200 : requestBody.length)}${(requestBody?.length ?? 0) > 200 ? '...' : ''}');
      
      // Make the request
      final response = await _httpClient
          .post(uri, headers: requestHeaders, body: requestBody)
          .timeout(timeout ?? _defaultTimeout);
      
      return _processResponse(response, 'POST', url);
    } catch (e) {
      return _handleError(e, 'POST', url);
    }
  }

  /// Make a PATCH request
  Future<Map<String, dynamic>> makePatchRequest({
    required String url,
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    dynamic body,
    Duration? timeout,
  }) async {
    try {
      // Build URL with query parameters
      final uri = _buildUri(url, queryParameters);
      
      // Prepare headers and body
      final requestHeaders = _prepareHeaders(headers);
      final requestBody = _prepareBody(body, requestHeaders);
      
      debugPrint('Making PATCH request to: $uri');
      debugPrint('Headers: $requestHeaders');
      debugPrint('Body: ${requestBody?.substring(0, (requestBody.length > 200) ? 200 : requestBody.length)}${(requestBody?.length ?? 0) > 200 ? '...' : ''}');
      
      // Make the request
      final response = await _httpClient
          .patch(uri, headers: requestHeaders, body: requestBody)
          .timeout(timeout ?? _defaultTimeout);
      
      return _processResponse(response, 'PATCH', url);
    } catch (e) {
      return _handleError(e, 'PATCH', url);
    }
  }

  /// Make a DELETE request
  Future<Map<String, dynamic>> makeDeleteRequest({
    required String url,
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Duration? timeout,
  }) async {
    try {
      // Build URL with query parameters
      final uri = _buildUri(url, queryParameters);
      
      // Prepare headers
      final requestHeaders = _prepareHeaders(headers);
      
      debugPrint('Making DELETE request to: $uri');
      debugPrint('Headers: $requestHeaders');
      
      // Make the request
      final response = await _httpClient
          .delete(uri, headers: requestHeaders)
          .timeout(timeout ?? _defaultTimeout);
      
      return _processResponse(response, 'DELETE', url);
    } catch (e) {
      return _handleError(e, 'DELETE', url);
    }
  }

  /// Make a PUT request
  Future<Map<String, dynamic>> makePutRequest({
    required String url,
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    dynamic body,
    Duration? timeout,
  }) async {
    try {
      // Build URL with query parameters
      final uri = _buildUri(url, queryParameters);
      
      // Prepare headers and body
      final requestHeaders = _prepareHeaders(headers);
      final requestBody = _prepareBody(body, requestHeaders);
      
      debugPrint('Making PUT request to: $uri');
      debugPrint('Headers: $requestHeaders');
      debugPrint('Body: ${requestBody?.substring(0, (requestBody.length > 200) ? 200 : requestBody.length)}${(requestBody?.length ?? 0) > 200 ? '...' : ''}');
      
      // Make the request
      final response = await _httpClient
          .put(uri, headers: requestHeaders, body: requestBody)
          .timeout(timeout ?? _defaultTimeout);
      
      return _processResponse(response, 'PUT', url);
    } catch (e) {
      return _handleError(e, 'PUT', url);
    }
  }

  /// Build URI with query parameters
  Uri _buildUri(String url, Map<String, String>? queryParameters) {
    final uri = Uri.parse(url);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      return uri.replace(queryParameters: {
        ...uri.queryParameters,
        ...queryParameters,
      });
    }
    return uri;
  }

  /// Prepare headers with defaults
  Map<String, String> _prepareHeaders(Map<String, String>? headers) {
    final requestHeaders = <String, String>{
      'User-Agent': 'JinuAI-HttpClient/1.0',
    };
    
    if (headers != null) {
      requestHeaders.addAll(headers);
    }
    
    return requestHeaders;
  }

  /// Prepare request body
  String? _prepareBody(dynamic body, Map<String, String> headers) {
    if (body == null) return null;
    
    if (body is String) {
      return body;
    } else if (body is Map || body is List) {
      // Set content-type to JSON if not already set
      if (!headers.containsKey('Content-Type') && !headers.containsKey('content-type')) {
        headers['Content-Type'] = 'application/json';
      }
      return jsonEncode(body);
    } else {
      return body.toString();
    }
  }

  /// Process HTTP response
  Map<String, dynamic> _processResponse(http.Response response, String method, String url) {
    try {
      // Check response size
      if (response.bodyBytes.length > _maxResponseSize) {
        return {
          'success': false,
          'error': 'Response too large (${(response.bodyBytes.length / 1024 / 1024).toStringAsFixed(1)}MB). Maximum allowed: ${(_maxResponseSize / 1024 / 1024).toStringAsFixed(1)}MB',
          'statusCode': response.statusCode,
          'method': method,
          'url': url,
        };
      }

      // Parse response body
      dynamic responseBody;
      String contentType = response.headers['content-type'] ?? '';
      
      if (contentType.contains('application/json')) {
        try {
          responseBody = jsonDecode(response.body);
        } catch (e) {
          responseBody = response.body;
        }
      } else {
        responseBody = response.body;
      }

      // Determine if request was successful
      bool isSuccess = response.statusCode >= 200 && response.statusCode < 300;

      return {
        'success': isSuccess,
        'statusCode': response.statusCode,
        'headers': response.headers,
        'body': responseBody,
        'method': method,
        'url': url,
        'contentType': contentType,
        'responseSize': response.bodyBytes.length,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to process response: $e',
        'statusCode': response.statusCode,
        'method': method,
        'url': url,
      };
    }
  }

  /// Handle errors
  Map<String, dynamic> _handleError(dynamic error, String method, String url) {
    String errorMessage;
    
    if (error is SocketException) {
      errorMessage = 'Network error: ${error.message}';
    } else if (error is HttpException) {
      errorMessage = 'HTTP error: ${error.message}';
    } else if (error is FormatException) {
      errorMessage = 'Invalid URL format: ${error.message}';
    } else if (error.toString().contains('TimeoutException')) {
      errorMessage = 'Request timeout';
    } else {
      errorMessage = 'Request failed: $error';
    }

    debugPrint('HTTP $method request failed for $url: $errorMessage');

    return {
      'success': false,
      'error': errorMessage,
      'method': method,
      'url': url,
    };
  }

  /// Validate URL
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Parse headers from string format "key1:value1,key2:value2"
  static Map<String, String>? parseHeadersString(String? headersString) {
    if (headersString == null || headersString.trim().isEmpty) {
      return null;
    }

    try {
      final headers = <String, String>{};
      final pairs = headersString.split(',');
      
      for (final pair in pairs) {
        final parts = pair.split(':');
        if (parts.length == 2) {
          final key = parts[0].trim();
          final value = parts[1].trim();
          if (key.isNotEmpty && value.isNotEmpty) {
            headers[key] = value;
          }
        }
      }
      
      return headers.isNotEmpty ? headers : null;
    } catch (e) {
      debugPrint('Error parsing headers string: $e');
      return null;
    }
  }

  /// Parse query parameters from string format "key1=value1&key2=value2"
  static Map<String, String>? parseQueryParamsString(String? queryString) {
    if (queryString == null || queryString.trim().isEmpty) {
      return null;
    }

    try {
      final params = <String, String>{};
      final pairs = queryString.split('&');
      
      for (final pair in pairs) {
        final parts = pair.split('=');
        if (parts.length == 2) {
          final key = Uri.decodeComponent(parts[0].trim());
          final value = Uri.decodeComponent(parts[1].trim());
          if (key.isNotEmpty) {
            params[key] = value;
          }
        }
      }
      
      return params.isNotEmpty ? params : null;
    } catch (e) {
      debugPrint('Error parsing query parameters string: $e');
      return null;
    }
  }
}