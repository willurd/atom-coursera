{CompositeDisposable} = require 'atom'

getRelativeFilePath = (filePath) ->
  paths = atom.project.getPaths()

  for path in paths
    if filePath.indexOf(path) == 0
      return filePath.slice(path.length + 1) # Remove the leading path separator

  return filePath

getRequirePath = (filePath) ->
  relativePath = getRelativeFilePath filePath
  index = relativePath.lastIndexOf('.')
  return relativePath.slice(0, index)

getModuleName = (requirePath) ->
  pathParts = requirePath.split('/')
  return pathParts[pathParts.length - 1]

module.exports = CourseraRequires =
  subscriptions: null
  courseraRequiresView: null

  activate: (state) ->
    @active = true

    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace', 'coursera-requires:add-require-statement': =>
      @addRequireStatement()

    process.nextTick => @startLoadPathsTask()

  deactivate: ->
    @subscriptions.dispose()

    if @projectView?
      @projectView.destroy()
      @projectView = null
    @projectPaths = null
    @stopLoadPathsTask()
    @active = false

  serialize: ->

  consumeAutoreload: (reloader) ->
    reloader(pkg:"coursera-requires", files:["package.json"], folders:["lib/"])

  addRequireStatement: ->
    return unless atom.workspace.getActiveTextEditor()?
    @createProjectView().toggle()

  fileChosen: (filePath) ->
    return unless editor = atom.workspace.getActiveTextEditor()
    requirePath = getRequirePath filePath
    moduleName = getModuleName requirePath
    requireText = "const #{moduleName} = require('#{requirePath}');"
    editor.insertText requireText

  createProjectView: ->
    @stopLoadPathsTask()

    unless @projectView?
      ProjectView  = require './project-view'
      @projectView = new ProjectView(@projectPaths)
      @subscriptions.add @projectView.on 'file-chosen', @fileChosen
      @projectPaths = null
    @projectView

  startLoadPathsTask: ->
    @stopLoadPathsTask()

    return unless @active
    return if atom.project.getPaths().length is 0

    PathLoader = require './path-loader'
    @loadPathsTask = PathLoader.startTask (@projectPaths) =>
    @projectPathsSubscription = atom.project.onDidChangePaths =>
      @projectPaths = null
      @stopLoadPathsTask()

  stopLoadPathsTask: ->
    @projectPathsSubscription?.dispose()
    @projectPathsSubscription = null
    @loadPathsTask?.terminate()
    @loadPathsTask = null
