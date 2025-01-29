child_process = require "child_process"
fs = require "fs"
http = require "http"
os = require "os"
path = require "path"
ws = require "ws"

networkHost = os.networkInterfaces().en0?.filter((i)-> i.family is "IPv4")[0]?.address
reloadCount = 0
started = false
websocket = null

mimeTypes =
  coffee: "text/coffeescript"
  css:    "text/css"
  gif:    "image/gif"
  glsl:   "text/plain"
  gz:     "application/gzip"
  html:   "text/html"
  ico:    "image/x-icon"
  jpeg:   "image/jpeg"
  jpg:    "image/jpeg"
  js:     "text/javascript"
  json:   "application/json"
  map:    "application/json"
  mjs:    "text/javascript"
  mp3:    "audio/mpeg"
  mp4:    "video/mp4"
  pdf:    "application/pdf"
  png:    "image/png"
  rss:    "text/xml"
  svg:    "image/svg+xml"
  swf:    "application/x-shockwave-flash"
  txt:    "text/plain"
  wasm:   "application/wasm"
  webp:   "image/webp"
  wgsl:   "text/wgsl"
  woff2:  "font/woff2"
  woff:   "font/woff"
  xml:    "text/xml"
  xslt:   "text/xml"

# Who needs chalk when you can just roll your own ANSI escape sequences
do ()->
  global.white = (t)-> t
  for color, n of red: 31, green: 32, yellow: 33, blue: 34, magenta: 35, cyan: 36
    do (color, n)-> global[color] = (t)-> "\x1b[#{n}m" + t + "\x1b[0m"

timestamp = ()->
  new Date().toLocaleTimeString "en-US", hour12: false

# Print out logs with nice-looking timestamps
log = (msg, ...more)->
  console.log if msg?.length then yellow(timestamp()) + blue(" → ") + msg else ""
  console.log ...more if more.length
  return msg # pass through

# Special formatting for the messages that announce a server has started
logStarted = (name, msg)->
  console.log "        " + blue(" → ") + name + ": " + msg

# When a favicon isn't found, we serve an SVG icon with a random color
faviconFallback = """
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10" fill="none" stroke-width="2" stroke="lch(70% 100 #{Math.random()*360})">
    <circle cx="5" cy="5" r="1"/>
    <circle cx="5" cy="5" r="4"/>
  </svg>
  """


# This function generates the JS needed to perform live reloading, plus a rainbow-pulse reload indicator
reloadScript =  (address)->
  """
  <style>
    please-reload {
      position: fixed;
      display: block;
      top: 0;
      left: 0;
      width: 100%;
      height: 48px;
      background: linear-gradient(90deg, rgb(255, 0, 0), rgb(255, 154, 0), rgb(208, 222, 33), rgb(79, 220, 74), rgb(63, 218, 216), rgb(47, 201, 226), rgb(28, 127, 238), rgb(95, 21, 242), rgb(186, 12, 248), rgb(251, 7, 217));
      z-index: 2147483647;
      pointer-events: none;
      animation: please-reload .2s .2s both linear;
    }
    @keyframes please-reload { from { transform: scaleX(0) } to { opacity: 0; } }
  </style>
  <script>
    if (window == window.top) {
      (new WebSocket("ws://#{address}")).onmessage = e => { e.data == "reload" ? location.reload(true) : console.log("Unexpected message from Please Reload:", e) };
      document.body.append(document.createElement("please-reload"));
    }
  </script>
  """


# Write out the headers and respond with an optional body
respond = (res, code, body, headers)->
  res.writeHead code, headers
  res.end body


