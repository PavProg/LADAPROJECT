@tool
extends Label
class_name AutoSizedLabel
## Автоматически подбирает максимальный размер шрифта,
## при котором текст полностью помещается в размеры Label.

@export var min_font_size: int = 1:
	set(value):
		min_font_size = max(1, value)
		_refit()
@export var max_font_size: int = 100:
	set(value):
		max_font_size = max(min_font_size, value)
		_refit()
## Дополнительный отступ (padding) со всех сторон, учитываемый при подборе.
@export var fit_padding: float = 0.0:
	set(value):
		fit_padding = value
		_refit()

var _last_text: String = ""
var _last_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	resized.connect(_refit)
	_refit()

func _process(_delta: float) -> void:
	# Отслеживаем изменения текста/размера, у которых нет своего сигнала.
	if text != _last_text or size != _last_size:
		_refit()

func refit() -> void:
	_refit()

func _refit() -> void:
	_last_text = text
	_last_size = size

	if text.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		return

	var font := get_theme_font("font")
	if font == null:
		return

	# Бинарный поиск максимального подходящего размера шрифта.
	var lo := min_font_size
	var hi := max_font_size
	var best := min_font_size

	while lo <= hi:
		var mid := (lo + hi) / 2
		if _fits(mid, font):
			best = mid
			lo = mid + 1
		else:
			hi = mid - 1

	add_theme_font_size_override("font_size", best)

func _fits(font_size: int, font: Font) -> bool:
	var available := size - Vector2(fit_padding, fit_padding) * 2.0
	if available.x <= 0.0 or available.y <= 0.0:
		return false

	# Если включён перенос строк — учитываем ширину для wrap.
	var wrap_width := -1.0
	if autowrap_mode != TextServer.AUTOWRAP_OFF:
		wrap_width = available.x

	var text_size := font.get_multiline_string_size(
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		wrap_width,
		font_size
	)

	# Небольшой допуск на субпиксельные округления.
	return text_size.x <= available.x + 0.5 and text_size.y <= available.y + 0.5
