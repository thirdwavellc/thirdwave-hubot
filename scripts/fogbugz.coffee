# Description:
#   FogBugz hubot helper
#
# Dependencies:
#   "xml2js": "0.1.14"
#
# Configuration:
#   HUBOT_FOGBUGZ_HOST
#   HUBOT_FOGBUGZ_TOKEN
#
# Commands:
#   bugz help - display FogBugz commands
#   bugz search <string> - searches cases
#   bugz case <case number> - returns helpful information about a case
#   bugz register <username> <password> - registers your api token
#   bugz my token - displays your api token
#   bugz my cases - displays your cases
#   bugz start <case number> - start timer for the case
#   bugz stop <case number - stop timer for the case
#   bugz my timer - displays your current timer (if running)
#
# Notes:
#   
#   curl 'https://HUBOT_FOGBUGZ_HOST/api.asp' -F'cmd=logon' # -F'email=EMAIL' -F'password=PASSWORD'
#   and copy the data inside the CDATA[...] block.
#
#   Tokens only expire if you explicitly log them out, so you should be able to
#   use this token forever without problems.
#
# Author:
#   dstrelau

Parser = require('xml2js').Parser
env = process.env
util = require 'util'

module.exports = (robot) ->
  if env.HUBOT_FOGBUGZ_HOST

    bugzURL = "http://#{env.HUBOT_FOGBUGZ_HOST}/api.asp"

    robot.hear /bugz help/i, (msg) ->
      msg.send """
                bugz help - display FogBugz commands
                bugz search <string> - searches cases
                bugz case <case number> - returns helpful information about a case
                bugz register <username> <password> - registers your api token
                bugz my token - displays your api token
                bugz my cases - displays your cases
                bugz start <case number> - start timer for the case
                bugz stop <case number - stop timer for the case
                bugz my timer = displays your current timer (if running)
               """
               
    robot.hear /bugz case (\d+)/i, (msg) ->
      msg.http(bugzURL)
        .query
          cmd: "search"
          token: msg.message.user.bugzToken
          q: msg.match[1]
          cols: "ixBug,sTitle,sStatus,sProject,sArea,sPersonAssignedTo,ixPriority,sPriority,sLatestTextSummary"
        .get() (err, res, body) ->
          (new Parser()).parseString body, (err,json) ->
            bug = json.cases?.case
            if bug
              details = [
                "FogBugz #{bug.ixBug}: #{bug.sTitle}"
                "  Priority: #{bug.ixPriority} - #{bug.sPriority}"
                "  Project: #{bug.sProject}"
                "  Status: #{bug.sStatus}"
                "  Assigned To: #{bug.sPersonAssignedTo}"
                "  Latest Comment: #{bug.sLatestTextSummary}"
              ]
              msg.send details.join("\n")
    
    robot.hear /bugz search (.*)/i, (msg) ->
      msg.send "Searching for #{msg.match[1]}..."
      msg.http(bugzURL)
        .query
          cmd: "search"
          token: msg.message.user.bugzToken
          q: msg.match[1]
          cols: "ixBug,sTitle"
          max: "10"
        .get() (err, res, body) ->
          (new Parser()).parseString body, (err,json) ->
            cases = json.cases?.case
            if cases[1]
              for bug in cases
                msg.send "FogBugz #{bug.ixBug}: #{bug.sTitle}"
            else
              msg.send "FogBugz #{cases.ixBug}: #{cases.sTitle}"

    robot.hear /bugz register (.*) (.*)/i, (msg) ->
      msg.send "Registering #{msg.message.user.name}..."
      msg.http(bugzURL)
        .query
          cmd: "logon"
          email: msg.match[1]
          password: msg.match[2]
        .get() (err, res, body) ->
          (new Parser()).parseString body, (err,json) ->
            msg.message.user.bugzToken = json.token
            msg.send "Okay, #{msg.message.user.name}'s token is #{msg.message.user.bugzToken}"

    robot.hear /bugz my token/i, (msg) ->
      msg.send "Your token is: #{msg.message.user.bugzToken}"

    robot.hear /bugz my cases/i, (msg) ->
      msg.http(bugzURL)
        .query
          cmd: "setCurrentFilter"
          sFilter: "ez"
          token: msg.message.user.bugzToken
        .get() (err, res, body) ->
          msg.http(bugzURL)
            .query
              cmd: "search"
              token: msg.message.user.bugzToken
              cols: "ixBug,sTitle"
              max: "10"
            .get() (err, res, body) ->
              (new Parser()).parseString body, (err,json) ->
                cases = json.cases?.case
                if cases[1]
                  for bug in cases
                    msg.send "FogBugz #{bug.ixBug}: #{bug.sTitle}"
                else
                  msg.send "FogBugz #{cases.ixBug}: #{cases.sTitle}"

    robot.hear /bugz start (\d+)/i, (msg) ->
      msg.http(bugzURL)
        .query
          cmd: "startWork"
          ixBug: msg.match[1]
          token: msg.message.user.bugzToken
        .get() (err, res, body) ->
          msg.message.user.workingon = "FogBugz #{msg.match[1]}"
          msg.send "Okay, I started the timer for FogBugz #{msg.match[1]}"

    robot.hear /bugz stop (\d+)/i, (msg) ->
      msg.http(bugzURL)
        .query
          cmd: "stopWork"
          ixBug: msg.match[1]
          token: msg.message.user.bugzToken
        .get() (err, res, body) ->
          msg.message.user.workingon = undefined
          msg.send "Okay, I stopped the timer for FogBugz #{msg.match[1]}"

    robot.hear /bugz my timer/i, (msg) ->
      if msg.message.user.workingon
        msg.send "You're currently working on #{msg.message.user.workingon}"
      else
        msg.send "You don't appear to be working on a case."

  else
    msg.send "My apologies, but it appears that HUBOT_FOGBUGZ_HOST is not set."