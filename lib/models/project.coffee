git = require 'git-utils'
_path = require 'path'
CSON = require 'season'
fs = require 'fs'

module.exports =
class Project
  constructor: (@path) ->
    @icon = "icon-repo"
    @ignored = false
    @title = _path.basename(@path)
    @readConfigFile()

  exists: ->
    fs.existsSync(@path)

  isDirty: ->
    repository = git.open @path
    Object.keys(repository.getStatus()).length != 0

  branch: ->
    repository = git.open @path
    repository.getShortHead()

  readConfigFile: ->
    filepath = @path + _path.sep + ".git-project"
    if fs.existsSync(filepath)
      data = CSON.readFileSync(filepath)
      if data?
        @title = data['title'] if data['title']?
        @ignored = data['ignore'] if data['ignore']?
        @icon = data['icon'] if data['icon']?
