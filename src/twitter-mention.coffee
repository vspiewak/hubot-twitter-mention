# Description:
#   Continually searches for mentions of word/phrase on twitter
#   and reports new tweets
#
# Dependencies:
#   "twit": "1.1.x"
#
# Configuration:
#   HUBOT_TWITTER_CONSUMER_KEY
#   HUBOT_TWITTER_CONSUMER_SECRET
#   HUBOT_TWITTER_ACCESS_TOKEN_KEY
#   HUBOT_TWITTER_ACCESS_TOKEN_SECRET
#   HUBOT_TWITTER_MENTION_QUERY
#   HUBOT_TWITTER_MENTION_ROOM
#
# Commands:
#   none
#
# Author:
#   vspiewak based on (eric@softwareforgood based on scripts by gkoo and timdorr)
#

TWIT = require "twit"
MENTION_ROOM = process.env.HUBOT_TWITTER_MENTION_ROOM || "#general"
MAX_TWEETS = 50
MESSAGE_FORMAT = process.env.HUBOT_TWITTER_MESSAGE_FORMAT || "markdown"

config =
  consumer_key: process.env.HUBOT_TWITTER_CONSUMER_KEY
  consumer_secret: process.env.HUBOT_TWITTER_CONSUMER_SECRET
  access_token: process.env.HUBOT_TWITTER_ACCESS_TOKEN_KEY
  access_token_secret: process.env.HUBOT_TWITTER_ACCESS_TOKEN_SECRET

getTwit = ->
  unless twit
    twit = new TWIT config

module.exports = (robot) ->
  if robot.adapterName == "slack"
    MESSAGE_FORMAT="slack"

  shareTweet = (tweet) ->
    tweet_url = "https://twitter.com/#{tweet.user.screen_name}/status/#{tweet.id_str}"
    switch MESSAGE_FORMAT
      when "slack"
        message = "Tweet Alert: #{tweet_url}"
        robot.emit 'slack-attachment',
          channel: "#{MENTION_ROOM}"
          content:
            color: "#55acee"
            fallback: "#{message}"
            text: "#{tweet.text}"
            author_name: "#{tweet.user.name} (@#{tweet.user.screen_name})"
            author_link: "http://twitter.com/#{tweet.user.screen_name}"
            title: "#{tweet_url}"
            title_link: "#{tweet_url}"
            thumb_url: "#{tweet.user.profile_image_url}"
            fields: [
                {
                    "title": "Stats",
                    "value": "Retweets: #{tweet.retweet_count} | Like: #{tweet.favorite_count} | Followers: #{tweet.user.followers_count} | Friends: #{tweet.user.friends_count}",
                    "short": false
                }
            ]
      when "markdown"
        message = """
          #{tweet.text}
          *[@#{tweet.user.screen_name}](https://twitter.com/#{tweet.user.screen_name}) (#{tweet.user.name}) on Twitter @ [#{tweet.created_at}](#{tweet_url})*
        """
        robot.messageRoom MENTION_ROOM, message
      when "plaintext"
        message = """
          #{tweet.text}
          - #{tweet_url}
        """
        robot.messageRoom MENTION_ROOM, message

  robot.brain.on 'loaded', =>
    robot.brain.data.last_tweet ||= '1'
    doAutomaticSearch(robot)

  doAutomaticSearch = (robot) ->
    query = process.env.HUBOT_TWITTER_MENTION_QUERY
    since_id = robot.brain.data.last_tweet
    count = MAX_TWEETS

    twit = getTwit()
    twit.get 'search/tweets', {q: query, count: count, since_id: since_id}, (err, data) ->
      if err
        console.log "Error getting tweets: #{err}"
        return
      if data.statuses? and data.statuses.length > 0
        robot.brain.data.last_tweet = data.statuses[0].id_str
        for tweet in data.statuses.reverse()
          shareTweet tweet

    setTimeout (->
      doAutomaticSearch(robot)
    ), 1000 * 60 * 2
