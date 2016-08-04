function download(resource)
	-- Check if app already exists
	if exists(resource) then
		printError("Error: Resource already exists\nUse option 'update' to update the it")
		return false
	end

	-- Download app files
	local fjson = net.download(CCAM_CONF.APP_REPO .. resource .. CCAM_CONF.APP_CONF)
	local file_json = json.decode(fjson)
	local file_list = file_json.files
	
	for _, v in pairs(file_list) do
		net.downloadFile(CCAM_CONF.APP_REPO .. resource .. "/" .. v,
						 CCAM_CONF.APP_DIR  .. resource .. "/" .. v)
	end

	-- Download dependencies
	local dependencies = file_json.dependencies
	for _, v in pairs(dependencies) do
		if not fs.exists(CCAM_CONF.LIB_DIR .. v) then
			net.downloadFile(CCAM_CONF.LIB_REPO .. v .. CCAM_CONF.LIB_MAIN,
							 CCAM_CONF.LIB_DIR  .. v .. CCAM_CONF.LIB_MAIN)
			net.downloadFile(CCAM_CONF.LIB_REPO .. v .. CCAM_CONF.LIB_CONF,
							 CCAM_CONF.LIB_DIR  .. v .. CCAM_CONF.LIB_CONF)
		end
	end

	-- Create bin shortcut
	local f_sc = fs.open(CCAM_CONF.BIN_DIR .. resource, 'w')
	f_sc.write("shell.run('" .. CCAM_CONF.APP_DIR .. resource .. CCAM_CONF.APP_MAIN .. "', ...)")
	f_sc.close()
end

function delete(resource, isLib)
	local dir = isLib and CCAM_CONF.LIB_DIR or CCAM_CONF.APP_DIR
	-- Check that app exists
	if not exists(resource, isLib) then
		printError("Error: App doesn't exist")
		return false
	end

	-- Confirm
	term.write("Are you sure you want to delete " .. resource .. "? (y/N): ")
	local ans = read()
	if ans == 'y' or ans == 'Y' then
		-- Remove the app
		fs.delete(dir .. resource)
		if not isLib then
			fs.delete(CCAM_CONF.BIN_DIR .. resource)
		end
	else
		print("Aborted.")
	end
end

function update(resource, isLib)
	local repo = isLib and CCAM_CONF.LIB_REPO or CCAM_CONF.APP_REPO
	local conf = isLib and CCAM_CONF.LIB_CONF or CCAM_CONF.APP_CONF
	local dir = isLib and CCAM_CONF.LIB_DIR or CCAM_CONF.APP_DIR

	-- Check that app exists
	if not exists(resource, isLib) then
		printError("Error: App doesn't exist")
		return false
	end

	-- Check for update
	local needUpdate = checkForUpdate(resource, isLib)

	if needUpdate then
		term.write("Are you sure you want to update " .. resource .. "? (y/N): ")
		local ans = read()
		if ans == 'y' or ans == 'Y' then

			-- Save app configuration
			local config = json.decodeFromFile(dir .. resource .. conf).configuration

			-- Download files
			local fjson = net.download(repo .. resource .. conf)
			local file_list = json.decode(fjson).files
			
			for _, v in pairs(file_list) do
				net.downloadFile(repo .. resource .. "/" .. v,
								 dir  .. resource .. "/" .. v)
			end

			-- Setup app configuration
			local json_data = json.decodeFromFile(dir .. resource .. conf)
			local new_json = fs.open(dir .. resource .. conf, 'w')

			if config then
				-- Not overwrite old configuration options
				for k, v in pairs(config) do
					json_data.configuration[k] = v
				end
			end

			-- Encode to json and close file
			new_json.write(json.encodePretty(json_data))
			new_json.close()

		else
			print("Aborted.")
		end
	else
		print("Resource is updated.")
	end

end

function checkForUpdate(resource, isLib)
	local repo = isLib and CCAM_CONF.LIB_REPO or CCAM_CONF.APP_REPO
	local conf = isLib and CCAM_CONF.LIB_CONF or CCAM_CONF.APP_CONF

	-- Check current version
	local currrent_version = getVersion(resource, isLib)
	print("Current version: " .. utils.versionStr(currrent_version))

	-- Check remote version
	net.downloadFile(repo .. resource .. conf,
					 CCAM_CONF.TMP_DIR .. resource .. "_conf.cfg")

	local file = fs.open(CCAM_CONF.TMP_DIR .. resource .. "_conf.cfg", 'r')
	local newest_version = json.decode(file.readAll()).version
	print("Newest version: " .. utils.versionStr(newest_version))

	file.close()
	utils.clearTemp()

	-- If there's an update return true
	return newest_version.build > currrent_version.build and true or false
end

function getVersion(resource, isLib)
	local conf = isLib and CCAM_CONF.LIB_CONF or CCAM_CONF.APP_CONF
	local dir = isLib and CCAM_CONF.LIB_DIR or CCAM_CONF.APP_DIR
	
	local app_json_file = fs.open(dir .. resource .. conf, 'r')

	-- Decode JSON
	local data = json.decode(app_json_file.readAll())
	app_json_file.close()

	-- Return version
	return data.version
end

function exists(resource, isLib)
	local dir = isLib and CCAM_CONF.LIB_DIR or CCAM_CONF.APP_DIR
	return fs.exists(dir .. resource)
end