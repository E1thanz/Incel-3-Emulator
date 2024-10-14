extends ColorRect

const programButtonScene = preload("res://Scenes/File Button.tscn")

var activeButton = null
var fileButtons = []
const maximum_files = 5

func _ready():
	DisplayServer.window_set_min_size(Vector2i(1920, 1080))
	%"Program View".add_gutter(0)
	%"Program View".set_gutter_width(0, 60)
	%"Program View".add_gutter(1)
	%"Program View".set_gutter_width(1, 35)
	%"Program View".set_gutter_type(1, TextEdit.GUTTER_TYPE_ICON)
	
	get_tree().set_auto_accept_quit(false)
	
	if not FileAccess.file_exists("user://fileBar.txt"):
		create_new_file("New File")
		return
		
	var file = FileAccess.open("user://fileBar.txt", FileAccess.READ_WRITE)
	var new_contents = ""
	while file.get_position() < file.get_length():
		var path = file.get_line().strip_edges()
		if not FileAccess.file_exists(path):
			continue
		new_contents += path + "\n"
		var split_path = Array(path.split("\\")).pop_back()
		create_new_file(split_path)
		activeButton.set_meta("FilePath", path)
		var program_file = FileAccess.open(activeButton.get_meta("FilePath"), FileAccess.READ)
		activeButton.set_meta("File", program_file.get_as_text())
	file.seek(0)
	file.store_string(new_contents)
	
	if activeButton == null:
		create_new_file("New File")
		return
	
	activeButton.selected = true
	activeButton.update_selection()
	%"Program View".text = activeButton.get_meta("File")
	%"Edit View Rect".color = Color.hex(0x2d2d2dff)
	activeButton.set_meta("Changed", false)
		
func create_new_file(name):
	if fileButtons.size() == maximum_files:
		return
	
	if activeButton != null:
		activeButton.selected = false
		activeButton.update_selection()
	
	var newFileButton = programButtonScene.instantiate()
	newFileButton.set_meta("File", "")
	newFileButton.connect("change_selected_file_signal", _change_selected_file)
	newFileButton.connect("close_file_signal", _close_file)
	fileButtons.append(newFileButton)
	newFileButton.selected = true
	%"File Bar".add_child(newFileButton)
	newFileButton.set_meta("FilePath", "")
	newFileButton.get_child(0).get_child(1).text = name
	activeButton = newFileButton
	%"Program View".text = ""
	
func _notification(notification):
	if notification == NOTIFICATION_WM_CLOSE_REQUEST:
		if activeButton.get_meta("Changed"):
			%"Save Window".show_request()
			var response = await Signal(%"Save Window", "save_response")
			if response:
				_save_file_press()
		close()

func _open_file_press():
	if fileButtons.size() == maximum_files:
		return
	
	var results = []
	OS.execute("powershell.exe", PackedStringArray(["\"Add-Type -AssemblyName System.Windows.Forms; 
														$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog; 
														$FileBrowser.initialDirectory = (Get-Item .).FullName + \\\"\\Files\\\";
														$FileBrowser.filter = \\\"txt files (*.txt)|*.txt\\\";
														[void]$FileBrowser.ShowDialog(); 
														$FileBrowser.FileName\""]), results, true)
	if results.is_empty() or results[0].strip_edges().is_empty():
		return
	
	for button in fileButtons:
		if button.get_meta("FilePath") == results[0].strip_edges():
			return
	
	activeButton.selected = false
	activeButton.update_selection()
	create_new_file(Array(results[0].strip_edges().split("\\")).pop_back())
	activeButton.set_meta("FilePath", results[0].strip_edges())
		
	var file = FileAccess.open(activeButton.get_meta("FilePath"), FileAccess.READ)
	var file_text = file.get_as_text()
	%"Program View".text = file_text
	activeButton.set_meta("File", file_text)
	%"Edit View Rect".color = Color.hex(0x2d2d2dff)
	activeButton.set_meta("Changed", false)

func _save_file_press():
	for button in fileButtons:
		save_file(button)
	%"Edit View Rect".color = Color.hex(0x2d2d2dff)
	
