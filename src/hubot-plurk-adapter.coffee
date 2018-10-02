try
  {Adapter,TextMessage} = require 'hubot'
catch
  prequire = require 'parent-require'
  {Adapter, TextMessage} = prequire 'hubot'

EventEmitter = require('events').EventEmitter
oauth = require("oauth")

cronJob = require("cron").CronJob

class Plurk extends Adapter
  send: (plurk_id, strings...)->
    console.log("Send: ", plurk_id)
    strings.forEach (message) =>
      @bot.reply plurk_id, message
    
  reply: (plurk_id, strings...)->
    console.log("Reply: ", plurk_id)
    strings.forEach (message)=>
      @bot.reply plurk_id, message  
  
  run: ->
    self = @
    options =
      key : process.env.HUBOT_PLURK_KEY
      secret : process.env.HUBOT_PLURK_SECRET
      token : process.env.HUBOT_PLURK_TOKEN
      tokensecret : process.env.HUBOT_PLURK_TOKEN_SECRET
    
    bot = new PlurkStreaming(options)
    
    r = @robot.constructor
    
    @doPlurk = (data)->
      if data.response?
        data.content_raw = data.response.content_raw
        data.user_id = data.response.user_id
        console.log("New message: ",data.content_raw)
      if data.plurk_id? and data.content_raw? and data.user_id.toString() isnt "6993533"
        console.log("Receive #{data.content_raw} Plurk ID: #{data.plurk_id}")
        self.receive new r.TextMessage data.plurk_id, data.content_raw
    
    bot.on 'channel_ready', ()->
      bot.plurk null, self.doPlurk
      console.log("channel_ready")
   
    bot.on 'rePlurk', (offset)->
      bot.plurk offset, self.doPlurk
      console.log("get new plurk!")
      
    do bot.acceptFriends
    
    @bot = bot
    
    
exports.use = (robot) ->
  new Plurk robot

class PlurkStreaming extends EventEmitter
  self = @
  
  constructor: (options) ->
    super()
    if options.token? and options.secret? and options.key? and options.tokensecret?
      @token = options.token
      @secret = options.secret
      @key = options.key
      @token_secret = options.tokensecret
      @domain = "www.plurk.com"
      console.log("OAuth_Action:",@token,@secret,@key,@token_secret)
      @consumer = new oauth.OAuth(
        'http://www.plurk.com/OAuth/request_token',
        'http://www.plurk.com/OAuth/access_token',
        @key,
        @secret,
        '1.0',
        'http://www.plurk.com/OAuth/authorize',
        'HMAC-SHA1'
      )
      do @getChannel
    else
      throw new Error("Not enough params,I need a token, a secret, a key, a secret token")
  
  plurk: (offset, callback) ->
   
   self = @
   
   if offset?
     path = @channel + '&offset=' + offset
   else
     path = @channel + '&offset=0'
   
   @comet path, (error, offset, data)->
     if data?
      for plurk in data
        callback plurk
    
  getChannel: ()->
    self = @
    @get "/APP/Realtime/getUserChannel", (error, data, response) ->
      if !error
        if data.comet_server?
          server = data.comet_server.match(/(.+)&offset=0/)[1]
          self.channel = server
          self.emit('channel_ready')
          console.log("成功送出getChannel:",data)
      else
        console.log(error)
  reply: (plurk_id, message) ->
    path = "/APP/Responses/responseAdd?plurk_id=#{plurk_id}&content=" + encodeURIComponent(message) + "&qualifier=says"
    @get path, (error, data, response)->
      console.log(data)
    
  acceptFriends: ->
    
    self = @
    
    cronJob "0 0 * * * *", ()->
      self.get "/APP/Alerts/addAllAsFriends", (error, data, response)->
        console.log("Error:", error)
        console.log("接受所有好友邀請:", data)
        console.log("Response:", response)

  get: (path, callback) ->
    @request "GET", path, null, callback
    
  post: (path, body, callback) ->
    @request "POST", path, body, callback
    
  request: (method, path, body, callback) ->
    console.log("http://#{@domain}#{path}, #{@token}, #{@token_secret}, null")
    
    request = @consumer.get("http://#{@domain}#{path}", @token, @token_secret, null)
    console.log("request:",request)
    request.on "response", (response) ->
      response.on "data", (chunk)->
        parseResponse(chunk+'', callback)
        console.log("Chunk:",chunk)
      response.on "end", (data) ->
        console.log "End Request: #{path}"
      response.on "error", (data)->
        console.log "Error : " + data
    
    request.end()
    
    parseResponse = (data, callback) ->
      if data.length > 0
        try
          #Skip it on production
          console.log "JSON: " + data
          callback null, JSON.parse(data)
        catch err
          console.log "Error Parse JSON: " + data, err
          callback null, data || { }
  
  comet: (server, callback)->
    self = @
    
    console.log("Coment:","#{server}, #{@token}, #{@token_secret}, null")
    
    request = @consumer.get server, @token, @token_secret, null
      
    request.on "response", (response) ->
      response.on "data", (chunk)->
        parseResponse(chunk+'', callback)
        
      response.on "end", (data) ->
        console.log "End Comet: #{server}"
        self.emit 'rePlurk', 0
        
      response.on "error", (data)->
        console.log "Error : " + data
    
    request.end()
    
    parseResponse = (data, callback) ->
      
      if data.length > 0
        try
          #Remove JavaScript Callback (for getUserChannel return's comet)
          data = data.match(/CometChannel.scriptCallback\((.+)\);\s*/)
          jsonData = ""
          if data?
            jsonData = JSON.parse(data[1])
          else
            jsonData = JSON.parse(data)
        catch err
          console.log("[Comet]Error: ", data, err)
          
        try
          # Skip it on production
          #console.log "[Comet]JSON: " + data
          callback null, 0, jsonData.data
        catch err
          console.log "[Comet]Error Parse JSON: " + data, err
          callback null, 0, data || { }
    