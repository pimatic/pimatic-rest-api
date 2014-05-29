module.exports = (env) ->
  fs = require 'fs'

  convict = env.require "convict"
  Q = env.require 'q'
  assert = env.require 'cassert'
  __ = env.require('i18n').__
  semver = env.require 'semver'
  _ = env.require 'lodash'
  M = env.matcher
  api = env.require 'dec-api'

  class RestApi extends env.plugins.Plugin
    config: null

    init: (app, framework, @config) =>

      onError = (error) =>
        if error instanceof Error
          message = error.message
          env.logger.error error.message
          env.logger.debug error.stack

      app.get("/api/device/:deviceId/:actionName", (req, res, next) =>
        deviceId = req.params.deviceId
        actionName = req.params.actionName
        device = framework.getDeviceById(deviceId)
        if device?
          if device.hasAction(actionName)
            action = device.actions[actionName]
            callActionFromReqAndRespond(actionName, action, device, req, res)
          else
            api.sendErrorResponse(res, 'device hasn\'t that action')
        else api.sendErrorResponse(res, 'device not found')
      )

      api.createExpressRestApi(app, env.api.framework.actions, framework, onError)
      api.createExpressRestApi(app, env.api.rules.actions, framework.ruleManager, onError)
      api.createExpressRestApi(app, env.api.variables.actions, framework.variableManager, onError)
      api.createExpressRestApi(app, env.api.plugins.actions, framework.pluginManager, onError)
      api.createExpressRestApi(app, env.api.database.actions, framework.database, onError)

  return new RestApi