func save_file(button) -> bool:
	if not button.get_meta("Changed"):
		return false
	if button.get_meta("FilePath").is_empty():
		# THIS IS A TEMPORARY LINUX SOLUTION
		if OS.get_name() == "Linux":
			return false
		var results = []
		OS.execute("powershell.exe", PackedStringArray(["\"Add-Type -AssemblyName System.Windows.Forms;
															$FileBrowser = New-Object System.Windows.Forms.SaveFileDialog;
															$FileBrowser.initialDirectory = (Get-Item .).FullName + \\\"\\Files\\\";
															$FileBrowser.filter = \\\"txt files (*.txt)|*.txt\\\";
															[void]$FileBrowser.ShowDialog();
															$FileBrowser.FileName\""]), results, true)
		if results.is_empty() or results[0].strip_edges().is_empty():
			return false
		
		button.set_meta("FilePath", results[0].strip_edges())
	
	var split_path = Array(button.get_meta("FilePath").split("\\")).pop_back()
	button.get_child(0).get_child(1).text = split_path
	var file = FileAccess.open(button.get_meta("FilePath"), FileAccess.WRITE)
	if button == activeButton:
		activeButton.set_meta("File", %"Program View".text)
		file.store_string(%"Program View".text)
	else:
		file.store_string(button.get_meta("File"))
	button.set_meta("Changed", false)
	return true

func _compile_press():
	if activeButton.get_meta("FilePath").is_empty():
		if not save_file(activeButton):
			return
	
	var pythonPath = "python"
	
	# THIS IS A TEMPORARY LINUX SOLUTION
	if OS.get_name() == "Linux":
		pythonPath = "python3"
	var pythonOut = []
	OS.execute(pythonPath, ["./PythonFiles/Assembler.py", activeButton.get_meta("FilePath")], pythonOut, true)
	if not pythonOut[0].strip_edges().is_empty():
		%"Error Window".show_error(pythonOut[0].strip_edges())
	else:
		var results = []
		
		# THIS IS A TEMPORARY LINUX SOLUTION
		if OS.get_name() == "Windows":
			OS.execute("powershell.exe", PackedStringArray(["\"Add-Type -AssemblyName System.Windows.Forms;
																$FileBrowser = New-Object System.Windows.Forms.SaveFileDialog;
																$FileBrowser.initialDirectory = (Get-Item .).FullName + \\\"\\Files\\\";
																$FileBrowser.filter = \\\"schem files (*.schem)|*.schem\\\";
																[void]$FileBrowser.ShowDialog();
																$FileBrowser.FileName\""]), results, true)
			if results.is_empty() or results[0].strip_edges().is_empty():
				return false
		else:
			results.append("./PythonFiles/program.schem")
		pythonOut.clear()
		OS.execute(pythonPath, ["./PythonFiles/Schematic Generator.py", "./PythonFiles/assemblyFile.txt", results[0].strip_edges().replace("\\", "/")], pythonOut, true)

func _on_program_view_text_changed():
	if not activeButton.get_meta("Changed"):
		activeButton.get_child(0).get_child(1).text = activeButton.get_child(0).get_child(1).text + "*" # "[color=red][b]*[/b][/color]"
		%"Edit View Rect".color = Color.hex(0x5fb3f5ff)
		activeButton.set_meta("Changed", true)
		
func _change_selected_file(clickedButton):
	activeButton.set_meta("File", %"Program View".text)
	activeButton.selected = false
	activeButton.update_selection()
	clickedButton.selected = true
	clickedButton.update_selection()
	activeButton = clickedButton
	%"Program View".text = clickedButton.get_meta("File")
	if clickedButton.get_meta("Changed"):
		%"Edit View Rect".color = Color.hex(0x5fb3f5ff)
	else:
		%"Edit View Rect".color = Color.hex(0x2d2d2dff)
		
func _close_file(clickedButton):
	if clickedButton.get_meta("Changed"):
		%"Save Window".show_request()
		var response = await Signal(%"Save Window", "save_response")
		if response:
			if not save_file(clickedButton):
				return
	
	if clickedButton == activeButton:
		if fileButtons.size() > 1:
			var closedIndex = fileButtons.find(clickedButton)
			if closedIndex - 1 < 0:
				closedIndex += 2
			fileButtons[closedIndex - 1].selected = true
			fileButtons[closedIndex - 1].update_selection()
			activeButton = fileButtons[closedIndex - 1]
		if fileButtons.size() == 1:
			create_new_file("New File")
	
	fileButtons.erase(clickedButton)
	clickedButton.queue_free()
	
	%"Program View".text = activeButton.get_meta("File")
	%"Edit View Rect".color = Color.hex(0x2d2d2dff)
	activeButton.set_meta("Changed", false)

func close():
	var save_file = FileAccess.open("user://fileBar.txt", FileAccess.WRITE)
	for button in fileButtons:
		var path = button.get_meta("FilePath")
		if path != "":
			save_file.store_line(path)
	get_tree().quit() # default behavior
