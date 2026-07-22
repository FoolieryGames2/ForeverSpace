extends Node
class_name LocalAIServerManager

signal status_changed(packet)

const DEFAULT_CONFIG_PATH := "res://local_ai/local_ai_client_config.json"
const DEFAULT_HOST := "127.0.0.1"
const DEFAULT_PORT := 8765
const DEFAULT_HEALTH_PATH := "/health"
const DEFAULT_SERVER_COMMAND := "python"
const DEFAULT_SERVER_SCRIPT_PATH := "res://local_ai/local_ai_server.py"
const DEFAULT_BACKEND := "echo"
const DEFAULT_MODEL := "echo"
const DEFAULT_RUNTIME_MODE := "llama_server_direct"
const PYTHON_BRIDGE_RUNTIME_MODE := "python_bridge"
const DIRECT_LLAMA_RUNTIME_MODE := "llama_server_direct"
const DIRECT_LLAMA_BACKEND_ID := "llama_server_direct"
const DIRECT_LLAMA_MODEL_ALIAS := "forever-space-local"
const USER_RUNTIME_CONFIG_PATH := "user://local_ai/local_ai_client_config.runtime.json"
const USER_SERVER_SCRIPT_PATH := "user://local_ai/local_ai_server.py"
const USER_MODEL_PATH := "user://local_ai/smoll.gguf"
const USER_LLAMA_SERVER_PATH := "user://local_ai/runtime/llama-server.exe"
const USER_LLAMA_LOG_PATH := "user://local_ai/llama_server.log"
const COPY_CHUNK_BYTES := 8388608
const RUNTIME_PAYLOAD_FILES := [
	{"source": "res://local_ai/local_ai_server.py", "target": "user://local_ai/local_ai_server.py", "required": false},
	{"source": "res://local_ai/smoll.gguf", "target": "user://local_ai/smoll.gguf", "required": true},
	{"source": "res://local_ai/runtime/ggml-base.dll", "target": "user://local_ai/runtime/ggml-base.dll", "required": true},
	{"source": "res://local_ai/runtime/ggml-cpu.dll", "target": "user://local_ai/runtime/ggml-cpu.dll", "required": true},
	{"source": "res://local_ai/runtime/ggml.dll", "target": "user://local_ai/runtime/ggml.dll", "required": true},
	{"source": "res://local_ai/runtime/llama-common.dll", "target": "user://local_ai/runtime/llama-common.dll", "required": true},
	{"source": "res://local_ai/runtime/llama-server.exe", "target": "user://local_ai/runtime/llama-server.exe", "required": true},
	{"source": "res://local_ai/runtime/llama.dll", "target": "user://local_ai/runtime/llama.dll", "required": true},
	{"source": "res://local_ai/runtime/mtmd.dll", "target": "user://local_ai/runtime/mtmd.dll", "required": true}
]

var enabled := true
var autostart := true
var debug_prints := true
var host := DEFAULT_HOST
var port := DEFAULT_PORT
var health_path := DEFAULT_HEALTH_PATH
var server_command := DEFAULT_SERVER_COMMAND
var server_script_path := DEFAULT_SERVER_SCRIPT_PATH
var server_backend := DEFAULT_BACKEND
var server_model := DEFAULT_MODEL
var server_runtime_mode := DEFAULT_RUNTIME_MODE
var install_runtime_to_user := true
var allow_lan := false
var restart_on_config_mismatch := true
var extra_args: Array = []
var backend_options: Dictionary = {}
var health_interval_seconds := 0.5
var health_timeout_seconds := 1.0
var max_health_attempts := 20
var process_bind_timeout_seconds := 45.0
var active_config_path := DEFAULT_CONFIG_PATH

var process_id := -1
var start_requested := false
var started_process := false
var server_ready := false
var last_status_packet: Dictionary = {}
var health_pending := false
var health_attempt := 0
var last_start_reason := ""
var process_started_at_msec := 0

var health_request: HTTPRequest = null
var health_timer: Timer = null


func setup(config_path: String = DEFAULT_CONFIG_PATH) -> void:
	active_config_path = config_path
	load_config(config_path)
	ensure_nodes()
	debug_print("setup complete | enabled=" + str(enabled) + " autostart=" + str(autostart) + " url=" + get_health_url())


