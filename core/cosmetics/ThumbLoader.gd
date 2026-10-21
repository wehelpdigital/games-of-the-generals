class_name ThumbLoader
extends Node
## Downloads shop pictures from the website for ShopThumbs, a few at a time, newest requests first
## (the cards on screen now). Lives under the scene root; ShopThumbs creates it on first use.

signal loaded(key: String, image: Image)

const PARALLEL := 6

var _queue: Array[Array] = []  # [key, url], most recent last
var _busy := 0


## Queues a picture ("category/slug") for download from `url`.
func fetch(key: String, url: String) -> void:
	_queue.append([key, url])
	if is_inside_tree():
		_pump()


func _ready() -> void:
	_pump()  # Requests made before the loader joined the tree.


func _pump() -> void:
	while _busy < PARALLEL and not _queue.is_empty():
		var job: Array = _queue.pop_back()
		_busy += 1
		var http := HTTPRequest.new()
		http.timeout = 20.0
		add_child(http)
		http.request_completed.connect(_on_done.bind(http, str(job[0])))
		if http.request(str(job[1])) != OK:
			_finish(http, str(job[0]), null)


func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, key: String) -> void:
	var image: Image = null
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		image = Image.new()
		if image.load_webp_from_buffer(body) != OK:
			image = null
	_finish(http, key, image)


func _finish(http: HTTPRequest, key: String, image: Image) -> void:
	http.queue_free()
	_busy -= 1
	loaded.emit(key, image)
	_pump()
