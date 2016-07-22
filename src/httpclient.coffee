# node.js deps
https = require 'https'
http  = require 'http'
querystring  = require 'querystring'
URL  = require 'url'
fs = require 'fs'
jsons = JSON.stringify
log = new (require 'log') process.env.HUBOT_LOG_LEVEL or 'info'

# npm deps
http_request_sync = require 'sync-request'

# app deps
config = require '../src/config'

http_request = (options , params , callback) ->
  aurl = URL.parse( options.url )
  options.host = aurl.host
  options.path = aurl.path
  options.headers ||= {}

  client =  if aurl.protocol == "https:" then https else http
  body = ""
  if params and options.method == "POST"
    data = new Buffer jsons params, 'utf8'
    options.headers["Content-Type"] = config.contentType
    options.headers["Content-Length"] = Buffer.byteLength data.toString(), 'utf8'
    options.headers["Connection"] = config.connection
  if params and options.method == "GET"
    query = querystring.stringify params
    append = if aurl.query then "&" else "?"
    options.path += append + query

  options.headers["Cookie"] = config.cookie

  req = client.request options, (resp) ->
    resp.on "data", (chunk) ->
      body += chunk
    resp.on "end", ->
      callback resp, body, options

  req.on "error" , (e)->
    callback(null,e)

  if params and options.method == "POST"
    req.write data
  req.end()

handle_resp_body = (body, options, callback) ->
  err = null
  try
    if _isNotEmptyBody body
      ret = JSON.parse body
  catch error
    log.error "Response in Error: ", options.url, body, error
    err = error
    ret = null
  callback body, ret, err

http_get  = (args...) ->
  [url, params, callback] = args
  [params, callback] = [params, null] unless callback
  options =
    method : 'GET'
    url    : url
  http_request( options , params , callback)


http_upload_file = (options, params, content, callback) ->
  options.method = "POST"
  aurl = URL.parse( options.url )
  options.host = aurl.host
  options.path = aurl.path
  options.headers ||= {}
  endBoundary = params["endBoundary"]

  body = ""

  req = http.request options, (resp) ->
    resp.on "data", (chunk) ->
      body += chunk
    resp.on "end", ->
      log.debug "statusCode: #{resp.statusCode}"
      callback body

  req.on "error" , (e)->
    callback e

  req.write content

  fileStream = fs.createReadStream params.filePath
  fileStream.pipe req, {end: false}
  fileStream.on 'end', () ->
      # mark the end of the one and only part
      log.debug "req end with endBoundary"
      req.end endBoundary
  

http_get_sync = (args...) ->
  [url] = args
  try
    res = http_request_sync 'GET', url, {
      'headers': {
        'Accept': "application/json",
        'Cookie': config.cookie
      },
      'gzip': false
    }
    return res
  catch error
    log.error error

http_post_sync = (args...) ->
  [url, params] = args
  try
    res = http_request_sync 'POST', url, {
      'headers': {
        'Accept': "application/json",
        'Connection': config.connection,
        'Content-Type': config.contentType,
        'Cookie': config.cookie
      },
      'gzip': false,
      json: params
    }
    return res
  catch error
    log.error error

http_post = (options , body , callback) ->
  options.method = "POST"
  http_request(options , body , callback)

_isNotEmptyBody = (body) ->
  return body isnt "" and body isnt null

module.exports =
  request: http_request
  get: http_get
  post: http_post
  get_sync: http_get_sync
  post_sync: http_post_sync
  upload_file: http_upload_file
