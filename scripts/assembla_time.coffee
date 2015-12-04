# Description:
#   Have Hubot remind you to do daily assembla time tracking.
#   hh:mm must be in the same timezone as the server Hubot is on. Probably UTC.
#
#   This is configured to work for Hipchat. You may need to change the 'create alarm' command
#   to match the adapter you're using.
#
# Configuration:
#  HUBOT_ASSEMBLA_ALARM_PREPEND
#
# Commands:
#   hubot alarm help - See a help document explaining how to use.
#   hubot create alarm hh:mm - Creates an assembla time tracking alarm at hh:mm every weekday for this room
#   hubot create alarm hh:mm UTC+2 - Creates an assembla time tracking alarm at hh:mm every weekday for this room (relative to UTC)
#   hubot list alarms - See all alarms for this room
#   hubot list alarms in every room - See all alarms in every room
#   hubot delete hh:mm alarm - If you have an assembla time tracking alarm at hh:mm, deletes it
#   hubot delete all alarms - Deletes all assembla time tracking alarms for this room.
#
# Dependencies:
#   underscore
#   cron

###jslint node: true###

cronJob = require('cron').CronJob
_ = require('underscore')

module.exports = (robot) ->
  # Compares current time to the time of the assembla alarm
  # to see if it should be fired.

  assemblaAlarmShouldFire = (alarm) ->
    alarmTime = alarm.time
    utc = alarm.utc
    now = new Date
    currentHours = undefined
    currentMinutes = undefined
    if utc
      currentHours = now.getUTCHours() + parseInt(utc, 10)
      currentMinutes = now.getUTCMinutes()
      if currentHours > 23
        currentHours -= 23
    else
      currentHours = now.getHours()
      currentMinutes = now.getMinutes()
    alarmHours = alarmTime.split(':')[0]
    alarmMinutes = alarmTime.split(':')[1]
    try
      alarmHours = parseInt(alarmHours, 10)
      alarmMinutes = parseInt(alarmMinutes, 10)
    catch _error
      return false
    if alarmHours == currentHours and alarmMinutes == currentMinutes
      return true
    false

  # Returns all assembla alarms.

  getAlarms = ->
    robot.brain.get('alarms') or []

  # Returns just assembla alarms for a given room.

  getAlarmsForRoom = (room) ->
    _.where getAlarms(), room: room

  # Gets all alarms for assembla, fires ones that should be.

  checkAlarms = ->
    alarms = getAlarms()
    _.chain(alarms).filter(assemblaAlarmShouldFire).pluck('room').each doAlarm
    return

  # Fires the assembla message.

  doAlarm = (room) ->
    message = PREPEND_MESSAGE + _.sample(ASSEMBLA_ALARM_MESSAGES)
    robot.messageRoom room, message
    return

  # Finds the room for most adaptors
  findRoom = (msg) ->
    room = msg.envelope.room
    if _.isUndefined(room)
      room = msg.envelope.user.reply_to
    room

  # Stores a assembla alarm in the brain.

  saveAlarm = (room, time, utc) ->
    alarms = getAlarms()
    newAlarm = 
      time: time
      room: room
      utc: utc
    alarms.push newAlarm
    updateBrain alarms
    return

  # Updates the brain's alarm knowledge.

  updateBrain = (alarms) ->
    robot.brain.set 'alarms', alarms
    return

  clearAllAlarmsForRoom = (room) ->
    alarms = getAlarms()
    alarmsToKeep = _.reject(alarms, room: room)
    updateBrain alarmsToKeep
    alarms.length - (alarmsToKeep.length)

  clearSpecificAlarmForRoom = (room, time) ->
    alarms = getAlarms()
    alarmsToKeep = _.reject(alarms,
      room: room
      time: time)
    updateBrain alarmsToKeep
    alarms.length - (alarmsToKeep.length)

  'use strict'
  # Constants.
  ASSEMBLA_ALARM_MESSAGES = [
    'It is assembla entries time!'
    'Time for assembla entries, y\'all.'
    'It\'s assembla entries adding time once again!'
    'Get up, eneter your time to assembla (it\'s time to do it)'
    'Assembla add entries time. Get up, humans'
    'Assembla add entries time! Now! Go go go!'
  ]
  PREPEND_MESSAGE = process.env.HUBOT_ASSEMBLA_ALARM_PREPEND or ''
  if PREPEND_MESSAGE.length > 0 and PREPEND_MESSAGE.slice(-1) != ' '
    PREPEND_MESSAGE += ' '

  # Check for alarms for assembla that need to be fired, once a minute
  # Monday to Friday.
  new cronJob('1 * * * * 1-5', checkAlarms, null, true)

  robot.respond /delete all alarms for (.+)$/i, (msg) ->
    room = msg.match[1]
    alarmsCleared = clearAllAlarmsForRoom(room)
    msg.send 'Deleted ' + alarmsCleared + ' assembla time tracking alarms for ' + room

  robot.respond /delete all alarms$/i, (msg) ->
    alarmsCleared = clearAllAlarmsForRoom(findRoom(msg))
    msg.send 'Deleted ' + alarmsCleared + ' assembla time tracking alarm' + (if alarmsCleared == 1 then '' else 's') + '. No more asembla time tracking for you.'
    return
  robot.respond /delete ([0-5]?[0-9]:[0-5]?[0-9]) alarm/i, (msg) ->
    time = msg.match[1]
    alarmssCleared = clearSpecificAlarmForRoom(findRoom(msg), time)
    if alarmsCleared == 0
      msg.send 'Nice try. You don\'t even have an assembla time tracking alarm at ' + time
    else
      msg.send 'Deleted your ' + time + ' assembla time tracking alarm.'
    return
  robot.respond /create alarm ((?:[01]?[0-9]|2[0-4]):[0-5]?[0-9])$/i, (msg) ->
    time = msg.match[1]
    room = findRoom(msg)
    saveAlarm room, time
    msg.send 'Ok, from now on I\'ll remind this room to do assembla time tracking every weekday at ' + time
    return
  robot.respond /create alarm ((?:[01]?[0-9]|2[0-4]):[0-5]?[0-9]) UTC([+-]([0-9]|1[0-3]))$/i, (msg) ->
    time = msg.match[1]
    utc = msg.match[2]
    room = findRoom(msg)
    saveAlarm room, time, utc
    msg.send 'Ok, from now on I\'ll remind this room to do a assembla time tracking every weekday at ' + time + ' UTC' + utc
    return
  robot.respond /list alarms/i, (msg) ->
    alarms = getAlarmsForRoom(findRoom(msg))
    if alarms.length == 0
      msg.send 'Well this is awkward. You haven\'t got any alarms for assembla set :-/'
    else
      alarmsText = [ 'Here\'s your list of assembla alarms:' ].concat(_.map(alarms, (alarm) ->
        if alarm.utc
          alarm.time + ' UTC' + alarm.utc
        else
          alarm.time
      ))
      msg.send alarmsText.join('\n')
    return
  robot.respond /list alarms in every room/i, (msg) ->
    alarms = getAlarms()
    if alarms.length == 0
      msg.send 'No, because there aren\'t any.'
    else
      alarmsText = [ 'Here are the assembla alarms for every room:' ].concat(_.map(alarms, (alarm) ->
        'Room: ' + alarm.room + ', Time: ' + alarm.time
      ))
      msg.send alarmsText.join('\n')
    return
  robot.respond /alarm help/i, (msg) ->
    message = []
    message.push 'I can remind you to add your daily assembla time tracking!'
    message.push 'Use me to create an assembla alarm, and then I\'ll post in this room every weekday at the time you specify. Here\'s how:'
    message.push ''
    message.push robot.name + ' create alarm hh:mm - I\'ll remind you to add your time to assembla in this room at hh:mm every weekday.'
    message.push robot.name + ' create alarm hh:mm UTC+2 - I\'ll remind you to add your time to assembla in this room at hh:mm every weekday.'
    message.push robot.name + ' list alarms - See all assembla alarms for this room.'
    message.push robot.name + ' list alarms in every room - Be nosey and see when other rooms have to enter their time to assembla.'
    message.push robot.name + ' delete hh:mm alarm - If you have an assembla alarm at hh:mm, I\'ll delete it.'
    message.push robot.name + ' delete all alarms - Deletes all alarms to enter assembla for this room.'
    msg.send message.join('\n')
    return
  return
