Type 4.0.0

# Require something

run this first

	npm install parent-require,events,oauth,node-cron

# hubot-plurk-adapter

Hubot's Adapter for Plurk

# Important

If your node verb is under than 9, then it will failed!(IDK why)

# Environment Variable

You need to set these EV:

* HUBOT_PLURK_KEY
* HUBOT_PLURK_SECRET
* HUBOT_PLURK_TOKEN
* HUBOT_PLURK_TOKEN_SECRET
* HUBOT_PLURK_USER_ID

You can get your HUBOT_PLURK_KEY, HUBOT_PLURK_SECRET, HUBOT_PLURK_TOKEN, HUBOT_PLURK_TOKEN_SECRET on Plurk APP page.

Here: https://www.plurk.com/PlurkApp/

HUBOT_PLURK_USER_ID is your account ID.

You can get it on Plurk APP's /APP/Users/me API.

# Install From NPM

After setting up the hubot, just install this adapter from npm by :

	npm install hubot-plurk-adapter

and use it by :

	bin\hubot -a plurk-adapter

# How to use ?

Hubot's message function have 2 types, "send" and "reply".

Here, 'send' means create a new plurk. 

You can set a schedule or something like it to auto the plurk.

Just like below :

```
module.exports = function(robot) {
  #maybe some schedule code
  robot.send("loves","Hello") //make a new plurk with qualifier "loves" and content "Hello"
}
```
	
And 'reply' means create a response.

You can use hubot's hear function to catch keywords and reply the plurk.

Just like below :

```
module.exports = function(robot) {
  robot.hear(/Hello/, function(response) { //If catch the word "Hello"(include plurk and response)
    response.reply("wants","Hi"); //reply the plurk or response "Hi" with qualifier "wants"
  });
}
```

By the way, all the qualifier you can use can be found on this link : https://www.plurk.com/API


# Reference

弦而時習之 - 製作一個 Hubot 的噗浪 Adapter - 2012/03/18 (Not work now)

https://blog.frost.tw/posts/2012/03/18/create-a-hubot-plurk-adapter/
