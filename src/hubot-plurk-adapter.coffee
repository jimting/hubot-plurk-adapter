try
  {Robot, Adapter, TextMessage, EnterMessage, LeaveMessage, Response} = require 'hubot'
catch
  prequire = require 'parent-require'
  {Robot, Adapter, TextMessage, EnterMessage, LeaveMessage, Response} = prequire 'hubot'
EventEmitter = require('events').EventEmitter
oauth = require("oauth")

cronJob = require("node-cron")

id = process.env.HUBOT_PLURK_USER_ID
tmpString = ""
cometString = ""
checkingStatus = 0 #0=上一次成功(last time successed)，1=上一次失敗(last time failed)

class Plurk extends Adapter
  send: (says, strings...)->
    strings.forEach (message)=>
      @bot.newPlurk says, message

  reply: (plurk, says, strings...)->
    console.log("Reply: ", plurk)
    console.log("語氣:" ,says)
    strings.forEach (message)=>
      @bot.reply plurk, says, message 

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
      #console.log(data)
      if data.response?
        data.content_raw = data.response.content_raw
        data.user_id = data.response.user_id
        console.log("===News===")
        console.log("New message: ",data.content_raw)
      porn = false
      if data.plurk_id? and data.content_raw?
        if data.type == "new_response"
          console.log(data.user[data.user_id].nick_name+" reply : \n")
          porn = data.plurk.porn
        if data.type == "new_plurk"
          console.log("New plurk : \n")
          porn = data.porn
        console.log(data.content_raw+"\nPlurk ID: #{data.plurk_id}\n")
        
      #把這篇文標為已讀
      bot.get "/APP/Timeline/markAsRead?ids=[#{data.plurk_id}]" , (error, data, response)->
          if error?
            console.log("######Unread Failed QQ######")
      #hubotReceive(data.plurk_id, data.user_id, data.content_raw)
        #這裡宣告一下TextMessage,舊方法不能用
      content_raw = data.content_raw
      if porn
        console.log("這篇是限制級噗");
        content_raw=content_raw+"this_plurk_have_porn_content"
      self.receive new TextMessage(data.plurk_id, content_raw, data.porn), data.plurk_id
        #message = new TextMessage "lp123lp123","hello",
        #@self.receive message
    #給偵測PO文用的ReceiveFunction(噗浪PO文ID,這句話誰回的,內容)
    @hubotReceive = (plurk_id, user_id, content, porn)->
      #提示內容
      console.log("===New Unread Plurk Found===")
      console.log("Plurk_id : #{plurk_id}\nUser_ID : #{user_id}\nContent : #{content}")
      #把這篇文標為已讀
      bot.channelGet "/APP/Timeline/markAsRead?ids=[#{plurk_id}]" , (error, data, response)->
        if error?
          console.log("######Unread Failed QQ######")
      #這裡宣告一下TextMessage,舊方法不能用
      content_raw = content
      if porn
        console.log("這篇是限制級噗");
        content_raw=content_raw+"this_plurk_have_porn_content"
      self.receive new TextMessage(plurk_id, content_raw, porn), plurk_id
      
    do bot.acceptFriends
    do bot.startCheckingChannel
    
    @bot = bot
    

    bot.on 'channel_ready', ()->
      bot.plurk null, self.doPlurk
      console.log("=====CHANNEL READY=====")
   
    bot.on 'rePlurk', (offset)->
      bot.plurk offset, self.doPlurk
      #do bot.acceptFriends
    
    bot.on 'channelReceive', (plurk_id, user_id, content, porn)->
      self.hubotReceive plurk_id, user_id, content, porn
    
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
          console.log(data.comet_server)
          self.channel = data.comet_server.replace("&offset=0","")+"&replurkers_detail=false&favorers_detail=false&limited_detail=false"
          self.emit('channel_ready')
        else
          console.log("=====CHANNEL FAILED=====")
      else
        console.log(error)

  reply: (plurk, says, message) ->
    path = "/APP/Responses/responseAdd?plurk_id=#{plurk.user}&content=" + encodeURIComponent(message) + "&qualifier="+says
    @get path, (error, data, response)->
      #console.log(data)
      
  newPlurk: (says, message) ->
    console.log("newPlurk: ", message)
    console.log("語氣:" ,says)
    path = "/APP/Timeline/plurkAdd?lang=en&qualifier="+says+"&porn=0&content=" + encodeURIComponent(message)
    @get path, (error, data, response)->
      #console.log(data)
   
  acceptFriends: ->
    self = @
    cronJob.schedule "* * * * *", () ->
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
    #console.log("※Request : ","https://#{@domain}#{path}, #{@token}, #{@token_secret}, null")
    
    request = @consumer.get "https://#{@domain}#{path}", @token, @token_secret, null 
    #console.log("request:",request)
    request.on "response", (response) ->
      #console.log("response",response)
      response.on "data", (chunk)->
        parseResponse chunk+'', callback
      response.on "end", (data) ->
        #console.log "End Request: #{path}"
      response.on "error", (data)->
        #console.log "Error : " + data
    
    request.end()
    
      #處理資料
    parseResponse = (data, callback) ->
      if data.length > 0
        #把html tag處理掉
        #data=data.replace(/<[^>]+>/g,"")
        #先把\處理掉
        data = data.toString()
        data=data.replace(/\\/g,"")
        if self.isJsonString(tmpString2) 
          callback null, JSON.parse(tmpString2) || {}
          tmpString2 = ""
        
        #用 Try/Catch 避免處理 JSON 出錯導致整個中斷
        try
          callback null, JSON.parse(data)
          tmpString2 = ""
        catch err
          #console.log("Error Parse JSON:" + data + "\n", err)
          tmpString2 += data
        #繼續執行
          callback null, data || {}

  channelGet: (path, callback) ->
    @channelRequest "GET", path, null, callback
    
  channelRequest: (method, path, body, callback) ->
    #console.log("※Request : ","https://#{@domain}#{path}, #{@token}, #{@token_secret}, null")
    
    request = @consumer.get "https://#{@domain}#{path}", @token, @token_secret, null 
    #console.log("request:",request)
    request.on "response", (response) ->
      #console.log("response",response)
      response.on "data", (chunk)->
        parseResponse chunk+'', callback
      response.on "end", (data) ->
        #console.log "End Request: #{path}"
      response.on "error", (data)->
        #console.log "Error : " + data
    
    request.end()
    
      #處理資料
    parseResponse = (data, callback) ->
      if data.length > 0
        #把html tag處理掉
        data=data.replace(/<[^>]+>/g,"")
        #先把\處理掉
        data = data.toString()
        data=data.replace(/\\\//g,"/")
        
        if self.isJsonString(tmpString) 
          callback null, JSON.parse(tmpString) || {}
          tmpString = ""
        else
          #console.log("不是JSON")
        
        #用 Try/Catch 避免處理 JSON 出錯導致整個中斷
        try
          callback null, JSON.parse(data)
        catch err
          #console.log("Error Parse JSON:" + data + "\n", err)
          tmpString += data
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
        #Remove JavaScript Callback (for getUserChannel return's comet)
        #這邊直接把前面的"CometChannel.scriptCallback(" 和結尾的");" 處理掉
        #console.log("Data before replace : " + data)
        data = data.replace("CometChannel.scriptCallback(","")
        data = data.replace(");","")
        data=data.replace(/\\\//g,"/")
        #把html tag處理掉
        data=data.replace(/<[^>]+>/g,"")
          
        if self.isJsonString(cometString)
          console.log "[Comet]JSON: " + data
          callback null, 0, JSON.parse(cometString)
          cometString = ""
        
        if self.isJsonString(data)
          # Skip it on production
          #console.log "[Comet]JSON: " + data
          callback null, 0, JSON.parse(data).data
          cometString = ""
        else
          cometString += data
          #console.log "[Comet]Error Parse JSON: " + data, err
          callback null, 0, data || { }
  checkChannel: (callback)->
      self = @
    #每秒檢查一次未讀的訊息，看看是否有漏回的
    #cronJob.schedule "* * * * * *", () ->
      self.channelGet "/APP/Timeline/getUnreadPlurks?offset=0&limit=1", (error, data, response)->
        #開始檢查是否有漏掉未回覆的未讀訊息
        #這邊的json格式:{plurk_users:{id},plurks:[]}
        #針對每個新plurk去檢查(因為不能太長 每幾秒檢查5個訊息/這邊可以自己設定啦，如果不是很多人用就可以檢查少一點XD)
        #如果有未讀
        #console.log(data)
        try
          #if checkingStatus == 1#如果上一次是失敗，則進入失敗處理迴圈
            #data = tmpString + data #把上次失敗的內容和這次串在一起 再試一次
          for plurk in data.plurks
            porn = plurk.porn
            #response_count=所有人回應的次數
            if plurk.responded == 0 #如果自己沒有回覆過
              #responded=自己回應的次數
              #如果responded = key_count則設為已讀跳過
              #還不知道怎麼處理比較好 所以
              #直接把最後回覆的內容丟給hubot
              if plurk.user_id!=id#如果不是自己的PO文就丟給hubot
                #把PO文內容丟給hubot
                self.emit "channelReceive",plurk.plurk_id, plurk.user_id, plurk.content_raw, porn
              else#是自己的就標已讀
                self.channelGet "/APP/Timeline/markAsRead?ids=[#{plurk.plurk_id}]" , (error, data, response)->
                  if error?
                    console.log("######Unread Failed QQ######")
            self.channelGet "/APP/Responses/getById?plurk_id=#{plurk.plurk_id}", (error2, data2, response2)->
              #console.log(data2.responses[data2.response_count-1].content_raw)
              if data2.response_count>0
                #console.log("Plurk_id : #{data2.responses[data2.response_count-1].plurk_id}\nUser_ID : #{data2.responses[data2.response_count-1].user_id}\nContent : #{data2.responses[data2.response_count-1].content}")
                if data2.responses[data2.response_count-1].user_id!=id#如果不是自己的回覆就送給hubot
                  self.emit "channelReceive",data2.responses[data2.response_count-1].plurk_id, data2.responses[data2.response_count-1].user_id, data2.responses[data2.response_count-1].content_raw, porn
                else#是自己的就標已讀
                  self.channelGet "/APP/Timeline/markAsRead?ids=[#{data2.responses[data2.response_count-1].plurk_id}]" , (error, data, response)->
                    if error?
                      console.log("######Unread Failed QQ######")
          #checkingStatus = 0 #成功了！
          #tmpString = "" #清空暫存資料
        catch err
          #do nothing
          #console.log("[ERROR] : " + tmpString)
          checkingStatus = 1 #失敗了QQ
          #tmpString += data #保留data

  startCheckingChannel: (callback)->
    #這只是用來設定checkChannel的定時執行而已 我設定五秒跑一次
    setInterval () ->
        console.log("=====CheckingChannel=====")
        self.checkChannel()
    , 5000
  isJsonString : (str) ->
    try 
        JSON.parse(str)
    catch error
        return false
    return true