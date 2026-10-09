extends Control

const CONFIG_PATH := "user://settings.cfg"
const CONFIG_SECTION := "localization"
const CONFIG_KEY := "locale"

const LANGUAGES := {
	"en": "res://ui/flags/en.png",
	"ru": "res://ui/flags/ru.png",
}

@export var flag_size := 128
const DEFAULT_LOCALE := "en"

@onready var flag_button: Button = $FlagButton
@onready var popup: Panel = $LanguagePopup
@onready var list: VBoxContainer = $LanguagePopup/List

func _ready() -> void:
	flag_button.pressed.connect(_on_flag_button_pressed)
	_load_saved_locale()
	_build_list()
	_update_current_flag()
	popup.visible = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_build_list()
		_update_current_flag()

# ---------- Построение списка флагов (без текущего) ----------
func _build_list() -> void:
	for child in list.get_children():
		child.queue_free()

	var current := _current_locale()
	for code in LANGUAGES.keys():
		if code == current:
			continue

		var btn := Button.new()
		btn.custom_minimum_size = flag_button.size
		btn.focus_mode = Control.FOCUS_NONE
		btn.flat = true
		btn.icon = load(LANGUAGES[code])
		btn.expand_icon = true
		btn.add_theme_constant_override("icon_max_width", flag_size)
		btn.pressed.connect(_on_flag_selected.bind(code))
		list.add_child(btn)

	# Подогнать Panel под содержимое
	popup.size = Vector2(flag_button.size.x, (flag_button.size.y)* LANGUAGES.keys().size())

# ---------- Текущий флаг ----------
func _current_locale() -> String:
	return TranslationServer.get_locale().split("_")[0]

func _update_current_flag() -> void:
	var code := _current_locale()
	if not LANGUAGES.has(code):
		code = DEFAULT_LOCALE
	flag_button.icon = load(LANGUAGES[code])
	flag_button.expand_icon = true
	flag_button.add_theme_constant_override("icon_max_width", flag_size)

# ---------- Показ/скрытие попапа над кнопкой ----------
func _on_flag_button_pressed() -> void:
	if popup.visible:
		popup.visible = false
		return

	_build_list()

	# Позиционируем в локальных координатах LanguageSelector:
	# правый край попапа = правый край кнопки,
	# нижний край попапа = верхний край кнопки.
	var b_pos := flag_button.position
	var b_size := flag_button.size
	var p_size := popup.size

	popup.position = Vector2(
		b_pos.x + b_size.x - p_size.x,
		b_pos.y - p_size.y + b_size.y
	)
	popup.visible = true

func _input(event: InputEvent) -> void:
	if not popup.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		var local := get_local_mouse_position()
		var in_button := Rect2(flag_button.position, flag_button.size).has_point(local)
		var in_popup := Rect2(popup.position, popup.size).has_point(local)
		if not in_button and not in_popup:
			popup.visible = false

# ---------- Выбор языка ----------
func _on_flag_selected(code: String) -> void:
	TranslationServer.set_locale(code)
	_save_locale(code)
	popup.visible = false

# ---------- Сохранение/загрузка ----------
func _save_locale(code: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value(CONFIG_SECTION, CONFIG_KEY, code)
	cfg.save(CONFIG_PATH)

func _load_saved_locale() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	var saved: String = cfg.get_value(CONFIG_SECTION, CONFIG_KEY, "")
	if saved != "" and LANGUAGES.has(saved):
		TranslationServer.set_locale(saved)
