# HTTP API Tools for AI - Documentation

## Overview

The AI now has access to HTTP API tools that allow it to make HTTP requests to external APIs. This enables the AI to:

- Fetch data from REST APIs
- Send data to web services
- Interact with third-party services
- Perform CRUD operations on remote resources

## Available HTTP Tools

### 1. `http_get_request`
**Purpose:** Retrieve data from an API endpoint

**Parameters:**
- `url` (required): Complete URL with http:// or https://
- `headers` (optional): Headers in format "key1:value1,key2:value2"
- `query_params` (optional): Query parameters in format "key1=value1&key2=value2"

**Example Usage:**
```
Use http_get_request to fetch user data from https://jsonplaceholder.typicode.com/users/1
```

### 2. `http_post_request`
**Purpose:** Send data to create new resources

**Parameters:**
- `url` (required): Complete URL with http:// or https://
- `headers` (optional): Headers in format "key1:value1,key2:value2"
- `query_params` (optional): Query parameters in format "key1=value1&key2=value2"
- `body` (optional): Request body as JSON string or plain text

**Example Usage:**
```
Use http_post_request to create a new user at https://jsonplaceholder.typicode.com/users with body {"name": "John Doe", "email": "john@example.com"}
```

### 3. `http_patch_request`
**Purpose:** Partially update existing resources

**Parameters:**
- `url` (required): Complete URL with http:// or https://
- `headers` (optional): Headers in format "key1:value1,key2:value2"
- `query_params` (optional): Query parameters in format "key1=value1&key2=value2"
- `body` (optional): Request body as JSON string or plain text

**Example Usage:**
```
Use http_patch_request to update user email at https://jsonplaceholder.typicode.com/users/1 with body {"email": "newemail@example.com"}
```

### 4. `http_put_request`
**Purpose:** Completely replace existing resources

**Parameters:**
- `url` (required): Complete URL with http:// or https://
- `headers` (optional): Headers in format "key1:value1,key2:value2"
- `query_params` (optional): Query parameters in format "key1=value1&key2=value2"
- `body` (optional): Request body as JSON string or plain text

**Example Usage:**
```
Use http_put_request to replace user data at https://jsonplaceholder.typicode.com/users/1 with complete user object
```

### 5. `http_delete_request`
**Purpose:** Remove resources from the server

**Parameters:**
- `url` (required): Complete URL with http:// or https://
- `headers` (optional): Headers in format "key1:value1,key2:value2"
- `query_params` (optional): Query parameters in format "key1=value1&key2=value2"

**Example Usage:**
```
Use http_delete_request to delete user at https://jsonplaceholder.typicode.com/users/1
```

## Header Format

Headers should be provided as a comma-separated string of key:value pairs:

**Examples:**
- `"Content-Type:application/json"`
- `"Authorization:Bearer your-token-here,Content-Type:application/json"`
- `"X-API-Key:your-api-key,Accept:application/json,User-Agent:MyApp/1.0"`

## Query Parameters Format

Query parameters should be provided as an ampersand-separated string of key=value pairs:

**Examples:**
- `"page=1&limit=10"`
- `"search=john&sort=name&order=asc"`
- `"filter=active&include=profile"`

## Request Body Format

The request body can be:
- **JSON string:** `'{"name": "John", "age": 30}'`
- **Plain text:** `"Hello, World!"`
- **Form data:** `"name=John&age=30"`

When sending JSON, the Content-Type header will automatically be set to `application/json` if not specified.

## Response Format

The AI receives responses in a structured format:

### Successful Response
```
✅ HTTP GET request successful
Status Code: 200
URL: https://api.example.com/users
Content-Type: application/json
Response Size: 1.2 KB

Response Body:
{
  "users": [
    {"id": 1, "name": "John Doe"},
    {"id": 2, "name": "Jane Smith"}
  ]
}
```

### Failed Response
```
❌ HTTP POST request failed
URL: https://api.example.com/users
Status Code: 400
Error: Bad Request - Invalid JSON format
```

## Security Features

### URL Validation
- Only HTTP and HTTPS URLs are allowed
- URLs are validated before making requests

### Response Size Limits
- Maximum response size: 5MB
- Large responses are truncated with a warning

### Request Timeouts
- Default timeout: 30 seconds
- Prevents hanging requests

### Response Truncation
- Responses longer than 2000 characters are truncated
- Full response data is still processed, only display is truncated

## Common Use Cases

### 1. API Data Fetching
```
Fetch weather data from OpenWeatherMap API for New York
```

### 2. User Authentication
```
Login to the API using POST request with username and password
```

### 3. Data Submission
```
Submit a contact form to the website's API endpoint
```

### 4. Resource Management
```
Create, read, update, and delete blog posts via REST API
```

### 5. Third-party Integrations
```
Send a message to Slack webhook or Discord webhook
```

## Error Handling

The HTTP tools handle various error scenarios:

- **Network errors:** Connection timeouts, DNS failures
- **HTTP errors:** 4xx and 5xx status codes
- **Invalid URLs:** Malformed or non-HTTP URLs
- **Large responses:** Automatic truncation with warnings
- **JSON parsing errors:** Graceful fallback to plain text

## Best Practices

### 1. Always Include Required Headers
For APIs requiring authentication:
```
headers: "Authorization:Bearer your-token,Content-Type:application/json"
```

### 2. Use Appropriate HTTP Methods
- GET: Retrieve data
- POST: Create new resources
- PATCH: Partial updates
- PUT: Complete replacement
- DELETE: Remove resources

### 3. Handle API Rate Limits
Be mindful of API rate limits and include appropriate delays between requests.

### 4. Validate Responses
Always check the response status and handle errors appropriately.

### 5. Use Query Parameters for Filtering
```
query_params: "limit=10&offset=20&sort=created_at"
```

## Integration with Memory

The HTTP API tools work seamlessly with the memory system:

```
1. Make an API request to fetch user data
2. Save important information to memory for future reference
3. Use saved API keys or endpoints from memory in subsequent requests
```

## Example Workflows

### Weather Information Workflow
1. Use `http_get_request` to fetch weather data
2. Save location preferences to memory
3. Format and present weather information

### User Management Workflow
1. Use `http_get_request` to list users
2. Use `http_post_request` to create new users
3. Use `http_patch_request` to update user details
4. Use `http_delete_request` to remove users

### Data Synchronization Workflow
1. Use `http_get_request` to fetch remote data
2. Compare with local memory
3. Use `http_post_request` or `http_patch_request` to sync changes
4. Update local memory with new data

This HTTP API integration makes the AI much more powerful and capable of interacting with the broader web ecosystem while maintaining security and reliability.