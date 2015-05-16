$ = require 'jquery'
fs = require 'fs-plus'
path = require 'path'
utils = require './utils'

Project = require './models/project'
ProjectsListView = require './views/projects-list-view'

module.exports =
  config:
    rootPath:
      title: "Root paths"
      description: "Paths to folders containing Git repositories, separated by semicolons."
      type: "string"
      default: fs.absolute(fs.getHomeDirectory() + "#{path.sep}repos")
    ignoredPath:
      title: "Ignored paths"
      description: "Paths to folders that should be ignored, separated by semicolons."
      type: "string"
      default: ""
    ignoredPatterns:
      title: "Ignored patterns"
      description: "Patterns that should be ignored (e.g.: node_modules), separated by semicolons."
      type: "string"
      default: "node_modules;\\.git"
    sortBy:
      title: "Sort by"
      type: "string"
      default: "Project name"
      enum: ["Project name", "Latest modification date", "Size"]
    maxDepth:
      title: "Max Folder Depth"
      type: 'integer'
      default: 5
      minimum: 1
    openInDevMode:
      title: "Open in development mode"
      type: "boolean"
      default: false
    notificationsEnabled:
      title: "Notifications enabled"
      type: "boolean"
      default: true
    showGitInfo:
      title: "Show repositories status"
      description: "Display the branch and a status icon in the list of projects"
      type: "boolean"
      default: true


  projects: []
  view: null

  activate: (state) ->
    @checkForUpdates()
    atom.commands.add 'atom-workspace',
      'git-projects:toggle': =>
        @createView().toggle(@)


  # Checks for updates by sending an ajax request to the latest package.json
  # hosted on Github.
  checkForUpdates: ->
    packageVersion = require("../package.json").version
    $.ajax({
      url: 'https://raw.githubusercontent.com/prrrnd/atom-git-projects/master/package.json',
      success: (data) ->
        latest = JSON.parse(data).version
        if(packageVersion != latest)
          if atom.config.get('git-projects.notificationsEnabled')
            atom.notifications.addInfo("<strong>Git projects</strong><br>Version #{latest} available!", dismissable: true)
    })


  # Opens a project. Supports for dev mode via package settings
  #
  # project - The {Project} to open.
  openProject: (project) ->
    @saveRecentProject(project)
    atom.open options =
      pathsToOpen: [project.path]
      devMode: atom.config.get('git-projects.openInDevMode')


  # Creates an instance of the list view
  createView: ->
    @view ?= new ProjectsListView()


  # Clears the projects array
  clearProjectsList: ->
    @projects = []


  # Determines if a path should be ignored based on the package settings
  # Returns true if the given _path should be ignored, false otherwise
  #
  # _path - {String} the path to test
  shouldIgnorePath: (_path) ->
    ignoredPaths = utils.parsePathString(atom.config.get('git-projects.ignoredPath'))
    ignoredPattern = new RegExp((atom.config.get('git-projects.ignoredPatterns') || "").split(/\s*;\s*/g).join("|"), "g")
    return true if ignoredPattern.test(_path)
    return ignoredPaths and ignoredPaths.has(_path)

  recentProjectPaths: ->
    JSON.parse(window.localStorage['git-projects.recentPaths'] || '[]')

  recentProjects: ->
    @recentProjectPaths()
          .map((path) -> new Project(path))
          .filter((prj) -> prj.exists() && !prj.isCurrentProject())
    
  saveRecentProject: (project) ->
    recents = @recentProjectPaths();
    if recents.indexOf(project.path) < 0
      recents.unshift(project.path)
      window.localStorage['git-projects.recentPaths'] = JSON.stringify(recents);
  
  # Finds all the git repositories recursively from the given root path(s)
  #
  # root - {String} the path to search from
  findGitRepos: (root = atom.config.get('git-projects.rootPath'), cb) ->
    rootPaths = utils.parsePathString(root)
    return cb(@projects) unless rootPaths?

    recentProjects = @recentProjects()

    pathsChecked = 0
    rootPaths.forEach (rootPath) =>

      sendCallback = =>
        if ++pathsChecked == rootPaths.size
          utils.sortBy(@projects)
          @projects.unshift.apply(@projects, recentProjects);
          cb(@projects)
      return sendCallback() if @shouldIgnorePath(rootPath)

      rootDepth = rootPath.split(path.sep).length
      maxDepth = atom.config.get('git-projects.maxDepth')

      fs.traverseTree(rootPath, (->), (_dir) =>
        return false if @shouldIgnorePath(_dir)
        if utils.isRepositorySync(_dir) && recentProjects.map((p) -> p.path).indexOf(_dir) < 0
          project = new Project(_dir)
          unless project.ignored || project.isCurrentProject()
            @projects.push(project)
          return false

        dirDepth = _dir.split(path.sep).length
        return rootDepth + maxDepth > dirDepth
      , ->
        sendCallback()
      )
