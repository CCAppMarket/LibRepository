function downloadFile(url, file_path)
	local data = download(url)
	local file = fs.open(file_path, 'w')
	file.write(data)
	file.close()
end

function download(path)
	http.request(path)
	requesting = true

	while requesting do
		event, url, sourceText = os.pullEvent()

		if event == "http_success" then
			respondedText = sourceText.readAll()

			sourceText.close()

			requesting = false
		elseif event == "http_failure" then
			printError("Server didn't respond.")

			requesting = false
		end
	end

	return respondedText
end
