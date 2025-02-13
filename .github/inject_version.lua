local version = ...

assert(version, "no version provided")

local VERSION_FILE = "src/version-info.lua"

local file = fs.read_file(VERSION_FILE)

--[[
package constants

const (
	VERSION  = "dev"
	CODENAME = "tezpay"
)
]]

file = file:gsub('AMI_VERSION%s*=%s*"dev"', 'AMI_VERSION = "' .. version .. '"')
print(file)
fs.write_file(VERSION_FILE, file)