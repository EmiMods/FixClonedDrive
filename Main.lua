scriptTitle = "Aurora Scanpath Fixer"
scriptAuthor = "EmiMods"
scriptVersion = 1.0
scriptDescription = "Update Aurora database to fix scan paths and covers."
scriptIcon = "icon.png"
scriptPermissions = { "filesystem", "sql" }

ExitTriggered = false

-- Main entry point to script
function main()
    local updatedScanpaths = false

    -- First grab the desired deviceID
    local newDeviceID = promptDriveSelect()

    if not ExitTriggered and newDeviceID ~= "" then
        local dbRows = {}
        local dialogPaths = ""
        local oldDeviceID = ""
        -- Add all rows with deviceId not matching newDeviceID
        for i, row in pairs(Sql.ExecuteFetchRows("SELECT id, path, deviceid FROM scanpaths ORDER BY id ASC")) do
            if row["DeviceId"] ~= newDeviceID then --TODO Switch this back to ~=, set to == for testing
                oldDeviceID = row["DeviceId"]
                dbRows[i] = { row["Id"], row["Path"], row["DeviceId"] }
                dialogPaths = dialogPaths .. dbRows[i][2] .. " - (" .. string.sub(oldDeviceID, 1, 7) .. "..->" .. string.sub(newDeviceID, 1, 7) .. "..)\n"
            end
        end 

        -- Display confirmation box depending on if array is empty
        local isTableEmpty = rawequal(next(dbRows), nil)
        local confirmation
        if isTableEmpty then
            confirmation = Script.ShowMessageBox("Error", "No scanpaths were found which required update. Scanpaths may already be set to appropriate deviceID.", "Continue", "Exit")
        else
            confirmation = Script.ShowMessageBox("Scan paths to be updated..", dialogPaths, "Continue", "Exit")
        end

        if confirmation.Button == 2 then
            ExitTriggered = true
        else
            if not isTableEmpty and not ExitTriggered then
                for _, row in pairs(dbRows) do
                    Sql.Execute("UPDATE scanpaths SET deviceid='" .. newDeviceID .. "' WHERE id=" .. row[1] .. ";")
                    updatedScanpaths = true
                end
            end

            if updatedScanpaths then
                confirmation = Script.ShowMessageBox("Update Complete", "Scanpaths have been updated with the selected deviceID.\nA restart is required for changes to take affect. Restart now?", "Yes", "No")
                if confirmation.Button == 1 then
                    Aurora.Restart()
                end
            end
        end
    end
end

function promptDriveSelect()
    -- Grab list of drives and form dialog for menu options
    local arrDrives = {}
    local arrDialog = {}
    for i, drives in ipairs(FileSystem.GetDrives(false)) do
		arrDrives[i] = { drives["MountPoint"], drives["Serial"] }
        -- Arbitrary formatting which I think looks nice and lines up well
        local padding = ""
        if (string.len(arrDrives[i][1])*1.25) <= 25 then
            for i=1, 25 - (string.len(arrDrives[i][1])*1.25) do
                padding = padding .. " "
            end
        end

        arrDialog[i] = arrDrives[i][1] .. padding .. "(Serial: " .. string.sub(arrDrives[i][2], 1, 12) .. "...)"
	end

    -- Show the popup selection dialog
    local dialog = Script.ShowPopupList(
                                            "Please select your new/cloned drive.",
                                            "No drives found.",
                                            arrDialog
    )
    
    -- Build confirmation prompt for selection dialog
    if not dialog.Canceled then
        local selectedKey = dialog.Selected.Key
        local dialogSelectedDrive = string.sub(arrDrives[selectedKey][1], 1, (string.len(arrDrives[selectedKey][1]) - 1))
        local serial = arrDrives[dialog.Selected.Key][2]
        local dialogSelectedSerial = string.sub(serial, 1, 28) .. "..."

        local confirmation = Script.ShowMessageBox("New Device Selected", "You have selected:\n-" .. dialogSelectedDrive .. "\n-Serial: " .. dialogSelectedSerial, "Continue", "Exit")
        if confirmation.Button == 2 then
            ExitTriggered = true
            return ""
        else
            return serial
        end
    end
end