func begin_startup(reason: String = "main_mode_boot") -> void:
	last_start_reason = reason
	setup(DEFAULT_CONFIG_PATH)
	debug_print("begin_startup | reason=" + reason)

	if not enabled:
		emit_status("disabled", "Local AI server autostart disabled by config.")
		return

	if not autostart:
		emit_status("autostart_off", "Local AI server autostart is off.")
		return

	if not prepare_runtime_for_startup():
		return

	start_requested = true
	server_ready = false
	health_attempt = 0
	check_existing_server()


func load_config(config_path: String) -> void:
	var config := read_config_dictionary(config_path)
	if config.is_empty():
		debug_print("config missing or empty, using defaults: " + config_path)
		return

	enabled = bool(config.get("enabled", enabled))
	host = str(config.get("server_host", host)).strip_edges()
	port = int(config.get("server_port", port))
	health_path = str(config.get("health_path", health_path)).strip_edges()

	var server_config = config.get("server", {})
	if typeof(server_config) == TYPE_DICTIONARY:
		autostart = bool(server_config.get("autostart", autostart))
		debug_prints = bool(server_config.get("debug_prints", debug_prints))
		server_command = str(server_config.get("command", server_command)).strip_edges()
		server_script_path = str(server_config.get("script_path", server_script_path)).strip_edges()
		server_runtime_mode = str(server_config.get("runtime_mode", server_runtime_mode)).strip_edges()
		install_runtime_to_user = bool(server_config.get("install_runtime_to_user", install_runtime_to_user))
		host = str(server_config.get("host", host)).strip_edges()
		port = int(server_config.get("port", port))
		server_backend = str(server_config.get("backend", server_backend)).strip_edges()
		server_model = str(server_config.get("model", server_model)).strip_edges()
		allow_lan = bool(server_config.get("allow_lan", allow_lan))
		restart_on_config_mismatch = bool(server_config.get("restart_on_config_mismatch", restart_on_config_mismatch))
		var raw_backend_options = server_config.get("backend_options", {})
		if typeof(raw_backend_options) == TYPE_DICTIONARY:
			backend_options = raw_backend_options.duplicate(true)
		health_interval_seconds = float(server_config.get("health_interval_seconds", health_interval_seconds))
		health_timeout_seconds = float(server_config.get("health_timeout_seconds", health_timeout_seconds))
		max_health_attempts = int(server_config.get("max_health_attempts", max_health_attempts))
		process_bind_timeout_seconds = float(server_config.get("process_bind_timeout_seconds", process_bind_timeout_seconds))

		var raw_extra_args = server_config.get("extra_args", [])
		if typeof(raw_extra_args) == TYPE_ARRAY:
			extra_args = raw_extra_args.duplicate(true)

	if host == "":
		host = DEFAULT_HOST
	if port <= 0:
		port = DEFAULT_PORT
	if health_path == "":
		health_path = DEFAULT_HEALTH_PATH
	if not health_path.begins_with("/"):
		health_path = "/" + health_path
	if server_command == "":
		server_command = DEFAULT_SERVER_COMMAND
	if server_script_path == "":
		server_script_path = DEFAULT_SERVER_SCRIPT_PATH
	if server_runtime_mode == "":
		server_runtime_mode = DEFAULT_RUNTIME_MODE
	if server_backend == "":
		server_backend = DEFAULT_BACKEND
	if server_model == "":
		server_model = DEFAULT_MODEL

	health_interval_seconds = max(health_interval_seconds, 0.1)
	health_timeout_seconds = max(health_timeout_seconds, 0.2)
	max_health_attempts = max(max_health_attempts, 1)
	process_bind_timeout_seconds = max(process_bind_timeout_seconds, 5.0)


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


func prepare_runtime_for_startup() -> bool:
	if not should_install_runtime_to_user():
		return true

	emit_status("installing_runtime", "Preparing local AI runtime files in user data.")
	var install_result := install_runtime_bundle_to_user()
	if not bool(install_result.get("ok", false)):
		emit_status("failed", str(install_result.get("message", "Could not prepare local AI runtime files.")), install_result)
		return false

	active_config_path = USER_RUNTIME_CONFIG_PATH
	load_config(active_config_path)
	ensure_nodes()
	debug_print("runtime prepared | config=" + active_config_path + " user_dir=" + ProjectSettings.globalize_path("user://local_ai"))
	return true


func should_install_runtime_to_user() -> bool:
	return install_runtime_to_user and not OS.has_feature("editor")