# When a request comes in, figure out what to respond with, and then do that!
handleRequest = (root)-> (req, res)->
  [url, query] = req.url.split "?"
  filePath = decodeURI root + url
  ext = path.extname(filePath).toLowerCase()[1..]

  # When the request doesn't include a file extension, attempt to serve an index.html
  if ext is ""
    if filePath[-1..] isnt "/"
      return respond res, 302, null, location: req.url + "/"
    else
      filePath += "/index.html"
      filePath = filePath.replace "//", "/" # TODO: if we remove the slash on the previous line, can we remove this line?
      ext = "html"

  contentType = mimeTypes[ext]

  unless contentType?
    log red "Unknown Media Type for url: #{req.url}"
    log     "                  filePath: #{filePath}"
    log     "                       ext: #{ext}"
    return respond res, 415

  headers =
    "Cache-Control": "private, no-cache, no-store, must-revalidate"
    "Expires": "-1"
    "Pragma": "no-cache"
    "Content-Type": contentType

  # Check if there's a file we can serve
  try
    stats = fs.statSync filePath

  # If no file was found, either send an automatic fallback or a 404
  catch
    if url is "/favicon.ico"
      return respond res, 200, faviconFallback, Object.assign headers, "Content-Type": "image/svg+xml"
    else
      return respond res, 404

  # For range requests (ie: videos), we need to do a bunch of extra nonsense
  if req.headers.range
    [start, end] = req.headers.range.replace("bytes=", "").split("-")
    start = parseInt(start, 10) or 0
    end = parseInt(end, 10) or stats.size - 1

    if start >= stats.size or end >= stats.size
      return respond res, 416, null, "Content-Range": "bytes */#{stats.size}"

    res.writeHead 206, Object.assign headers,
      "Content-Range": "bytes #{start}-#{end}/#{stats.size}"
      "Content-Length": end - start + 1
      "Accept-Ranges": "bytes"

    fs.createReadStream filePath, {start, end}
      .pipe res

  # For all other requests, serve the file
  else
    fs.readFile filePath, (error, content)->
      return respond res, 404 if error?.code is "ENOENT"
      return respond res, 500, error.code if error?
      if ext is "html"
        content = content.toString()
        if -1 < content.indexOf "</body>"
          content = content.replace "</body>", "  #{reloadScript req.headers.host}\n</body>"
        else
          content += reloadScript req.headers.host
      respond res, 200, content, headers


# Set up a server. Returns a promise that resolves with the port that we ended up using.
createServer = (root, host, port, name)-> new Promise (resolve)->

  # Set up our file server
  server = http.createServer handleRequest root

  server.on "error", (e)->
    # If the port is already in use, try the next port
    if e.code is "EADDRINUSE"
      server.close()
      server.listen { host, port: ++port }
    # For other errors, just make some noise
    else
      log red("Unhandled server error:"), e

  # When we successfully fire up the server, make an announcement and resolve the promise
  server.on "listening", ()->
    logStarted name, green "http://#{host}:#{port}"
    resolve port

  # When the browser connects, upgrade it to a websocket conn, and store the websocket for firing reloads
  wss = new ws.Server noServer: true
  server.on "upgrade", (r,s,h)-> wss.handleUpgrade r,s,h, (ws)->
    # Terminate and replace the old websocket connection (if any) with this new one
    websocket?.terminate()
    websocket = ws

  server.listen { host, port: port }

# Reload any connected browsers
exports.reload = ()->
  if websocket
    websocket.send "reload"
    log green "Reload ##{++reloadCount}"
  else
    log red "Couldn't reload, sorry — there's no websocket"

# Given a root file path, serve those files at two addresses: localhost, and the current IP address
# Optionally open a browser with this server. By default, opens the root. Set the second arg to false
# to not open a browser, or pass a string to open a specific path from the root
exports.serve = (root, open = true)->
  return if started
  started = true

  log ""
  log yellow "Please Reload 🤞"

  # Start a server for localhost
  localPort = await createServer root, "localhost", 3000, "local"

  # Open localhost automatically
  if open
    cmd = "open http://localhost:#{localPort}"
    if typeof open is "string" then cmd += "/" + open.replace /^\//, "" # strip leading slash
    child_process.execSync cmd

  # Start a server for network access
  if networkHost
    await createServer root, networkHost, 3000, "network"
  else
    console.log "        " + blue(" → ") + "network" + ": " + blue "Unavailable"

  log ""
