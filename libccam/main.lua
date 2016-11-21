
function search(resource, silent)
	if not silent then print("Searching for: " .. resource) end
	for k, v in pairs(CCAM_CONF.REPOS) do
		local url = v.base_url .. v.username .. "/" .. v.repository .. "/" .. v.branch .. "/"
		if not silent then print("Searching repo: " .. k) end

		if http.get(url  .. resource .. CCAM_CONF.CONF) then
			if not silent then print("Found in repo: " .. k .. " -> " .. resource) end
			return url .. resource
		end
	end

	error("Resource not found: " .. resource)
end

function download(resource)
	-- Check if app already exists
	if exists(resource) then
		printError("Error: Resource already exists\nUse option 'update' to update the it")
		return false
	end

	-- Download app files
	local search_result = search(resource, true)
	local fjson = net.download(search_result .. CCAM_CONF.CONF)
	local file_json = json.decode(fjson)
	local file_list = file_json.files

	for _, v in pairs(file_list) do
		net.downloadFile(search_result .. "/" .. v,
						 CCAM_CONF.APP_DIR  .. resource .. "/" .. v)
	end

	-- Download dependencies
	local dependencies = file_json.dependencies
	for _, v in pairs(dependencies) do
		if not fs.exists(CCAM_CONF.LIB_DIR .. v) then
			net.downloadFile(search_result .. CCAM_CONF.MAIN,
							 CCAM_CONF.LIB_DIR  .. v .. CCAM_CONF.MAIN)
			net.downloadFile(search_result .. CCAM_CONF.CONF,
							 CCAM_CONF.LIB_DIR  .. v .. CCAM_CONF.CONF)
		end
	end

	-- Create bin shortcut
	local f_sc = fs.open(CCAM_CONF.BIN_DIR .. resource, 'w')
	f_sc.write("shell.run('" .. CCAM_CONF.APP_DIR .. resource .. CCAM_CONF.MAIN .. "', ...)")
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

function update(resource, isLib, silent)
	local repo = search(resource, true) --isLib and CCAM_CONF.LIB_REPO or CCAM_CONF.APP_REPO
	local conf = CCAM_CONF.CONF
	local dir = isLib and CCAM_CONF.LIB_DIR or CCAM_CONF.APP_DIR

	-- Check that app exists
	if not exists(resource, isLib) then
		printError("Error: App doesn't exist")
		return false
	end

	-- Check for update
	local needUpdate = checkForUpdate(resource, isLib, silent)

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
		if not silent then
			print("Resource is updated.")
		end
	end
end

function updateall(silent)
	print("Checking for updates...")
	-- Update apps
	for _, v in pairs(fs.list(CCAM_CONF.APP_DIR)) do
		if not silent then
			print("\nUpdating app: " .. v)
		end
		update(v, false, silent)
	end

	-- Update libs
	for _, v in pairs(fs.list(CCAM_CONF.LIB_DIR)) do
		if not silent then
			print("\nUpdating lib: " .. v)
		end
		update(v, true, silent)
	end
end

function checkForUpdate(resource, isLib, silent)
	local repo = search(resource, true) --isLib and CCAM_CONF.LIB_REPO or CCAM_CONF.APP_REPO
	local conf = CCAM_CONF.CONF

	-- Check current version
	local currrent_version = getVersion(resource, isLib)
	if not silent then
		print("Current version: " .. utils.versionStr(currrent_version))
	end

	-- Check remote version
	net.downloadFile(repo .. conf,
					 CCAM_CONF.TMP_DIR .. resource .. "_conf.cfg")

	local file = fs.open(CCAM_CONF.TMP_DIR .. resource .. "_conf.cfg", 'r')
	local newest_version = json.decode(file.readAll()).version
	if not silent then
		print("Newest version: " .. utils.versionStr(newest_version))
	end

	file.close()
	utils.clearTemp()

	-- If there's an update return true
	return newest_version.build > currrent_version.build and true or false
end

function getVersion(resource, isLib)
	local conf = CCAM_CONF.CONF

	local app_json_file = fs.open(exists(resource) .. resource .. conf, 'r')

	-- Decode JSON
	local data = json.decode(app_json_file.readAll())
	app_json_file.close()

	-- Return version
	return data.version
end

function exists(resource, isLib)
	return fs.exists(CCAM_CONF.APP_DIR .. resource) and CCAM_CONF.APP_DIR
			or fs.exists(CCAM_CONF.LIB_DIR .. resource) and CCAM_CONF.LIB_DIR
end

function list()
	for repo, tab in pairs(CCAM_CONF.REPOS) do
		print("\nRepository: " .. repo)
		local api_response = http.get("https://api.github.com/repos/".. tab.username .."/" .. tab.repository .. "/contents?ref=" .. tab.branch)
		local data = api_response.readAll()
		local parsed = json.decode(data)

		local app_ver = {}

		for _, b in pairs(parsed) do
			local app_name = b.path
			if app_name ~= "README.md" then
				local dlver = http.get(search(app_name, true) .. CCAM_CONF.CONF)
				if dlver then
					local v_data = dlver.readAll()
					dlver.close()
					local v_parsed = json.decode(v_data)
					local currentVer = "none"
					if exists(app_name) then
						currentVer = utils.versionStr(getVersion(app_name))
					end
					app_ver[app_name] = {currentVer, utils.versionStr(v_parsed.version)}
					print(app_name .. "\t[Current: " .. currentVer .. ", Latest: " .. utils.versionStr(v_parsed.version) .. "]")
				end
			end
		end

	end
end
