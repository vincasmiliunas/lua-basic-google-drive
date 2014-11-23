local URL = require 'net.url'
local JSON = require 'json'
local OAUTH2 = require 'lua-basic-oauth2'
local GDUTILS = require 'lua-basic-google-drive.utils'
local OAUTILS = require 'lua-basic-oauth2.utils'

local baseConfig = {
	scope = 'https://www.googleapis.com/auth/drive',
	endpoint = 'https://www.googleapis.com/drive/v2/',
	endpoint_upload = 'https://www.googleapis.com/upload/drive/v2/',
}

local M = {}
M.__index = M

M.mimeType = {folder = 'application/vnd.google-apps.folder'}

function M.new(workConfig)
	local self = setmetatable({}, M)
	self.gdUtils = GDUTILS.new()
	self.oaUtils = OAUTILS.new()

	self.config = {}
	self.oaUtils:copyTable(baseConfig, self.config)
	self.oaUtils:copyTable(workConfig, self.config)

	self.oauth2 = OAUTH2.new(OAUTH2.google_config, self.config)
	return self
end

function M:init()
	return self.oauth2:init()
end

function M:buildUrl(params, endpoint)
	endpoint = endpoint or (self.config.endpoint .. 'files')
	local result = URL.parse(endpoint)
	result.query.alt = 'json'
	self.oaUtils:copyTable(params, result.query)
	return result
end

function M:request(url, payload, headers)
	local content, code = self.oauth2:request(url, payload, headers)
	if code ~= 200 then error(self.gdUtils:formatHttpCodeError(code)) end
	return JSON.decode(content)
end

function M:list(params)
	local url = self:buildUrl(params)
	return self:request(url)
end

function M:get(params, fileId)
	local url = self:buildUrl(params, self.config.endpoint .. 'files/' .. fileId)
	local data = self:request(url)
	local content, code = self.oauth2:request(data.downloadUrl)
	if code ~= 200 then error(self.gdUtils:formatHttpCodeError(code)) end
	return content, data
end

function M:insert(params, file)
	local url = self:buildUrl(params)
	return self:request(url, JSON.encode(file), {'Content-Type: application/json'})
end

function M:upload(params, file, blob)
	local url = self:buildUrl(params, self.config.endpoint_upload .. 'files')
	url.query.uploadType = 'multipart'
	local data = {
		{data = JSON.encode(file), type = 'application/json'},
		{data = blob, type = file.mimeType},
	}
	local content, contentType = self.gdUtils:buildMultipartRelated(data)
	return self:request(url, content, {'Content-Type: ' .. contentType})
end

function M:delete(params, fileId)
	local url = self:buildUrl(params, self.config.endpoint .. 'files/' .. fileId)
	local _, code = self.oauth2:request(url, nil, nil, 'DELETE')
	if code ~= 204 then error(self.gdUtils:formatHttpCodeError(code)) end
end

return M