func install_runtime_bundle_to_user() -> Dictionary:
	var dirs_ok := ensure_user_runtime_directories()
	if not bool(dirs_ok.get("ok", false)):
		return dirs_ok

	for item in RUNTIME_PAYLOAD_FILES:
		var copy_result := copy_payload_file_to_user(item)
		if not bool(copy_result.get("ok", false)):
			return copy_result

	var config_result := write_user_runtime_config()
	if not bool(config_result.get("ok", false)):
		return config_result

	return {
		"ok": true,
		"message": "Local AI runtime files are ready.",
		"config_path": ProjectSettings.globalize_path(USER_RUNTIME_CONFIG_PATH),
		"runtime_dir": ProjectSettings.globalize_path("user://local_ai")
	}


func ensure_user_runtime_directories() -> Dictionary:
	var runtime_root := ProjectSettings.globalize_path("user://local_ai")
	var runtime_bin := ProjectSettings.globalize_path("user://local_ai/runtime")
	var root_err := DirAccess.make_dir_recursive_absolute(runtime_root)
	if root_err != OK:
		return {"ok": false, "message": "Could not create local AI user directory: " + runtime_root + " err=" + str(root_err)}
	var bin_err := DirAccess.make_dir_recursive_absolute(runtime_bin)
	if bin_err != OK:
		return {"ok": false, "message": "Could not create local AI runtime directory: " + runtime_bin + " err=" + str(bin_err)}
	return {"ok": true}


func copy_payload_file_to_user(item: Dictionary) -> Dictionary:
	var source_path := str(item.get("source", "")).strip_edges()
	var target_path := str(item.get("target", "")).strip_edges()
	var required := bool(item.get("required", true))
	if source_path == "" or target_path == "":
		return {"ok": false, "message": "Local AI payload entry is missing a source or target path."}

	if not FileAccess.file_exists(source_path):
		if required:
			return {"ok": false, "message": "Required local AI payload is missing from export: " + source_path}
		debug_print("optional local AI payload missing, skipped | " + source_path)
		return {"ok": true, "skipped": true}

	var source_size := get_file_size(source_path)
	var target_size := get_file_size(target_path)
	if source_size >= 0 and target_size == source_size:
		debug_print("payload already installed | " + target_path + " bytes=" + str(target_size))
		return {"ok": true, "skipped": true, "target": ProjectSettings.globalize_path(target_path)}

	var target_dir := target_path.get_base_dir()
	var dir_err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_dir))
	if dir_err != OK:
		return {"ok": false, "message": "Could not create local AI payload directory: " + target_dir + " err=" + str(dir_err)}

	debug_print("installing payload | " + source_path + " -> " + target_path + " bytes=" + str(source_size))
	var source_file := FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		return {"ok": false, "message": "Could not open local AI payload for reading: " + source_path}

	var target_file := FileAccess.open(target_path, FileAccess.WRITE)
	if target_file == null:
		source_file.close()
		return {"ok": false, "message": "Could not open local AI payload for writing: " + target_path}

	while source_file.get_position() < source_file.get_length():
		var remaining := int(source_file.get_length() - source_file.get_position())
		var chunk_size = min(COPY_CHUNK_BYTES, remaining)
		var chunk := source_file.get_buffer(chunk_size)
		if chunk.is_empty() and remaining > 0:
			source_file.close()
			target_file.close()
			return {"ok": false, "message": "Local AI payload copy stalled: " + source_path}
		target_file.store_buffer(chunk)

	source_file.close()
	target_file.close()

	var final_size := get_file_size(target_path)
	if final_size != source_size:
		return {"ok": false, "message": "Local AI payload copy size mismatch: " + target_path + " expected=" + str(source_size) + " actual=" + str(final_size)}

	return {"ok": true, "target": ProjectSettings.globalize_path(target_path), "bytes": final_size}


