function versionStr(version_table)
	return version_table.major .. "."
		.. version_table.minor .. "-"
		.. version_table.build
end

function strSplit(input, regex)
	regex = regex or "%s"
	
	local t = {}
	i = 1

	for str in input:gmatch("([^" .. reg .. "]+)") do
		t[i] = str
		i = i + 1
	end

	return t
end

function clearTemp()
	fs.delete(CCAM_CONF.TMP_DIR)
	fs.makeDir(CCAM_CONF.TMP_DIR)
end