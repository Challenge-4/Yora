on run
	set isFrench to (user locale of (get system info)) starts with "fr"
	if isFrench then
		set dialogTitle to "Désinstaller Yora"
		set question to "Désinstaller Yora ?" & return & return & "L'application et son cache seront supprimés. Tes playlists, tes réglages et tes MP3 téléchargés sont conservés : une réinstallation retrouvera tout."
		set cancelLabel to "Annuler"
		set confirmLabel to "Désinstaller"
		set doneMessage to "Yora a été désinstallé."
		set failPrefix to "La désinstallation a échoué : "
	else
		set dialogTitle to "Uninstall Yora"
		set question to "Uninstall Yora?" & return & return & "The app and its cache will be removed. Your playlists, settings and downloaded MP3s are kept: a reinstall will find everything again."
		set cancelLabel to "Cancel"
		set confirmLabel to "Uninstall"
		set doneMessage to "Yora has been uninstalled."
		set failPrefix to "Uninstall failed: "
	end if

	try
		display dialog question buttons {cancelLabel, confirmLabel} default button confirmLabel cancel button cancelLabel with title dialogTitle with icon caution
	on error number -128
		return
	end try

	try
		if application id "com.yora.app" is running then
			tell application id "com.yora.app" to quit
			delay 2
		end if
	end try

	set scriptPath to POSIX path of (path to resource "uninstall.sh")
	set myPath to POSIX path of (path to me)
	try
		do shell script "/bin/bash " & quoted form of scriptPath & " " & quoted form of myPath
		display dialog doneMessage buttons {"OK"} default button "OK" with title dialogTitle
	on error errMsg
		display dialog failPrefix & errMsg buttons {"OK"} default button "OK" with title dialogTitle with icon stop
	end try
end run
