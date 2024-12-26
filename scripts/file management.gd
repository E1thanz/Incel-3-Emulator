extends ColorRect

const programButtonScene = preload("res://Scenes/File Button.tscn")

var fileDialog = "\"Add-Type -AssemblyName System.Windows.Forms;
										$form = New-Object System.Windows.Forms.Form;
										$form.TopMost = $true;
										$form.Size = New-Object System.Drawing.Size(0, 0);
										$form.StartPosition = 'Manual';
										$form.Location = New-Object System.Drawing.Point(-1000, -1000);
										$FileBrowser = New-Object System.Windows.Forms.%sFileDialog;
										$FileBrowser.initialDirectory = (Get-Item .).FullName + \\\"\\Files\\\";
										$FileBrowser.filter = \\\"%s files (*.%s)|*.%s\\\";
										$form.add_Shown({
											$null = $FileBrowser.ShowDialog($form);
											Write-Host $FileBrowser.FileName
											$FileBrowser.Dispose();
											$form.Close();
										})
										$form.ShowDialog();\""


var activeButton = null
var fileButtons = []
const maximum_files = 5

func _ready():
	#DisplayServer.window_set_min_size(Vector2i(1920, 1080))
	%"Program View".add_gutter(0)
	%"Program View".set_gutter_width(0, 60)
	%"Program View".add_gutter(1)
	%"Program View".set_gutter_width(1, 40)
	%"Program View".add_gutter(2)
	%"Program View".set_gutter_width(2, 35)
	%"Program View".set_gutter_clickable(2, true)
	%"Program View".set_gutter_type(2, TextEdit.GUTTER_TYPE_ICON)
	%Emulator._Reset_Pressed()
	
	get_tree().set_auto_accept_quit(false)
	var settings = ConfigFile.new()
	var err = settings.load("user://settings.txt")
	if err != OK:
		return
	var paths = settings.get_value("files", "paths")
	
	if paths != null and paths.size() != 0:
		for path in paths:
			if not FileAccess.file_exists(path):
				continue
			var split_path = Array(path.split("\\")).pop_back()
			create_new_file(split_path)
			activeButton.set_meta("FilePath", path)
			var program_file = FileAccess.open(activeButton.get_meta("FilePath"), FileAccess.READ)
			activeButton.set_meta("File", program_file.get_as_text())
	
	if activeButton == null:
		create_new_file("New File")
		return
	
	activeButton.selected = true
	activeButton.update_selection()
	%"Program View".text = activeButton.get_meta("File")
	%"Edit View Rect".color = Color.hex(0x2d2d2dff)
	activeButton.set_meta("Changed", false)
		
func create_new_file(file_name):
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
	newFileButton.get_child(0).get_child(1).text = file_name
	activeButton = newFileButton
	%"Program View".text = ""
	%"Edit View Rect".color = Color.hex(0x2d2d2dff)
	
func _notification(notification):
	if notification == NOTIFICATION_WM_CLOSE_REQUEST:
		if activeButton.get_meta("Changed"):
			%"Save Window".show_request()
			var response = await Signal(%"Save Window", "save_response")
			if response == null:
				return
			if response:
				_save_file_press()
		close()

func _open_file_press():
	if fileButtons.size() == maximum_files:
		return
	
	var results = []
	OS.execute("powershell.exe", PackedStringArray([fileDialog % ["Open", "txt", "txt", "txt"]]), results, true)
	
	var processed_results = results[0].strip_edges().split("\n")[0]
	
	if processed_results == "Cancel":
		return
	
	for button in fileButtons:
		if button.get_meta("FilePath") == processed_results:
			return
	
	if activeButton.get_meta("FilePath") == "" and not activeButton.get_meta("Changed"):
		fileButtons.erase(activeButton)
		activeButton.queue_free()
	else:
		activeButton.selected = false
		activeButton.update_selection()
	create_new_file(Array(processed_results.split("\\")).pop_back())
	activeButton.set_meta("FilePath", processed_results)
		
	var file = FileAccess.open(activeButton.get_meta("FilePath"), FileAccess.READ)
	var file_text = file.get_as_text()
	%"Program View".text = file_text
	activeButton.set_meta("File", file_text)
	%"Edit View Rect".color = Color.hex(0x2d2d2dff)
	activeButton.set_meta("Changed", false)

func _save_file_press():
	for button in fileButtons:
		save_file(button)
	
func save_file(button) -> bool:
	if not button.get_meta("Changed"):
		return false
	if button.get_meta("FilePath").is_empty():
		# THIS IS A TEMPORARY LINUX SOLUTION
		if OS.get_name() == "Linux":
			return false
		var results = []
		
		OS.execute("powershell.exe", PackedStringArray([fileDialog % ["Save", "txt", "txt", "txt"]]), results, true)
		
		var processed_results = results[0].strip_edges().split("\n")[0]
	
		if processed_results == "Cancel":
			return false
		
		button.set_meta("FilePath", processed_results)
	
	if button == activeButton:
		%"Edit View Rect".color = Color.hex(0x2d2d2dff)
	
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
	if activeButton.get_meta("FilePath").is_empty() or activeButton.get_meta("Changed"):
		if not save_file(activeButton):
			return
	
	var pythonOut = []
	OS.execute("./PythonFiles/venv/Scripts/python.exe", ["./PythonFiles/Assembler.py", activeButton.get_meta("FilePath")], pythonOut, true)
	
	if not pythonOut[0].strip_edges().is_empty():
		%"Error Window".show_error(pythonOut[0].strip_edges())
	else:
		var results = []
		
		# THIS IS A TEMPORARY LINUX SOLUTION
		if OS.get_name() == "Windows":
			OS.execute("powershell.exe", PackedStringArray([fileDialog % ["Save", "schem", "schem", "schem"]]), results, true)
			
			var processed_results = results[0].strip_edges().split("\n")[0]
	
			if processed_results == "Cancel":
				return false
			
			results.clear()
			results.append(processed_results)
		else:
			results.append("./PythonFiles/program.schem")
		pythonOut.clear()
		OS.execute("./PythonFiles/venv/Scripts/python.exe", ["./PythonFiles/Schematic Generator.py", "./PythonFiles/assemblyFile.txt", results[0].strip_edges().replace("\\", "/")], pythonOut, true)

func _on_program_view_text_changed():
	if not activeButton.get_meta("Changed"):
		activeButton.get_child(0).get_child(1).text = activeButton.get_child(0).get_child(1).text + "*" # "[color=red][b]*[/b][/color]"
		%"Edit View Rect".color = Color.hex(0x5fb3f5ff)
		activeButton.set_meta("Changed", true)
		
func _change_selected_file(clickedButton):
	if clickedButton == activeButton:
		return
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
		if response == null:
			return
		if response:
			save_file(clickedButton)
	
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
	%Emulator.update_settings()
	%Emulator.is_running = false
	if %Emulator.thread.is_alive():
		%Emulator.semaphore.post()
		%Emulator.thread.wait_to_finish()
	get_tree().quit() # default behavior
