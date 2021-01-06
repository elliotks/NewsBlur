app = require('express')()
server = require('http').Server(app)
mongo = require 'mongodb'
log    = require './log.js'

DEV = process.env.NODE_ENV == 'development'
DOCKER = process.env.NODE_ENV == "docker"
MONGODB_SERVER = if DEV then 'localhost' else 'db_mongo'
MONGODB_PORT = parseInt(process.env.MONGODB_PORT or 27017, 10)

log.debug "Starting NewsBlur Favicon server..."
if !DEV and !process.env.NODE_ENV
    log.debug "Specify NODE_ENV=<development,docker,production>"
    return
else if DEV
    log.debug "Running as development server"
else if DOCKER
    log.debug "Running as docker server"
else
    log.debug "Running as production server"
    
if DEV or DOCKER
    url = "mongodb://#{MONGODB_SERVER}:#{MONGODB_PORT}/newsblur"
else
    url = "mongodb://#{MONGODB_SERVER}:#{MONGODB_PORT}/newsblur?replicaSet=nbset&readPreference=secondaryPreferred"

do ->
    try
        client = mongo.MongoClient url, useUnifiedTopology: true
        await client.connect()
    catch err
        log.debug "Error connecting to Mongo: #{err}"
        return

    db = client.db "newsblur"
    collection = db.collection "feed_icons"

    log.debug "Connected to #{db?.serverConfig.s.seedlist[0].host}:#{db?.serverConfig.s.seedlist[0].port}"
    if err
        log.debug " ***> Error connecting: #{err}"

    app.get /\/rss_feeds\/icon\/(\d+)\/?/, (req, res) =>
        feed_id = parseInt(req.params[0], 10)
        etag = req.header('If-None-Match')
        log.debug "Feed: #{feed_id} " + if etag then " / #{etag}" else ""
        collection.findOne _id: feed_id, (err, docs) ->
            if not err and etag and docs and docs?.color == etag
                log.debug "Cached: #{feed_id}, etag: #{etag}/#{docs?.color} " + if err then "(err: #{err})" else ""
                res.sendStatus 304
            else if not err and docs and docs.data
                log.debug "Req: #{feed_id}, etag: #{etag}/#{docs?.color} " + if err then "(err: #{err})" else ""
                res.header 'etag', docs.color
                body = new Buffer(docs.data, 'base64')
                res.set("Content-Type", "image/png")
                res.status(200).send body
            else
                log.debug "Redirect: #{feed_id}, etag: #{etag}/#{docs?.color} " + if err then "(err: #{err})" else ""
                if DEV
                    res.redirect '/media/img/icons/circular/world.png' 
                else
                    res.redirect 'https://www.newsblur.com/media/img/icons/circular/world.png' 

    app.listen 3030
