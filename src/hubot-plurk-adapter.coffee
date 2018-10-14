try
<<<<<<< HEAD
  {Robot, Adapter, TextMessage, EnterMessage, LeaveMessage, Response} = require 'hubot'
catch
  prequire = require 'parent-require'
  {Robot, Adapter, TextMessage, EnterMessage, LeaveMessage, Response} = prequire 'hubot'
=======
  {Adapter,TextMessage} = require 'hubot'
catch
  prequire = require 'parent-require'
  {Adapter, TextMessage} = prequire 'hubot'
>>>>>>> 045c9e0f33bcaf4ae5787af163a04815724e4277

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
<<<<<<< HEAD
    @doPlurk = (data)->
      console.log("---送出河道請求---")
=======
    
    @doPlurk = (data)->
>>>>>>> 045c9e0f33bcaf4ae5787af163a04815724e4277
      if data.response?
        data.content_raw = data.response.content_raw
        data.user_id = data.response.user_id
        console.log("New message: ",data.content_raw)
      if data.plurk_id? and data.content_raw? and data.user_id.toString() isnt "6993533"
        console.log("Receive #{data.content_raw} Plurk ID: #{data.plurk_id}")
        self.receive new r.TextMessage data.plurk_id, data.content_raw
    
<<<<<<< HEAD
    
    do bot.acceptFriends
    
    @bot = bot

    

    bot.on 'channel_ready', ()->
      bot.plurk null, self.doPlurk
      console.log("channel_ready")
   
    bot.on 'rePlurk', (offset)->
      bot.plurk offset, self.doPlurk
      console.log("get new plurk!")
    
    self.emit('connected')
    
    
exports.use = (robot) ->
  new Plurk robot

=======
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

>>>>>>> 045c9e0f33bcaf4ae5787af163a04815724e4277
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
<<<<<<< HEAD
        'https://www.plurk.com/OAuth/request_token',
        'https://www.plurk.com/OAuth/access_token',
        @key,
        @secret,
        '1.0',
        'https://www.plurk.com/OAuth/authorize',
=======
        'http://www.plurk.com/OAuth/request_token',
        'http://www.plurk.com/OAuth/access_token',
        @key,
        @secret,
        '1.0',
        'http://www.plurk.com/OAuth/authorize',
>>>>>>> 045c9e0f33bcaf4ae5787af163a04815724e4277
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
<<<<<<< HEAD
   console.log("進到plurk了")
=======
   
>>>>>>> 045c9e0f33bcaf4ae5787af163a04815724e4277
   @comet path, (error, offset, data)->
     if data?
      for plurk in data
        callback plurk
    
  getChannel: ()->
    self = @
    @get "/APP/Realtime/getUserChannel", (error, data, response) ->
      if !error
<<<<<<< HEAD
        console.log("data:",data)
        console.log("checking:",data.comet_server.replace("&offset=0",""))
        if data.comet_server!=null
          #server = data.comet_server.match(/(.+)&offset=0/)[1]
          self.channel = data.comet_server.replace("&offset=0","")
          self.emit('channel_ready')
        else
          console.log("channel failed!")
=======
        if data.comet_server?
          server = data.comet_server.match(/(.+)&offset=0/)[1]
          self.channel = server
          self.emit('channel_ready')
          console.log("成功送出getChannel:",data)
>>>>>>> 045c9e0f33bcaf4ae5787af163a04815724e4277
      else
        console.log(error)
  reply: (plurk_id, message) ->
    path = "/APP/Responses/responseAdd?plurk_id=#{plurk_id}&content=" + encodeURIComponent(message) + "&qualifier=says"
    @get path, (error, data, response)->
      console.log(data)
    
  acceptFriends: ->
<<<<<<< HEAD
=======
    
>>>>>>> 045c9e0f33bcaf4ae5787af163a04815724e4277
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
<<<<<<< HEAD
    console.log("※Request : ","https://#{@domain}#{path}, #{@token}, #{@token_secret}, null")
    
    request = @consumer.get "https://#{@domain}#{path}", @token, @token_secret, null 
    #console.log("request:",request)
    request.on "response", (response) ->
      #console.log("response",response)
      response.on "data", (chunk)->
        parseResponse chunk+'', callback
=======
    console.log("http://#{@domain}#{path}, #{@token}, #{@token_secret}, null")
    
    request = @consumer.get("http://#{@domain}#{path}", @token, @token_secret, null)
    console.log("request:",request)
    request.on "response", (response) ->
      response.on "data", (chunk)->
        parseResponse(chunk+'', callback)
        console.log("Chunk:",chunk)
>>>>>>> 045c9e0f33bcaf4ae5787af163a04815724e4277
      response.on "end", (data) ->
        console.log "End Request: #{path}"
      response.on "error", (data)->
        console.log "Error : " + data
    
    request.end()
    
<<<<<<< HEAD
      #處理資料
    parseResponse = (data, callback) ->
      if data.length > 0
        #先把\處理掉
        data = data.toString()
        data=data.replace(/\\/g,"")
        #用 Try/Catch 避免處理 JSON 出錯導致整個中斷
=======
    parseResponse = (data, callback) ->
      if data.length > 0
>>>>>>> 045c9e0f33bcaf4ae5787af163a04815724e4277
        try
          #Skip it on production
          console.log "JSON: " + data
          callback null, JSON.parse(data)
        catch err
<<<<<<< HEAD
          console.log("Error Parse JSON:" + data + "\n", err)
        #繼續執行
          callback null, data || {}
=======
          console.log "Error Parse JSON: " + data, err
          callback null, data || { }
>>>>>>> 045c9e0f33bcaf4ae5787af163a04815724e4277
  
  comet: (server, callback)->
    self = @
    
<<<<<<< HEAD
    console.log("進入Coment:","#{server}, #{@token}, #{@token_secret}, null")
=======
    console.log("Coment:","#{server}, #{@token}, #{@token_secret}, null")
>>>>>>> 045c9e0f33bcaf4ae5787af163a04815724e4277
    
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
<<<<<<< HEAD
          console.log("*data:"+data)
=======
>>>>>>> 045c9e0f33bcaf4ae5787af163a04815724e4277
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
    