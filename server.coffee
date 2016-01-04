#!/usr/bin/env coffee
"use strict"
B = require('baconjs')
R = require('ramda')
moment = require 'moment'
io = require('socket.io-client')
log = (msg...) -> console.log new Date().toString(), msg...
rp = require('request-promise')
houmSocket = io('http://houmi.herokuapp.com')
houmConnectE = B.fromEvent(houmSocket, "connect").map("HOUM").log("Connected to")
houmDisconnectE = B.fromEvent(houmSocket, "disconnect")
houmConfig = require('./houm-config.js')
houmLightsP = B.fromPromise(rp("https://houmi.herokuapp.com/api/site/" + houmConfig.siteKey))
  .map(JSON.parse)
  .map(".lights")
  .map((lights) => lights.map(({name,_id})=>{name,id:_id}))
houmLightsP
  .forEach log, "HOUM lights found"
houmConnectE.onValue =>
  houmSocket.emit('clientReady', { siteKey: houmConfig.siteKey})
houmReadyP = B.once(false).concat(B.combineAsArray(houmConnectE, houmLightsP).map(true)).toProperty()
houmReadyP.filter(B._.id)
  .forEach ->
    log "Houm ready"
    log "Lights configured for fading", houmConfig.lights

oneHour = 3600 * 1000
oneMinute = 60 * 1000
fadeTime = 5 * oneMinute
LIGHT = 255
DARK = 0
sunLightInfoP = B.once().concat(B.interval(oneHour))
  .flatMap -> B.fromPromise(rp("http://api.sunrise-sunset.org/json?lat="+houmConfig.latitude+"&lng="+houmConfig.longitude+"&date=today"))
  .map(JSON.parse)
  .flatMapLatest (sunInfo) ->
    now = new Date().getTime()
    timeUntilSunrise = parseTime(sunInfo.results.civil_twilight_begin) - now
    timeUntilSunset = parseTime(sunInfo.results.civil_twilight_end) - now
    log "Sunrise", formatRelativeTime(timeUntilSunrise)
    log "Sunset", formatRelativeTime(timeUntilSunset)
    events = []
    if timeUntilSunrise > 0
      events.push(B.later timeUntilSunrise, LIGHT)
    if timeUntilSunset > 0
      events.push(B.later timeUntilSunset, DARK)
    currentLevel = if timeUntilSunrise <= 0 and timeUntilSunset > 0
        LIGHT
      else
        DARK
    events.push(B.once(currentLevel))
    B.mergeAll(events)
  .skipDuplicates()
  .slidingWindow(2, 1)
  .flatMapLatest ([fst, snd]) ->
    if snd?
      log "fading from" , fst , "to" , snd , "in" , fadeTime , "milliseconds"
      fade fst, snd, fadeTime
    else
      B.once(fst)
  .skipDuplicates()
  .holdWhen(houmReadyP.not())
  .forEach (bri) ->
    houmConfig.lights.forEach (light) ->
      setLight(light.id, bri)

formatRelativeTime = (diff) -> moment().add(diff, "milliseconds").fromNow()
parseTime = (str) -> moment(str + " +0000", "h:mm:ss A Z").toDate().getTime()

setLight = (id, bri) ->
  log "Set brightness of light", id, "to",  bri
  houmSocket.emit('apply/light', {_id: id, on: bri>0, bri })

fade = (startBri, endBri, timeMillis) ->
  timeStep = 1000
  steps = timeMillis / timeStep
  briStep = (endBri - startBri) / steps
  briE = B.interval(timeStep)
    .take(steps)
    .scan(startBri, ((bri, _) -> bri + briStep))
    .changes()
    .concat(B.once(endBri))
    .map(quadraticBrightness)
  briE

quadraticBrightness = (bri) -> Math.ceil(bri * bri / 255)
