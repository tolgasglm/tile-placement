extends PanelContainer

signal rotate_requested()
signal confirm_requested()

var info_label: Label
var confirm_btn: Button

# Bu panel sabit elemanlara sahip (Label + 2 buton), bu yüzden onları _ready()'de bir kere kuruyoruz
func _ready() -> void:
	var vbox = VBoxContainer.new()
	add_child(vbox)

	info_label = Label.new()
	vbox.add_child(info_label)

	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)

	var rotate_btn = Button.new()
	rotate_btn.text = "Döndür"
	rotate_btn.pressed.connect(func(): rotate_requested.emit())
	hbox.add_child(rotate_btn)

	confirm_btn = Button.new()
	confirm_btn.text = "Onayla"
	confirm_btn.pressed.connect(func(): confirm_requested.emit())
	hbox.add_child(confirm_btn)

	visible = false

# Güncel kenar bilgisini ve "sığıyor mu" durumunu ekrana yansıtır
func update_display(edges_text: String, fits: bool) -> void:
	info_label.text = edges_text + "\nSığıyor mu: " + ("EVET" if fits else "HAYIR")
	confirm_btn.disabled = not fits   # Sığmıyorsa Onayla tıklanamaz

func show_panel() -> void:
	visible = true

func hide_panel() -> void:
	visible = false
