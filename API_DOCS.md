# Qwen-Sarvam vLLM API Documentation

API documentation for the Qwen-Sarvam Search vLLM server endpoints.

## Base URL

## Base URL

After deploying with `modal deploy server_vllm_v2.py`, your base URL will be:
```
https://viratgsingh99--drissy-text-drissytextvllm.modal.run
```
(Note: The client automatically appends `-search` or `-chat` to this base)

---

## Endpoints

### 1. Health Check

Check if the server is running and healthy.

**Endpoint:** `GET /health`

**Request:**
```bash
curl -X GET "https://<base-url>/health"
```

**Response:**
```json
{
  "status": "healthy",
  "model": "qwen-sarvam-vllm-v2"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `status` | string | Server health status |
| `model` | string | Model identifier |

---

### 2. Search

Generate a response based on a search query and search results. This is the primary endpoint for search-augmented generation.

**Endpoint:** `POST /search`

**Request Headers:**
```
Content-Type: application/json
```

**Request Body:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `query` | string | Yes | `""` | The user's search query |
| `search_results` | string | Yes | `""` | Search results to use as context (limited to 20k tokens) |
| `system_prompt` | string | No | Default Indian AI assistant prompt | Custom system prompt for the model |
| `max_tokens` | integer | No | `1000` | Maximum tokens to generate in the response |
| `temperature` | float | No | `0.6` | Sampling temperature default. |
| `top_p` | float | No | `0.95` | Nucleus sampling probability. |
| `top_k` | integer | No | `20` | Top-K sampling. |
| `min_p` | float | No | `0.0` | Min-P sampling. |
| `thinking` | boolean | No | `false` | Enable "Chain of Thought" reasoning. |
| `stream` | boolean | No | `false` | Set to `true` to receive Server-Sent Events (SSE) |

**Example Request:**
```bash
curl -X POST "https://<base-url>/search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Best places to visit in Mumbai",
    "search_results": "...",
    "max_tokens": 256
  }'
```

**Streaming Request:**
```bash
curl -X POST "https://<base-url>/search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Best places to visit in Mumbai",
    "search_results": "...",
    "stream": true
  }'
```

**Response (Non-streaming):**
```json
{
  "response": "Mumbai mein visit karne ke liye kaafi amazing places hain!...",
  "inference_ms": 450.23,
  "total_ms": 520.15,
  "lora_applied": true
}
```

**Response (Streaming):**
Received as Server-Sent Events (SSE). Each event contains a JSON data chunk.
```
data: "Mumbai"
data: " mein"
data: " visit"
...
data: "[DONE]"
```

| Field | Type | Description |
|-------|------|-------------|
| `response` | string | Generated response from the model |
| `inference_ms` | float | Model inference time in milliseconds |
| `total_ms` | float | Total request time including overhead (ms) |
| `lora_applied` | boolean | Whether the LoRA adapter was applied |

---

### 3. Chat

Simple chat endpoint that extracts the latest user message and generates a response.

**Endpoint:** `POST /chat`

**Request Headers:**
```
Content-Type: application/json
```

**Request Body:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `messages` | array | Yes | `[]` | Array of message objects with `role` and `content` |
| `system_prompt` | string | No | Default Indian AI assistant prompt | Custom system prompt for the model |
| `max_tokens` | integer | No | `256` | Maximum tokens to generate |
| `stream` | boolean | No | `false` | Set to `true` to receive Server-Sent Events (SSE) |

**Message Object:**
| Field | Type | Description |
|-------|------|-------------|
| `role` | string | Either `"user"` or `"assistant"` |
| `content` | string | The message content |

**Example Request:**
```bash
curl -X POST "https://<base-url>/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "Hello, how are you?"}
    ],
    "max_tokens": 256
  }'
```

**Streaming Request:**
```bash
curl -X POST "https://<base-url>/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "Hello, how are you?"}
    ],
    "stream": true
  }'
```

**Response (Non-streaming):**
```json
{
  "response": "Main badhiya hoon! Kaise madad kar sakta hoon?"
}
```

**Response (Streaming):**
```
data: "Main"
data: " badhiya"
...
data: "[DONE]"
```

| Field | Type | Description |
|-------|------|-------------|
| `response` | string | Generated response from the model |

---

## Default System Prompt

When `system_prompt` is not provided, the following default prompt is used:

```
Tu ek Indian AI search assistant hai. User ko search results se answer de - casual Hinglish style mein, jaise koi knowledgeable dost baat kar raha ho.

Rules:
- Hindi-English naturally mix kar
- Concise reh, faltu gyaan mat de  
- Sources mention kar jab relevant ho
- Friendly aur helpful tone rakh
```

---

## Notes

1. **Token Limits:** 
   - `search_results` is automatically truncated to **20,000 tokens** to prevent context overflow
   - Use `max_tokens` to control response length

2. **LoRA Adapter:**
   - The server uses a LoRA fine-tuned adapter for improved Hinglish responses
   - The `lora_applied` field in the response indicates if the adapter was loaded

3. **Performance:**
   - Expected TTFT (Time to First Token): 300-800ms
   - Cold start may take 1-2 minutes for model loading

4. **Rate Limits:**
   - The server supports up to 15 concurrent requests
   - Idle timeout: 5 minutes (server scales down after inactivity)

---

## Error Handling

When an error occurs, the API returns an appropriate HTTP status code:

| Status Code | Description |
|-------------|-------------|
| `200` | Success |
| `500` | Internal server error (model error, timeout, etc.) |
| `503` | Service unavailable (server starting up) |

---

## Deployment

```bash
# Upload LoRA files
modal run server_vllm_simple.py

# Deploy the server
modal deploy server_vllm_simple.py
```
