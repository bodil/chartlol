# Weird CloudFoundry service inspection
boundServices = if process.env.VCAP_SERVICES then JSON.parse process.env.VCAP_SERVICES else null
#console.log "boundServices: " + JSON.stringify(boundServices)

module.exports.mongo_uri = ->
  if boundServices
    service = boundServices["mongodb-1.8"][0]["credentials"]
    "mongo://#{service.username}:#{service.password}@#{service.hostname}:#{service.port}/#{service.db}"
  else
    "mongodb://localhost/chartlol"

module.exports.listen_port = ->
  if process.env.VMC_APP_PORT then parseInt(process.env.VMC_APP_PORT, 10) else 1337
