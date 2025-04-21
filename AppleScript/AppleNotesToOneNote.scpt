-- Define export folder
set exportFolder to (path to desktop folder as text) & "Exported Notes:"
do shell script "mkdir -p ~/Desktop/'Exported Notes'"

-- Define flagged notes log file
set flaggedLogPath to POSIX path of (path to desktop folder) & "Flagged Notes.txt"
do shell script "echo '' > " & quoted form of flaggedLogPath -- reset log

set maxNoteSize to 100000 -- Character limit
set validNotes to {}

-- Gather notes, excluding Recently Deleted
tell application "Notes"
	set allFolders to every folder of default account
	
	repeat with f in allFolders
		if name of f is not equal to "Recently Deleted" then
			set folderNotes to notes of f
			repeat with n in folderNotes
				copy n to end of validNotes
			end repeat
		end if
	end repeat
end tell

-- Loop through notes
repeat with i from 1 to count of validNotes
	set theNote to item i of validNotes
	
	tell application "Notes"
		set noteTitle to name of theNote
		set noteBody to body of theNote
	end tell
	
	-- Check for large note
	if (length of noteBody) > maxNoteSize then
		set logEntry to noteTitle & " (Length: " & (length of noteBody as string) & ")"
		do shell script "echo " & quoted form of logEntry & " >> " & quoted form of flaggedLogPath
		log "Skipped large note: " & noteTitle
		-- skip to next note
		-- AppleScript doesn't like `next repeat` here, so use a workaround
		-- Just wrap rest of logic in an `else`
	else
		-- Create safe file name
		set safeTitle to do shell script "echo " & quoted form of noteTitle & " | tr -cd '[:alnum:]_-' | cut -c1-50"
		if safeTitle is "" then set safeTitle to "Untitled_" & (i as string)
		
		set htmlPath to (POSIX path of exportFolder) & safeTitle & ".html"
		set htmlContent to "<html><head><meta charset='utf-8'></head><body>" & noteBody & "</body></html>"
		
		-- Write to file safely
		do shell script "printf %s " & quoted form of htmlContent & " > " & quoted form of htmlPath
		
		-- Open in Safari
		set fileURL to "file://" & htmlPath
		tell application "Safari"
			open location fileURL
			delay 2
			activate
		end tell
		
		delay 1
		tell application "System Events"
			keystroke tab
			delay 0.3
			keystroke "a" using {command down}
			delay 0.2
			keystroke "c" using {command down}
			delay 0.5
		end tell
		
		tell application "Microsoft OneNote"
			activate
		end tell
		delay 1
		
		tell application "System Events"
			keystroke "n" using {command down}
			delay 1
			keystroke noteTitle
			delay 0.2
			keystroke tab
			delay 0.2
			keystroke "v" using {command down}
		end tell
		
		tell application "Safari"
			close front window
		end tell
		
		delay 1
	end if
end repeat

-- Get paths
set exportPath to (POSIX path of exportFolder)
set logPath to flaggedLogPath

-- Tell Finder to own the dialog (brings it to front)
tell application "Finder"
	activate
	display dialog "✅ Export complete!

Check your exported content:
• Notes to HTML (success): " & exportPath & "
• Flagged Notes Log: " & logPath buttons {"OK"} default button "OK"
end tell
