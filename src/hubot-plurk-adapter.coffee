Robot = require("hubot").robot()
Adapter = require("hubto").adapter()

EventEmitter = require("events").EventEmitter

oauth = require("oauth")
cronJob = require("cron").CronJob

class Plurk exntends Adapter
  send: (plurk_id, strings…) ->
  
  reply: (plurk_id, strings…) ->
  
  run: ->

class PlurkStreaming exnteds EventEmitter
  consuctor: (options) ->
    super()
    if options.key? and options.secret? and options.token? and options.token_secret?
      @key = options.key
      @secret = options.secret
      @token = options.token
      @token_secret = options.token_secret
      #建立 OAuth 連接
      @consumer = new oauth.OAuth(
      "http://www.plurk.com/OAuth/request_token",
      "http://www.plurk.com/OAuth/access_token",
      @key,
      @secret,
      "1.0",
      "http://www.plurk.com/OAuth/authorize".
      "HMAC-SHA1"
      )
      @domain = "www.plurk.com"
      #初始化取得Comet網址
      do @getChannel
    else
      throw new Error("參數不足，需要 Key, Secret, Token, Token Secret")
  plurk: (callback) ->
    #觀察河道
	#其實官方文件是要設定 offset 的，不過目前沒有想到設定的方法，以及即使沒有設定也能正常運作
    @comet @channel, (error, data) ->
      if data?
        #將一筆筆的資料一一遞送
        for plurk in data
          callback plurk
  getChannel: ->
    #取得 Comet 網址
	self = @
  
    @get "/APP/Realtime/getUserChannel", (error, data) ->
      if !error
        #檢查是否有 comet server
        if data.comet_server?
          self.channel = data.comet_server
          #如果沒有 Channel Ready 就嘗試連接會失敗
          self.emit('channel_ready')
  reply: (plurk_id, message) ->
    #回噗
	#設定回噗的參數
    path = "/APP/Responses/responseAdd?plurk_id=#{plurk_id}&content=" + encodeURIComponent(message) + "&qualifier=says"
    @get path, (error, data)->
    #啥都不做
  acceptFriends: ->
    #接受好友
	self = @
    #用 Cron Module 的時候到了！
    cronJob "0 0 * * * *", () ->
      self.get "/APP/Alerts/addAllAsFriends", (error, data) ->
        console.log("接受所有好友邀請：", data)
  get: (path, callback) ->
    #GET 請求
	@request("GET", path, null, callback)
  post: (path, body, callback)->
    #POST 請求（其實是裝飾）
	@request("POST", path, body, callback)
  request: (method, path, body, callback)->
    #主要的 OAuth 請求
	#記錄一下這次的 Request
    console.log("http://#{@domain}#{path}")
  
    # Callback 這邊先不丟進去，要用另一種方式處理
    request = @consumer.get("http://#{@domain}#{path}", @token, @token_secret, null)
  
    request.on "response", (res) ->
      res.on "data", (chunk) ->
        parseResponse(chunk+'', callback)
      res.on "end", (data) ->
        console.log "End Request: #{path}"
      res.on "error", (data) ->
        console.log "Error: " + data
      
    request.end()
  
    #處理資料
    parseResponse = (data, callback) ->
      if data.length > 0
        #用 Try/Catch 避免處理 JSON 出錯導致整個中斷
        try
          callback null, JSON.parse(data)
        catch err
          console.log("Error Parse JSON:" + data, err)
          #繼續執行
          callback null, data || {}
  comet: (server, callback)->
    #噗浪的 Comet 傳回是 JavaScript Callback 要另外處理後才會變成 JSON
	#在 Callback 裡面會找不到自身，所以設定區域變數
    self = @

    #記錄一下這次的 Request
    console.log("[Comet] #{server}")
  
    # Callback 這邊先不丟進去，要用另一種方式處理
    request = @consumer.get("http://#{@domain}#{path}", @token, @token_secret, null)
  
    request.on "response", (res) ->
      res.on "data", (chunk) ->
        parseResponse(chunk+'', callback)
      res.on "end", (data) ->
        console.log "End Request: #{path}"
      #請求結束，發出事件通知可以進行下一次請求
        self.emit "nextPlurk"
      res.on "error", (data) ->
        console.log "Error: " + data
      
    request.end()    
  
    #處理資料
    parseResponse = (data, callback) ->
      if data.length > 0
        #用 try/catch 避免失敗中斷
        try
          #去掉 JavaScript 的 Callback
          data = data.match(/CometChannel.scriptCallback\((.+)\);\s*/)
          jsonData = ""
        
          if data?
            jsonData = JSON.parse(data[1])
          else
            #如果沒有任何 Match 嘗試直接 parse
            jsonData = JSON.parse(data)
        catch err
          console.log("[Comet] Error:", data, err)
        
        #用 Try/Catch 避免處理 JSON 出錯導致整個中斷
        try
          #只傳入 json 的 data 部分
          callback null, jsonData.data
        catch err
          console.log("[Comet]Error Parse JSON:" + data, err)
          #繼續執行
          callback null, data || {}