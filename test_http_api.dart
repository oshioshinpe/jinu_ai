// Simple test script for HTTP API Client
import 'dart:convert';
import 'lib/data/services/http_api_client_service.dart';

void main() async {
  print('Testing HTTP API Client Service...');
  
  final httpClient = HttpApiClientService();
  
  try {
    // Test 1: Simple GET request to a public API
    print('\n=== Test 1: GET Request ===');
    final getResult = await httpClient.makeGetRequest(
      url: 'https://jsonplaceholder.typicode.com/posts/1',
    );
    print('GET Result: ${getResult['success']}');
    print('Status Code: ${getResult['statusCode']}');
    if (getResult['success']) {
      final body = getResult['body'];
      if (body is Map) {
        print('Title: ${body['title']}');
      }
    } else {
      print('Error: ${getResult['error']}');
    }
    
    // Test 2: POST request
    print('\n=== Test 2: POST Request ===');
    final postData = {
      'title': 'Test Post',
      'body': 'This is a test post from the HTTP API client',
      'userId': 1,
    };
    
    final postResult = await httpClient.makePostRequest(
      url: 'https://jsonplaceholder.typicode.com/posts',
      body: postData,
    );
    print('POST Result: ${postResult['success']}');
    print('Status Code: ${postResult['statusCode']}');
    if (postResult['success']) {
      final body = postResult['body'];
      if (body is Map) {
        print('Created ID: ${body['id']}');
      }
    } else {
      print('Error: ${postResult['error']}');
    }
    
    // Test 3: URL validation
    print('\n=== Test 3: URL Validation ===');
    print('Valid URL (https://example.com): ${HttpApiClientService.isValidUrl('https://example.com')}');
    print('Invalid URL (not-a-url): ${HttpApiClientService.isValidUrl('not-a-url')}');
    print('Invalid URL (ftp://example.com): ${HttpApiClientService.isValidUrl('ftp://example.com')}');
    
    // Test 4: Header parsing
    print('\n=== Test 4: Header Parsing ===');
    final headers = HttpApiClientService.parseHeadersString('Content-Type:application/json,Authorization:Bearer token123');
    print('Parsed headers: $headers');
    
    // Test 5: Query parameter parsing
    print('\n=== Test 5: Query Parameter Parsing ===');
    final queryParams = HttpApiClientService.parseQueryParamsString('page=1&limit=10&sort=name');
    print('Parsed query params: $queryParams');
    
    print('\n✅ All tests completed successfully!');
    
  } catch (e) {
    print('❌ Test failed with error: $e');
  } finally {
    httpClient.dispose();
  }
}