func write_user_runtime_config() -> Dictionary:
	var runtime_config := read_config_dictionary(DEFAULT_CONFIG_PATH)
	if runtime_config.is_empty():
		runtime_config = {}

	runtime_config["base_url"] = get_base_url()
	runtime_config["chat_path"] = "/v1/chat/completions" if is_direct_llama_runtime() else "/chat"
	runtime_config["api_mode"] = "llama_server_openai" if is_direct_llama_runtime() else "forever_space_bridge"
	runtime_config["model_id"] = DIRECT_LLAMA_MODEL_ALIAS if is_direct_llama_runtime() else server_model

	var runtime_server_config = runtime_config.get("server", {})
	if typeof(runtime_server_config) != TYPE_DICTIONARY:
		runtime_server_config = {}

	runtime_server_config["runtime_mode"] = server_runtime_mode
	runtime_server_config["install_runtime_to_user"] = install_runtime_to_user
	runtime_server_config["script_path"] = USER_SERVER_SCRIPT_PATH
	runtime_server_config["host"] = host
	runtime_server_config["port"] = port
	runtime_server_config["backend"] = server_backend
	runtime_server_config["model"] = ProjectSettings.globalize_path(USER_MODEL_PATH)

	var runtime_backend_options = runtime_server_config.get("backend_options", {})
	if typeof(runtime_backend_options) != TYPE_DICTIONARY:
		runtime_backend_options = {}
	runtime_backend_options = runtime_backend_options.duplicate(true)
	runtime_backend_options["llama_server_path"] = ProjectSettings.globalize_path(USER_LLAMA_SERVER_PATH)
	runtime_backend_options["llama_server_log_path"] = ProjectSettings.globalize_path(USER_LLAMA_LOG_PATH)
	runtime_server_config["backend_options"] = runtime_backend_options
	runtime_config["server"] = runtime_server_config

	var file := FileAccess.open(USER_RUNTIME_CONFIG_PATH, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Could not write local AI runtime config: " + USER_RUNTIME_CONFIG_PATH}
	file.store_string(JSON.stringify(runtime_config, "\t"))
	file.close()
	return {"ok": true, "config_path": ProjectSettings.globalize_path(USER_RUNTIME_CONFIG_PATH)}


func get_file_size(path: String) -> int:
	if path == "" or not FileAccess.file_exists(path):
		return -1
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var size := int(file.get_length())
	file.close()
	return size


func ensure_nodes() -> void:
	if health_request == null or not is_instance_valid(health_request):
		health_request = HTTPRequest.new()
		health_request.name = "LocalAIServerHealthRequest"
		add_child(health_request)

	if health_request.request_completed.is_connected(_on_health_request_completed):
		health_request.request_completed.disconnect(_on_health_request_completed)
	health_request.request_completed.connect(_on_health_request_completed)
	health_request.timeout = health_timeout_seconds

	if health_timer == null or not is_instance_valid(health_timer):
		health_timer = Timer.new()
		health_timer.name = "LocalAIServerHealthTimer"
		health_timer.one_shot = true
		add_child(health_timer)

	if health_timer.timeout.is_connected(_on_health_timer_timeout):
		health_timer.timeout.disconnect(_on_health_timer_timeout)
	health_timer.timeout.connect(_on_health_timer_timeout)


func check_existing_server() -> void:
	debug_print("checking existing server | " + get_health_url())
	emit_status("checking", "Checking local AI server health.")
	request_health("pre_start")


func request_health(reason: String) -> bool:
	if health_pending:
		debug_print("health request skipped, already pending | reason=" + reason)
		return false

	ensure_nodes()
	health_pending = true
	health_attempt += 1
	debug_print("health request " + str(health_attempt) + "/" + str(max_health_attempts) + " | reason=" + reason + " | url=" + get_health_url())

	var err := health_request.request(get_health_url())
	if err != OK:
		health_pending = false
		debug_print("health request failed to dispatch | err=" + str(err))
		handle_health_failed("dispatch_error_" + str(err))
		return false

	return true


func _on_health_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	health_pending = false
	debug_print("health completed | result=" + str(result) + " response_code=" + str(response_code))
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		parsed = {}

	if is_direct_llama_runtime():
		handle_direct_llama_health_response(result, response_code, parsed)
		return

	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		if typeof(parsed) == TYPE_DICTIONARY and bool(parsed.get("ok", false)):
			if should_keep_polling_for_inference(parsed):
				emit_status("warming_up", "Local AI model is loading at " + get_base_url(), parsed)
				schedule_health_poll()
				return

			server_ready = true
			if parsed.has("pid") and process_id <= 0:
				process_id = int(parsed.get("pid", process_id))

			var state := "ready"
			var message := "Local AI server ready at " + get_base_url()
			var mismatch_message := get_health_mismatch_message(parsed)
			if mismatch_message != "":
				if restart_existing_server_for_mismatch(parsed, mismatch_message):
					return
				state = "ready_config_mismatch"
				message += " | Config mismatch: " + mismatch_message
				debug_print("server ready with config mismatch | " + mismatch_message + " | packet=" + str(parsed))
			else:
				debug_print("server ready | packet=" + str(parsed))

			emit_status(state, message, parsed)
			return

	handle_health_failed("bad_health_response")


func handle_direct_llama_health_response(result: int, response_code: int, parsed: Dictionary) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		server_ready = true
		var packet := build_direct_llama_health_packet(parsed, true)
		debug_print("direct llama server ready | packet=" + str(packet))
		emit_status("ready", "Local AI server ready at " + get_base_url(), packet)
		return

	if result == HTTPRequest.RESULT_SUCCESS and response_code == 503:
		if health_attempt >= max_health_attempts:
			emit_status("failed", "Local AI model did not finish loading before the health retry limit.", build_direct_llama_health_packet(parsed, false))
			return
		emit_status("warming_up", "Local AI model is loading at " + get_base_url(), build_direct_llama_health_packet(parsed, false))
		schedule_health_poll()
		return

	handle_health_failed("bad_direct_llama_health_response_" + str(response_code))


func build_direct_llama_health_packet(raw_health: Dictionary, inference_ready: bool) -> Dictionary:
	return {
		"ok": true,
		"service": "forever_space_local_ai",
		"backend": DIRECT_LLAMA_BACKEND_ID,
		"model": server_model,
		"pid": process_id,
		"mode": DIRECT_LLAMA_RUNTIME_MODE,
		"inference_ready": inference_ready,
		"runtime_mode": server_runtime_mode,
		"raw_health": raw_health.duplicate(true)
	}


func should_keep_polling_for_inference(packet: Dictionary) -> bool:
	if not packet.has("inference_ready"):
		return false
	if bool(packet.get("inference_ready", false)):
		return false

	var mode := str(packet.get("mode", ""))
	return mode != "echo_wire_test"


func get_health_mismatch_message(packet: Dictionary) -> String:
	var issues := []
	var active_backend := str(packet.get("backend", ""))
	var active_model := str(packet.get("model", ""))
	var expected_backend := get_expected_health_backend()

	if active_backend != "" and active_backend != expected_backend:
		issues.append("backend " + active_backend + " != config " + expected_backend)
	if active_model != "" and active_model != server_model:
		issues.append("model " + active_model + " != config " + server_model)

	var message := ""
	for issue in issues:
		if message != "":
			message += "; "
		message += str(issue)
	return message


func restart_existing_server_for_mismatch(packet: Dictionary, mismatch_message: String) -> bool:
	if not restart_on_config_mismatch:
		return false
	if started_process:
		return false
	if str(packet.get("service", "")) != "forever_space_local_ai":
		return false

	var existing_pid := int(packet.get("pid", -1))
	if existing_pid <= 0:
		return false

	debug_print("restarting existing server for config mismatch | pid=" + str(existing_pid) + " mismatch=" + mismatch_message)
	emit_status("restarting_config_mismatch", "Restarting local AI server for config mismatch: " + mismatch_message, packet)
	var kill_result := OS.kill(existing_pid)
	debug_print("existing server kill result | pid=" + str(existing_pid) + " result=" + str(kill_result))
	if kill_result != OK:
		return false

	process_id = -1
	started_process = false
	server_ready = false
	health_pending = false
	start_server_process()
	schedule_health_poll()
	return true


func handle_health_failed(reason: String) -> void:
	debug_print("health failed | reason=" + reason + " | started_process=" + str(started_process))

	if not started_process:
		start_server_process()
		schedule_health_poll()
		return

	if process_id > 0 and not OS.is_process_running(process_id):
		started_process = false
		server_ready = false
		emit_status("failed", "Local AI server process exited before it became ready: " + reason)
		debug_print("process exited before ready | pid=" + str(process_id) + " reason=" + reason)
		process_id = -1
		return

	if process_id > 0 and process_started_at_msec > 0:
		var elapsed_seconds := float(Time.get_ticks_msec() - process_started_at_msec) / 1000.0
		if elapsed_seconds >= process_bind_timeout_seconds:
			debug_print("process bind timeout | pid=" + str(process_id) + " elapsed=" + str(elapsed_seconds) + " limit=" + str(process_bind_timeout_seconds))
			OS.kill(process_id)
			emit_status("failed", "Local AI server process did not open /health after " + str(process_bind_timeout_seconds) + " seconds.")
			process_id = -1
			process_started_at_msec = 0
			started_process = false
			server_ready = false
			return

	if health_attempt >= max_health_attempts:
		emit_status("failed", "Local AI server did not become ready: " + reason)
		debug_print("giving up after " + str(health_attempt) + " health attempts")
		return

	schedule_health_poll()


func start_server_process() -> void:
	started_process = true
	process_started_at_msec = Time.get_ticks_msec()
	if is_direct_llama_runtime():
		start_direct_llama_server_process()
	else:
		start_python_bridge_process()


func start_python_bridge_process() -> void:
	var script_path := resolve_server_script_path()
	var args := PackedStringArray()
	args.append(script_path)
	args.append("--config")
	args.append(resolve_config_path(active_config_path))
	args.append("--host")
	args.append(host)
	args.append("--port")
	args.append(str(port))
	args.append("--backend")
	args.append(server_backend)
	args.append("--model")
	args.append(server_model)
	if allow_lan:
		args.append("--allow-lan")

	append_int_backend_option_arg(args, "n_ctx", "--n-ctx")
	append_int_backend_option_arg(args, "n_threads", "--n-threads")
	append_int_backend_option_arg(args, "n_gpu_layers", "--n-gpu-layers")
	append_int_backend_option_arg(args, "max_tokens", "--max-tokens")
	append_backend_option_arg(args, "temperature", "--temperature")
	append_backend_option_arg(args, "llama_server_path", "--llama-server-path")
	append_backend_option_arg(args, "llama_server_host", "--llama-server-host")
	append_int_backend_option_arg(args, "llama_server_port", "--llama-server-port")
	append_backend_option_arg(args, "startup_timeout_seconds", "--startup-timeout-seconds")
	append_backend_option_arg(args, "request_timeout_seconds", "--request-timeout-seconds")
	append_backend_option_arg(args, "llama_server_log_path", "--llama-server-log-path")

	for raw_arg in extra_args:
		var arg := str(raw_arg).strip_edges()
		if arg != "":
			args.append(arg)

	debug_print("starting process | command=" + server_command + " args=" + str(Array(args)))
	process_id = OS.create_process(server_command, args, false)
	debug_print("process start result | pid=" + str(process_id))

	if process_id <= 0 and server_command == "python":
		var py_args := PackedStringArray()
		py_args.append("-3")
		for arg in args:
			py_args.append(arg)
		debug_print("python command failed, trying py launcher | args=" + str(Array(py_args)))
		process_id = OS.create_process("py", py_args, false)
		debug_print("py launcher result | pid=" + str(process_id))

	if process_id > 0:
		emit_status("starting", "Local AI server process started. PID: " + str(process_id))
	else:
		process_started_at_msec = 0
		emit_status("failed", "Could not start local AI server process.")


func start_direct_llama_server_process() -> void:
	var executable_path := resolve_llama_server_executable_path()
	var model_path := resolve_runtime_file_path(server_model)
	if executable_path == "" or not FileAccess.file_exists(executable_path):
		process_started_at_msec = 0
		started_process = false
		emit_status("failed", "Could not find bundled llama-server executable: " + executable_path)
		return

	if model_path == "" or not FileAccess.file_exists(model_path):
		process_started_at_msec = 0
		started_process = false
		emit_status("failed", "Could not find bundled local AI model: " + model_path)
		return

	var args := PackedStringArray()
	args.append("--model")
	args.append(model_path)
	args.append("--host")
	args.append(host)
	args.append("--port")
	args.append(str(port))
	args.append("--ctx-size")
	args.append(str(get_backend_option_int("n_ctx", 2048)))
	args.append("--n-gpu-layers")
	args.append(str(get_backend_option_int("n_gpu_layers", 0)))
	args.append("--alias")
	args.append(DIRECT_LLAMA_MODEL_ALIAS)

	var n_threads := get_backend_option_int("n_threads", 0)
	if n_threads > 0:
		args.append("--threads")
		args.append(str(n_threads))

	for raw_arg in extra_args:
		var arg := str(raw_arg).strip_edges()
		if arg != "":
			args.append(arg)

	debug_print("starting direct llama-server | command=" + executable_path + " args=" + str(Array(args)))
	process_id = OS.create_process(executable_path, args, false)
	debug_print("direct llama-server start result | pid=" + str(process_id))

	if process_id > 0:
		emit_status("starting", "Local AI server process started. PID: " + str(process_id))
	else:
		process_started_at_msec = 0
		started_process = false
		emit_status("failed", "Could not start bundled llama-server process.")


func resolve_llama_server_executable_path() -> String:
	var configured := str(backend_options.get("llama_server_path", "")).strip_edges()
	if configured == "":
		configured = server_command
	return resolve_runtime_file_path(configured)


func get_backend_option_int(option_key: String, fallback: int) -> int:
	if not backend_options.has(option_key):
		return fallback
	return int(float(backend_options.get(option_key, fallback)))


func append_backend_option_arg(args: PackedStringArray, option_key: String, cli_name: String) -> void:
	if not backend_options.has(option_key):
		return

	var value := str(backend_options.get(option_key, "")).strip_edges()
	if value == "":
		return

	args.append(cli_name)
	args.append(value)


func append_int_backend_option_arg(args: PackedStringArray, option_key: String, cli_name: String) -> void:
	if not backend_options.has(option_key):
		return

	var raw_value = backend_options.get(option_key, "")
	var value := str(int(float(raw_value))).strip_edges()
	if value == "":
		return

	args.append(cli_name)
	args.append(value)


func schedule_health_poll() -> void:
	if server_ready:
		return
	if health_timer == null:
		return

	debug_print("scheduling health poll in " + str(health_interval_seconds) + " seconds")
	health_timer.start(health_interval_seconds)


func _on_health_timer_timeout() -> void:
	if server_ready:
		return
	request_health("post_start_poll")


func stop_started_process() -> void:
	if process_id <= 0:
		return
	debug_print("stopping process | pid=" + str(process_id))
	OS.kill(process_id)
	process_id = -1
	process_started_at_msec = 0
	started_process = false
	server_ready = false


func resolve_server_script_path() -> String:
	if server_script_path.begins_with("res://") or server_script_path.begins_with("user://"):
		return ProjectSettings.globalize_path(server_script_path)
	return resolve_runtime_file_path(server_script_path)


func resolve_config_path(config_path: String) -> String:
	if config_path.begins_with("res://") or config_path.begins_with("user://"):
		return ProjectSettings.globalize_path(config_path)
	return config_path


func resolve_runtime_file_path(path_text: String) -> String:
	var clean_path := str(path_text).strip_edges()
	if clean_path == "":
		return ""
	if clean_path.begins_with("res://") or clean_path.begins_with("user://"):
		return ProjectSettings.globalize_path(clean_path)
	if is_absolute_filesystem_path(clean_path):
		return clean_path

	var res_path := "res://" + clean_path
	var user_path := "user://" + clean_path
	if OS.has_feature("editor") and FileAccess.file_exists(res_path):
		return ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(user_path):
		return ProjectSettings.globalize_path(user_path)
	if FileAccess.file_exists(res_path):
		return ProjectSettings.globalize_path(res_path)

	return clean_path


func is_absolute_filesystem_path(path_text: String) -> bool:
	var clean_path := path_text.replace("\\", "/")
	if clean_path.begins_with("/") or clean_path.begins_with("//"):
		return true
	return clean_path.length() >= 3 and clean_path.substr(1, 2) == ":/"


func is_direct_llama_runtime() -> bool:
	return server_runtime_mode == DIRECT_LLAMA_RUNTIME_MODE


func get_expected_health_backend() -> String:
	return DIRECT_LLAMA_BACKEND_ID if is_direct_llama_runtime() else server_backend


func get_base_url() -> String:
	return "http://" + host + ":" + str(port)


func get_health_url() -> String:
	return get_base_url() + health_path


func emit_status(state: String, message: String, data: Dictionary = {}) -> void:
	var packet := {
		"state": state,
		"message": message,
		"host": host,
		"port": port,
		"pid": process_id,
		"started_process": started_process,
		"ready": server_ready,
		"attempt": health_attempt,
		"data": data.duplicate(true)
	}
	last_status_packet = packet.duplicate(true)
	debug_print("status | " + str(packet))
	status_changed.emit(packet)


func get_last_status_packet() -> Dictionary:
	return last_status_packet.duplicate(true)


func debug_print(message: String) -> void:
	if debug_prints:
		print("[LOCAL_AI_SERVER_MANAGER] " + message)
