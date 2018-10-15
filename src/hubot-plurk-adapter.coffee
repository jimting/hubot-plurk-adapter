try
  {Robot, Adapter, TextMessage, EnterMessage, LeaveMessage, Response} = require 'hubot'
catch
  prequire = require 'parent-require'
  {Robot, Adapter, TextMessage, EnterMessage, LeaveMessage, Response} = prequire 'hubot'
utf8 = require('utf8')
EventEmitter = require('events').EventEmitter
oauth = require("oauth")

cronJob = require("cron").CronJob

class Plurk extends Adapter
  send: (plurk, strings...)->
    console.log("Send: ", plurk)
    strings.forEach (message) =>
      @bot.reply plurk, message
    
  reply: (plurk, strings...)->
    console.log("Reply: ", plurk)
    strings.forEach (message)=>
      @bot.reply plurk, message  
  
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
        console.log("===News===")
        console.log("New message: ",data.content_raw)
      if data.plurk_id? and data.content_raw?
        if data.type == "new_response"
          console.log(data.user[data.user_id].nick_name+" reply : \n")
        if data.type == "new_plurk"
          console.log("New plurk : \n")
        console.log(data.content_raw+"\nPlurk ID: #{data.plurk_id}\n")
        #這裡宣告一下TextMessage,舊方法不能用
        self.receive new TextMessage data.plurk_id, data.content_raw
        #message = new TextMessage "lp123lp123","hello",
        #@self.receive message
        #tmsg = new TextMessage({ plurk_id: data.plurk_id, content_raw: utf8.encode(data.content_raw) }, self.robot.name)
        #self.receive tmsg
    
    
    do bot.acceptFriends
    
    @bot = bot
    

    bot.on 'channel_ready', ()->
      bot.plurk null, self.doPlurk
      console.log("=====CHANNEL READY=====")
   
    bot.on 'rePlurk', (offset)->
      bot.plurk offset, self.doPlurk
      do bot.acceptFriends
    
    self.emit('connected')
    
    
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
        'https://www.plurk.com/OAuth/request_token',
        'https://www.plurk.com/OAuth/access_token',
        @key,
        @secret,
        '1.0',
        'https://www.plurk.com/OAuth/authorize',
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
        if data.comet_server!=null
          #server = data.comet_server.match(/(.+)&offset=0/)[1]
          self.channel = data.comet_server.replace("&offset=0","")
          self.emit('channel_ready')
        else
          console.log("=====CHANNEL FAILED=====")
      else
        console.log(error)
  reply: (plurk, message) ->
    path = "/APP/Responses/responseAdd?plurk_id=#{plurk.user}&content=" + encodeURIComponent(message) + "&qualifier=says"
    @get path, (error, data, response)->
      console.log(data)
    
  acceptFriends: ->
    self = @
    
    self.get "/APP/Alerts/addAllAsFriends", (error, data, response)->
      if error?
        console.log("Error when add friends : ", error)
      if data?
        console.log("===Accept All Friends!===")

  get: (path, callback) ->
    @request "GET", path, null, callback
    
  post: (path, body, callback) ->
    @request "POST", path, body, callback
    
  request: (method, path, body, callback) ->
    console.log("※Request : ","https://#{@domain}#{path}, #{@token}, #{@token_secret}, null")
    
    request = @consumer.get "https://#{@domain}#{path}", @token, @token_secret, null 
    #console.log("request:",request)
    request.on "response", (response) ->
      #console.log("response",response)
      response.on "data", (chunk)->
        parseResponse chunk+'', callback
      response.on "end", (data) ->
        #console.log "End Request: #{path}"
      response.on "error", (data)->
        console.log "Error : " + data
    
    request.end()
    
      #處理資料
    parseResponse = (data, callback) ->
      if data.length > 0
        #先把\處理掉
        data = data.toString()
        data=data.replace(/\\/g,"")
        #用 Try/Catch 避免處理 JSON 出錯導致整個中斷
        try
          callback null, JSON.parse(data)
        catch err
          console.log("Error Parse JSON:" + data + "\n", err)
        #繼續執行
          callback null, data || {}
  
  comet: (server, callback)->
    self = @
    
    console.log("===Searching Plurk...===")
    
    request = @consumer.get server, @token, @token_secret, null
      
    request.on "response", (response) ->
      response.on "data", (chunk)->
        parseResponse(chunk+'', callback)
        
      response.on "end", (data) ->
        #console.log "End Comet: #{server}"
        self.emit 'rePlurk', 0
        
      response.on "error", (data)->
        console.log "Error : " + data
    
    request.end()
    
    parseResponse = (data, callback) ->
      
      if data.length > 0
        try
          #Remove JavaScript Callback (for getUserChannel return's comet)
          #這邊直接把前面的"CometChannel.scriptCallback(" 和結尾的");" 處理掉
          data = data.replace("CometChannel.scriptCallback(","")
          data = data.replace(");","")
          console.log("Data before replace : " + data)
          #data=data.replace(/\\/g,"")
          #直接把html連結處理掉
          data=data.replace(/<[^>]+>/g,"")
          jsonData = ""
          if data?
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
    