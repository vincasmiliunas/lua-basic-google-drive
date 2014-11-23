local JSON = require 'json'
local GDRIVE = require 'lua-basic-google-drive'

local root = '/tmp/'
local gdrive = GDRIVE.new{creds_file = root..'/creds.json', tokens_file = root..'/tokens.json'}

work = function()
	print('-- initializing')
	gdrive:init()

	print('-- folder insertion')
	local file = {title = 'test', mimeType = gdrive.mimeType.folder}
	local folder = gdrive:insert({}, file)
	print(JSON.encode(folder))

	print('-- file upload')
	local file = {title = 'test', mimeType = "text/plain", parents = {{id = folder.id}}}
	local ret = gdrive:upload({}, file, string.format('os.time() = %d', os.time()))
	print(JSON.encode(ret))

	print('-- file listing')
	local ret = gdrive:list{
		maxResults = 1,
		q = string.format("mimeType = '%s' and title = '%s' and '%s' in parents", 'text/plain', 'test', folder.id),
	}
	print(JSON.encode(ret))

	print('-- file retrieval')
	local content, meta = gdrive:get({}, ret.items[1].id)
	print('File content: ' .. content)
	print('File metadata: ' .. JSON.encode(meta))

	print('-- file deletion')
	gdrive:delete({}, ret.items[1].id)

	print('-- folder deletion')
	gdrive:delete({}, folder.id)
end
local status, err = pcall(work)
if status then
  print('Operations completed successfully.')
else
  print('Failure occurred: ' .. err)
end
