extends Node
class_name LocalAITalker

signal reply_received(packet)
signal request_failed(packet)
signal status_changed(status_text)

const DEFAULT_CONFIG_PATH := "res://local_ai/local_ai_client_config.json"
const DEFAULT_BASE_URL := "http://127.0.0.1:8765"
const DEFAULT_CHAT_PATH := "/chat"
const DEFAULT_MODEL_ID := "echo"
const BRIDGE_API_MODE := "forever_space_bridge"
const LLAMA_SERVER_OPENAI_API_MODE := "llama_server_openai"
const DEBUG_PREFIX := "[LOCAL_AI_TALKER]"

var enabled := true
var debug_prints := true
var base_url := DEFAULT_BASE_URL
var chat_path := DEFAULT_CHAT_PATH
var model_id := DEFAULT_MODEL_ID
var api_mode := BRIDGE_API_MODE
var max_tokens := 256
var temperature := 0.7
var timeout_seconds := 30.0
var conversation_id := ""
var history: Array = []
var pending := false
var http_request: HTTPRequest = null


func setup(config_path: String = DEFAULT_CONFIG_PATH) -> void:
	load_config(config_path)
	ensure_http_request()
	conversation_id = "orbit_" + str(Time.get_unix_time_from_system()) + "_" + str(Time.get_ticks_msec())
	debug_print("setup complete | enabled=" + str(enabled) + " url=" + get_chat_url() + " model=" + model_id + " timeout=" + str(timeout_seconds))
	status_changed.emit("Local AI ready: " + get_chat_url())


func load_config(config_path: String) -> void:
	var config := read_config_dictionary(config_path)
	if config.is_empty():
		return

	enabled = bool(config.get("enabled", enabled))
	if config.has("client_debug_prints"):
		debug_prints = bool(config.get("client_debug_prints", debug_prints))
	base_url = str(config.get("base_url", base_url)).strip_edges()
	chat_path = str(config.get("chat_path", chat_path)).strip_edges()
	model_id = str(config.get("model_id", model_id)).strip_edges()
	api_mode = str(config.get("api_mode", api_mode)).strip_edges()
	timeout_seconds = float(config.get("timeout_seconds", timeout_seconds))

	var server_config = config.get("server", {})
	if typeof(server_config) == TYPE_DICTIONARY:
		if not config.has("client_debug_prints"):
			debug_prints = bool(server_config.get("debug_prints", debug_prints))
		var backend_options = server_config.get("backend_options", {})
		if typeof(backend_options) == TYPE_DICTIONARY:
			max_tokens = int(float(backend_options.get("max_tokens", max_tokens)))
			temperature = float(backend_options.get("temperature", temperature))

	if base_url == "":
		base_url = DEFAULT_BASE_URL
	if chat_path == "":
		chat_path = DEFAULT_CHAT_PATH
	if not chat_path.begins_with("/"):
		chat_path = "/" + chat_path
	if model_id == "":
		model_id = DEFAULT_MODEL_ID
	if api_mode == "":
		api_mode = BRIDGE_API_MODE
	if chat_path == "/v1/chat/completions" and api_mode == BRIDGE_API_MODE:
		api_mode = LLAMA_SERVER_OPENAI_API_MODE
	timeout_seconds = max(timeout_seconds, 1.0)


func read_config_dictionary(config_path: String) -> Dictionary:
	if not FileAccess.file_exists(config_path):
		return {}

	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		return {}

	var raw_text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(raw_text)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed.duplicate(true)

	return {}


func ensure_http_request() -> void:
	if http_request != null and is_instance_valid(http_request):
		return

	http_request = HTTPRequest.new()
	http_request.name = "LocalAIHttpRequest"
	http_request.timeout = timeout_seconds
	add_child(http_request)

	if not http_request.request_completed.is_connected(_on_request_completed):
		http_request.request_completed.connect(_on_request_completed)


