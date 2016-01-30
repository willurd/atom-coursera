{CompositeDisposable} = require 'atom'

EXT_CONFIGS =
  styl: { prefix: 'css', keepExt: false }
  json: { prefix: 'json', keepExt: true }

getRelativeFilePath = (editor, filePath) ->
  currentPath = editor.getPath()
  currentDirectory = getDirectory(currentPath)

  if filePath.indexOf(currentDirectory) == 0
    return filePath.replace(currentDirectory, './')
  else
    paths = atom.project.getPaths()

    for path in paths
      if filePath.indexOf(path) == 0
        return filePath.slice(path.length + 1) # Remove the leading path separator

  return filePath

getDirectory = (filePath) ->
  pathParts = filePath.split('/')
  return pathParts.slice(0, pathParts.length - 1).join('/') + '/'

removeExtension = (filePath) ->
  index = filePath.lastIndexOf('.')
  return filePath.slice(0, index) if index != -1
  return filePath

getRequirePath = (editor, filePath) ->
  ext = getExtension(filePath)
  extConfig = EXT_CONFIGS[ext]
  relativePath = getRelativeFilePath(editor, filePath)

  if extConfig?.keepExt
    return relativePath

  return removeExtension(relativePath)

getExtension = (filePath) ->
  pathParts = filePath.split('.')
  return pathParts[pathParts.length - 1]

getPrefix = (filePath) ->
  ext = getExtension(filePath)
  return EXT_CONFIGS[ext]?.prefix

getModuleName = (requirePath) ->
  pathParts = requirePath.split('/')
  return removeExtension(pathParts[pathParts.length - 1])

module.exports = Coursera =
  subscriptions: null

  activate: (state) ->
    @active = true

    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace', 'coursera:add-require-statement': =>
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

  addRequireStatement: ->
    return unless atom.workspace.getActiveTextEditor()?
    @createProjectView().toggle()

  fileChosen: (filePath) ->
    return unless editor = atom.workspace.getActiveTextEditor()
    prefix = getPrefix filePath
    requirePath = getRequirePath editor, filePath
    moduleName = getModuleName requirePath
    plugin = if prefix then (prefix + '!') else ''
    requireText = "const #{moduleName} = require('#{plugin}#{requirePath}');"
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
