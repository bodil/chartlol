spawn_command = "node chartlol.js"

ignore = [ /^node_modules|public$/ ]
zappa_files = []

local_env =
  MONGOLAB_URI: "mongodb://localhost/chartlol"

fs = require "fs"
child_process = require "child_process"
path = require "path"
coffee = require "coffee-script"
events = require "events"

try
  libnotify = require "gnomenotify"
  libnotify.notify_init "runlol"

notify = (title, body) ->
  if libnotify
    n = new libnotify.Notification title, body, "dialog-warning"
    n.set_hint "x-canonical-append", ""
    n.show()

exists = (path) ->
    try
        fs.statSync path
        true
    catch error
        false

isdir = (path) -> (fs.statSync path).isDirectory()
iscoffee = (path) -> not not path.match(/\.coffee$/)
istest = (path) -> not not path.match(/test\.coffee$/)
simplify = (path) -> if path[0...__dirname.length] is __dirname then path[__dirname.length+1..] else path
inres = (item, re_list) -> (true for re in re_list when item.match re).length

scan = (base, list) ->
    list ?= {}
    for file in fs.readdirSync base when file[0] isnt "." and not inres file, ignore
        file = path.join base, file
        if isdir file then scan file, list else list[file] = true if (iscoffee file) and (file isnt __filename)
    list

isnewer = (first, second) ->
    return (fs.statSync first).mtime > (fs.statSync second).mtime

class CompileError
    constructor: (@file, @error) ->

compile = (inpath) ->
    return if (istest inpath) or (not iscoffee inpath)
    outpath = path.join (path.dirname inpath), (path.basename inpath, ".coffee") + ".js"
    if (not exists outpath) or (isnewer inpath, outpath)
        console.log "Compiling #{simplify inpath}"
        try
            js = coffee.compile (fs.readFileSync inpath, "utf8"), bare: not not inres inpath, zappa_files
        catch error
            body = "In file #{simplify inpath}: #{error.message}"
            console.log body
            notify "Compilation failed", body
            throw new CompileError inpath, error
        js = """require('zappa').run(function(){#{js}}, { port: [ parseInt(process.env.PORT, 10) || 5678 ] });""" if inres inpath, zappa_files
        fs.writeFileSync outpath, js

test = (tests, callback) ->
    if tests.length > 0
        child = child_process.spawn "vows", tests, cwd: __dirname
        child.on "exit", (code, signal) ->
            console.log "Test process ended with return code #{code}" if code? and code > 0
            console.log "Test process terminated with signal #{signal}" if signal?
            callback?()
        child.stdout.on "data", (data) ->
            process.stdout.write data.toString("utf8")
        child.stderr.on "data", (data) ->
            process.stdout.write data.toString("utf8")
    else
        callback?()

runtests = (callback) ->
  if process.env.APP_ENV isnt "heroku"
    test (simplify t for own t of scan __dirname when istest t), callback
  else
    callback()

class Watcher extends events.EventEmitter
    constructor: ->
        super()
        @watched = []

    watch: (file) ->
        @watched.push file
        fs.watchFile file, (curr, prev) =>
            @emit "fileChanged", file

    clear: ->
        fs.unwatchFile file for file in @watched
        @watched = []

class Launcher
    constructor: ->
        process.on("SIGINT", @onInterrupt)
        @watcher = new Watcher
        @watcher.on "fileChanged", @onFileChanged

    onInterrupt: =>
        console.log "Exiting on SIGINT"
        if @child?
            @child.removeListener "exit", @onChildExit
            @child.on "exit", (code, signal) =>
                process.exit(0)
            @child.kill("SIGINT")
        else
            process.exit(0)

    onFileChanged: (file) =>
        console.log "File changed:", file
        if (istest file) and (exists file)
            test [simplify file]
        else
            @run()

    compile: ->
        compile script for own script of scan __dirname

    watch: ->
        @watcher.clear()
        @files = (file for own file of scan __dirname)
        @watcher.watch file for file in @files
        if not @watchTimer?
            @watchTimer = setInterval @watchForNew, 1000

    watchForNew: =>
        if (file for own file of scan __dirname).length isnt @files.length
            @run()

    respawn: ->
        if @child?
            @child.removeListener "exit", @onChildExit
            @child.on "exit", (code, signal) =>
                console.log "Restarting child process"
                @spawn()
            @child.kill()
        else
            @spawn()

    spawn: ->
        child_env = {}
        child_env[key] = value for own key, value of local_env
        child_env[key] = value for own key, value of process.env
        spawn_args = spawn_command.split(" ")
        spawn_cmd = spawn_args.shift()
        @child = child_process.spawn spawn_cmd, spawn_args,
          cwd: __dirname
          env: child_env
        @child.on "exit", @onChildExit
        @child.stdout.on "data", (data) =>
            process.stdout.write "CHILD: " + data.toString("utf8")
        @child.stderr.on "data", (data) =>
            process.stdout.write "ERROR: " + data.toString("utf8")

    onChildExit: (code, signal) ->
        console.log "Child process ended with return code #{code}" if code?
        console.log "Child process terminated with signal #{signal}" if signal?
        process.exit(0)

    run: ->
        runtests =>
            try
                @compile()
            catch error
                if error instanceof CompileError
                    console.log "Compilation failed!"
                    @watch()
                    return
                else
                    throw error
            if process.env.APP_ENV isnt "heroku"
                @watch()
            @respawn()

(new Launcher).run()

