class_name FilePicker
extends RefCounted
## Lets the player choose an image (profile photo, guild logo, custom flag). In the browser it
## opens the native file chooser through JavaScriptBridge; on desktop a FileDialog. The image is
## downscaled so its longest side is at most `max_size`, ready for upload as base64 JSON:
##
##     FilePicker.pick_image(self, func(image: Image) -> void:
##         if image: ApiManager.request(HTTPClient.METHOD_POST, "/api/...", FilePicker.to_upload(image)))

static var _js_callback: JavaScriptObject  # Kept alive while the browser dialog is open.


## Calls `on_done` with the chosen Image (downscaled), or null if cancelled / unreadable.
static func pick_image(owner: Node, on_done: Callable, max_size := 512) -> void:
	if OS.has_feature("web"):
		_pick_web(on_done, max_size)
	else:
		_pick_desktop(owner, on_done, max_size)


## {image: base64, mime} body for upload endpoints (JPEG for photos, PNG keeps transparency).
static func to_upload(image: Image, keep_alpha := false) -> Dictionary:
	if keep_alpha:
		return {"image": Marshalls.raw_to_base64(image.save_png_to_buffer()), "mime": "image/png"}
	return {"image": Marshalls.raw_to_base64(image.save_jpg_to_buffer(0.86)), "mime": "image/jpeg"}


static func downscale(image: Image, max_size: int) -> Image:
	var longest := maxi(image.get_width(), image.get_height())
	if longest > max_size:
		var factor := float(max_size) / longest
		image.resize(maxi(1, roundi(image.get_width() * factor)), maxi(1, roundi(image.get_height() * factor)), Image.INTERPOLATE_LANCZOS)
	return image


static func _decode(bytes: PackedByteArray, mime: String) -> Image:
	var image := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if mime.contains("png"):
		err = image.load_png_from_buffer(bytes)
	elif mime.contains("webp"):
		err = image.load_webp_from_buffer(bytes)
	else:
		err = image.load_jpg_from_buffer(bytes)
	if err != OK:
		# Browsers sometimes report a generic type; try every decoder.
		for loader: Callable in [image.load_png_from_buffer, image.load_jpg_from_buffer, image.load_webp_from_buffer]:
			if loader.call(bytes) == OK:
				return image
		return null
	return image


static func _pick_web(on_done: Callable, max_size: int) -> void:
	_js_callback = JavaScriptBridge.create_callback(func(args: Array) -> void:
		var image: Image = null
		if args.size() >= 2 and str(args[0]) != "":
			image = _decode(Marshalls.base64_to_raw(str(args[0])), str(args[1]))
		on_done.call(downscale(image, max_size) if image else null))
	var window := JavaScriptBridge.get_interface("window")
	window.__gotgImagePicked = _js_callback
	JavaScriptBridge.eval("""
		(function () {
			var input = document.createElement('input');
			input.type = 'file';
			input.accept = 'image/png,image/jpeg,image/webp';
			input.onchange = function () {
				var file = input.files && input.files[0];
				if (!file) { window.__gotgImagePicked('', ''); return; }
				var reader = new FileReader();
				reader.onload = function () { window.__gotgImagePicked(String(reader.result).split(',')[1] || '', file.type); };
				reader.onerror = function () { window.__gotgImagePicked('', ''); };
				reader.readAsDataURL(file);
			};
			input.click();
		})();
	""", true)


static func _pick_desktop(owner: Node, on_done: Callable, max_size: int) -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
	owner.add_child(dialog)
	dialog.file_selected.connect(func(path: String) -> void:
		var image := Image.load_from_file(path)
		on_done.call(downscale(image, max_size) if image else null)
		dialog.queue_free())
	dialog.canceled.connect(func() -> void:
		on_done.call(null)
		dialog.queue_free())
	dialog.popup_centered_ratio(0.6)
