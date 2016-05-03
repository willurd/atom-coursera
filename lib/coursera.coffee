{CompositeDisposable} = require 'atom'

FILE_RELATIVE_PATHS_ENABLED = false
EXT_CONFIGS =
  styl: { prefix: 'css', keepExt: false }
  json: { prefix: 'json', keepExt: true }

getProjectRelativeFilePath = (editor, filePath) ->
  paths = atom.project.getPaths()

  for path in paths
    if filePath.indexOf(path) == 0
      return filePath.slice(path.length + 1) # Remove the leading path separator

  return filePath

getFileRelativeFilePath = (editor, filePath) ->
  currentPath = editor.getPath()
  currentDirectory = getDirectory(currentPath)

  if filePath.indexOf(currentDirectory) == 0
    return filePath.replace(currentDirectory, './')
  else
    return getProjectRelativeFilePath(editor, filePath)

getFilePath = (editor, filePath) ->
  if FILE_RELATIVE_PATHS_ENABLED
    return getFileRelativeFilePath(editor, filePath)
  else
    return getProjectRelativeFilePath(editor, filePath)

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
  relativePath = getFilePath(editor, filePath)

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
  if isNlsFile(requirePath)
    return '_t'
  else
    pathParts = requirePath.split('/')
    return removeExtension(pathParts[pathParts.length - 1])

getPlugin = (filePath, requirePath) ->
  prefix = getPrefix filePath

  console.log requirePath, requirePath.split('/')

  if prefix
    return prefix
  else if isNlsFile(requirePath)
    return 'i18n'

isNlsFile = (requirePath) ->
  return requirePath.split('/')[0] == 'nls'

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
    requirePath = getRequirePath editor, filePath
    moduleName = getModuleName requirePath
    plugin = getPlugin filePath, requirePath
    prefix = if plugin != 'css' then "const #{moduleName} = " else ''
    pluginText = if plugin then (plugin + '!') else ''
    requireText = "#{prefix}require('#{pluginText}#{requirePath}');"
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