func send_message(message: String, meta: Dictionary = {}) -> bool:
	var clean_message := message.strip_edges()
	if clean_message == "":
		debug_print("send rejected | empty message")
		request_failed.emit({"ok": false, "reason": "Message is empty."})
		return false
	if not enabled:
		debug_print("send rejected | client disabled")
		request_failed.emit({"ok": false, "reason": "Local AI client is disabled."})
		return false
	if pending:
		debug_print("send rejected | request already pending")
		request_failed.emit({"ok": false, "reason": "A local AI request is already pending."})
		return false

	ensure_http_request()
	pending = true
	status_changed.emit("Sending to local AI...")

	var request_id := "orbit_req_" + str(Time.get_ticks_msec())
	var packet := build_bridge_request_packet(request_id, clean_message, meta)
	var body := JSON.stringify(packet)
	if uses_llama_server_openai_api():
		body = JSON.stringify(build_llama_server_request_packet(clean_message, meta))

	history.append({"role": "user", "content": clean_message})

	var headers := [
		"Content-Type: application/json",
		"Accept: application/json"
	]
	var chat_url := get_chat_url()
	debug_print("request dispatch | request_id=" + request_id + " mode=" + api_mode + " url=" + chat_url + " chars=" + str(clean_message.length()) + " body_bytes=" + str(body.to_utf8_buffer().size()))
	var err := http_request.request(chat_url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		pending = false
		var failed := {
			"ok": false,
			"reason": "HTTPRequest.request failed: " + str(err),
			"request_id": request_id,
			"url": chat_url
		}
		debug_print("request dispatch failed | packet=" + str(failed))
		status_changed.emit("Local AI request failed.")
		request_failed.emit(failed)
		return false

	return true


func build_bridge_request_packet(request_id: String, clean_message: String, meta: Dictionary) -> Dictionary:
	return {
		"request_id": request_id,
		"conversation_id": conversation_id,
		"model": model_id,
		"message": clean_message,
		"history": history.duplicate(true),
		"meta": meta.duplicate(true)
	}


func build_llama_server_request_packet(clean_message: String, meta: Dictionary) -> Dictionary:
	return {
		"model": model_id,
		"messages": build_llama_server_messages(clean_message, meta),
		"temperature": temperature,
		"max_tokens": max_tokens,
		"stream": false
	}


func build_llama_server_messages(clean_message: String, meta: Dictionary) -> Array:
	var messages := [
		{
			"role": "system",
			"content": build_system_prompt(meta)
		}
	]

	for item in history.slice(max(0, history.size() - 8), history.size()):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var content := str(item.get("content", "")).strip_edges()
		if content == "":
			continue
		var raw_role := str(item.get("role", "user")).strip_edges().to_lower()
		var role := "assistant" if raw_role in ["assistant", "ai"] else "user"
		messages.append({"role": role, "content": content})

	messages.append({"role": "user", "content": clean_message})
	return messages


func build_system_prompt(meta: Dictionary) -> String:
	var parts := [
		"You are the local AI for Forever Space.",
		"Answer naturally, stay concise, and do not repeat the user's text unless it is useful."
	]

	var snapshot_summary = meta.get("snapshot_summary", {})
	if typeof(snapshot_summary) == TYPE_DICTIONARY and not snapshot_summary.is_empty():
		parts.append("Current game snapshot summary: " + JSON.stringify(snapshot_summary))

	var local_ai_role := str(meta.get("local_ai_role", "")).strip_edges()
	if local_ai_role != "":
		parts.append("Current local AI role: " + local_ai_role + ".")

	var target_body = meta.get("target_body", {})
	if typeof(target_body) == TYPE_DICTIONARY and not target_body.is_empty():
		parts.append("Current orbital body: " + JSON.stringify(target_body))

	var operation = meta.get("operation", {})
	if typeof(operation) == TYPE_DICTIONARY and not operation.is_empty():
		parts.append("Confirmed operation packet: " + JSON.stringify(operation))
		parts.append("Treat the operation packet as truth. Do not invent rewards, item ids, discoveries, or game-state changes.")

	var result := ""
	for part in parts:
		if result != "":
			result += "\n"
		result += str(part)
	return result


func get_chat_url() -> String:
	var clean_base := base_url
	while clean_base.ends_with("/") and clean_base.length() > 0:
		clean_base = clean_base.substr(0, clean_base.length() - 1)
	return clean_base + chat_path


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	pending = false
	var raw_text := body.get_string_from_utf8()
	debug_print("request completed | result=" + str(result) + " response_code=" + str(response_code) + " raw=" + truncate_text(raw_text, 600))

	if result != HTTPRequest.RESULT_SUCCESS:
		status_changed.emit("Local AI connection failed.")
		request_failed.emit({
			"ok": false,
			"reason": "HTTPRequest result: " + str(result),
			"response_code": response_code
		})
		return

	var parsed = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		status_changed.emit("Local AI returned invalid JSON.")
		request_failed.emit({
			"ok": false,
			"reason": "Response was not a JSON object.",
			"response_code": response_code,
			"raw": raw_text
		})
		return

	if uses_llama_server_openai_api():
		handle_llama_server_response(response_code, parsed)
		return

	var packet: Dictionary = parsed
	if response_code < 200 or response_code >= 300 or not bool(packet.get("ok", false)):
		status_changed.emit("Local AI returned an error.")
		packet["response_code"] = response_code
		request_failed.emit(packet)
		return

	var reply := str(packet.get("reply", ""))
	history.append({"role": "assistant", "content": reply})
	debug_print("reply accepted | chars=" + str(reply.length()))
	if str(packet.get("backend", "")) == "echo":
		status_changed.emit("Echo wire-test reply received. Local model inference is not active.")
	else:
		status_changed.emit("Local AI reply received.")
	reply_received.emit(packet)


func handle_llama_server_response(response_code: int, parsed: Dictionary) -> void:
	if response_code < 200 or response_code >= 300:
		status_changed.emit("Local AI returned an error.")
		var error_message := extract_llama_server_error(parsed)
		request_failed.emit({
			"ok": false,
			"reason": error_message,
			"response_code": response_code,
			"backend": "llama_server_direct",
			"model": model_id
		})
		return

	var reply := extract_llama_server_reply(parsed)
	var packet := {
		"ok": true,
		"request_id": "llama_server_" + str(Time.get_ticks_msec()),
		"conversation_id": conversation_id,
		"reply": reply,
		"backend": "llama_server_direct",
		"model": model_id,
		"mode": "llama_server_direct",
		"inference_ready": true,
		"created_at_unix": Time.get_unix_time_from_system()
	}

	history.append({"role": "assistant", "content": reply})
	debug_print("direct llama reply accepted | chars=" + str(reply.length()))
	status_changed.emit("Local AI reply received.")
	reply_received.emit(packet)


func extract_llama_server_reply(packet: Dictionary) -> String:
	var choices = packet.get("choices", [])
	if typeof(choices) != TYPE_ARRAY or choices.is_empty():
		return ""

	var first = choices[0]
	if typeof(first) != TYPE_DICTIONARY:
		return ""

	var message = first.get("message", {})
	if typeof(message) == TYPE_DICTIONARY:
		return str(message.get("content", "")).strip_edges()

	return str(first.get("text", "")).strip_edges()


func extract_llama_server_error(packet: Dictionary) -> String:
	var error = packet.get("error", "")
	if typeof(error) == TYPE_DICTIONARY:
		return str(error.get("message", error)).strip_edges()
	var text := str(error).strip_edges()
	return text if text != "" else "llama-server returned an error."


func uses_llama_server_openai_api() -> bool:
	return api_mode == LLAMA_SERVER_OPENAI_API_MODE


func truncate_text(text: String, max_chars: int) -> String:
	if text.length() <= max_chars:
		return text
	return text.substr(0, max_chars) + "...[truncated]"


func debug_print(message: String) -> void:
	if debug_prints:
		print(DEBUG_PREFIX + " " + message)
