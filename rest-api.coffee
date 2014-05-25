module.exports = (env) ->
  fs = require 'fs'

  convict = env.require "convict"
  Q = env.require 'q'
  assert = env.require 'cassert'
  __ = env.require('i18n').__
  semver = env.require 'semver'
  _ = env.require 'lodash'
  M = env.matcher

  class RestApi extends env.plugins.Plugin
    config: null

    init: (app, framework, @config) =>
      
      sendSuccessResponse = (res, data = {}) =>
        data.success = true
        res.send 200, data

      sendErrorResponse = (res, error, statusCode = 400) =>
        message = null
        if error instanceof Error
          message = error.message
          env.logger.error error.message
          env.logger.debug error.stack
        else
          message = error
        res.send statusCode, {success: false, error: message}

      app.get "/api/device/:actuatorId/:actionName", (req, res, next) =>
        actuator = framework.getDeviceById req.params.actuatorId
        if actuator?
          if actuator.hasAction req.params.actionName
            action = actuator.actions[req.params.actionName]
            unless _.keys(req.query).length is _.keys(action.params).length
              sendErrorResponse res, 'wrong param count'
              return
            params = []
            for p of action.params
              unless req.query[p]?
                sendErrorResponse res, "expected param: #{p}"
                return
              params.push req.query[p]

            result = actuator[req.params.actionName](params...) 
            Q.when(result,  =>
              sendSuccessResponse res
            ).catch( (error) =>
              sendErrorResponse res, error, 500
            ).done()
          else
            sendErrorResponse res, 'device hasn\'t that action'
        else sendErrorResponse res, 'device not found'

      handleRuleActiveState = ( (req, res, active) =>
        ruleId = req.params.ruleId
        unless ruleId? then return sendErrorResponse res, 'No ruleId given', 400
        rule = framework.ruleManager.rules[ruleId]
        unless rule? then return sendErrorResponse res, 'Rule not found', 400
        framework.ruleManager.updateRuleByString(
          ruleId, 
          rule.name, 
          rule.string, 
          active, 
          rule.logging
        ).then( =>
          message = (if active then 'rule activated' else "rule deactivated")
          sendSuccessResponse res, message: message
        ).catch( (error) =>
          sendErrorResponse res, error, 406
        ).done()
      )

      app.get "/api/rule/:ruleId/activate", (req, res, next) =>
        handleRuleActiveState(req, res, yes)

      app.get "/api/rule/:ruleId/deactivate", (req, res, next) =>
        handleRuleActiveState(req, res, no)

      app.post "/api/rule//add", (req, res, next) =>
        sendErrorResponse res, 'No id given', 400
        
      app.post "/api/rule/:ruleId/update", (req, res, next) =>
        ruleId = req.params.ruleId
        ruleString = req.body.rule
        ruleName = req.body.name
        active = (req.body.active is "true")
        logging = (req.body.logging is "true")
        unless ruleId? then return sendErrorResponse res, 'No ruleId given', 400
        unless ruleName? then return sendErrorResponse res, 'No name given', 400
        unless ruleString? then return sendErrorResponse res, 'No rule given', 400
        framework.ruleManager.updateRuleByString(
          ruleId, 
          ruleName, 
          ruleString, 
          active, 
          logging
        ).then( =>
          sendSuccessResponse res
        ).catch( (error) =>
          sendErrorResponse res, error, 406
        ).done()

      app.post "/api/rule/:ruleId/add", (req, res, next) =>
        ruleId = req.params.ruleId
        ruleString = req.body.rule
        ruleName = req.body.name
        active = (req.body.active is "true")
        logging = (req.body.logging is "true")
        unless ruleId? then return sendErrorResponse res, 'No ruleId given', 400
        unless ruleName? then return sendErrorResponse res, 'No name given', 400
        unless ruleString? then return sendErrorResponse res, 'No rule given', 400

        unless ruleId.match /^[a-z0-9\-_]+$/i
          return sendErrorResponse(
            res, 
            "rule id must only contain alpha numerical symbols, \"-\" and  \"_\"",
            400
          )
        if framework.ruleManager.rules[ruleId]?
          return sendErrorResponse res, "There is already a rule with the id \"#{ruleId}\"", 400

        framework.ruleManager.addRuleByString(
          ruleId, 
          ruleName, 
          ruleString, 
          active, 
          logging
        ).then( =>
          sendSuccessResponse res
        ).catch( (error) =>
          sendErrorResponse res, error, 406
        ).done()

      app.get "/api/rules", (req, res, next) =>
        ruleList = framework.ruleManager.getAllRules()
        sendSuccessResponse res, { rules: ruleList }

      updateVariable = (variableName, variableValue, variableExpression) ->
        if variableValue?
          framework.variableManager.setVariableToValue(variableName, variableValue)
        else
          tokens = null
          if variableExpression.length is 0
            throw new Error("No expression given")
          m = M(variableExpression).matchAnyExpression((m, ts) => tokens = ts)
          unless m.hadMatch() and m.getFullMatch() is variableExpression
            throw new Error("no match")
          framework.variableManager.setVariableToExpr(variableName, tokens, variableExpression)

      app.post "/api/variable/:name/add", (req, res, next) =>
        variableName = req.params.name
        variableValue = req.body.value
        variableExpression = req.body.expression
        unless variableName? then return sendErrorResponse res, 'No name given', 400
        unless variableValue? or variableExpression?
          return sendErrorResponse res, 'No value or expression given', 400

        unless variableName.match /^[a-z0-9\-_]+$/i
          return sendErrorResponse(
            res, 
            "variable name must only contain alpha numerical symbols, \"-\" and  \"_\"",
            400
          )

        if framework.variableManager.isVariableDefined(variableName)
          return sendErrorResponse(res, 
            "There is already a variable with the name \"#{variableName}\"", 400
          )

        Q.fcall( => 
          updateVariable(variableName, variableValue, variableExpression)
        ).then( =>
          sendSuccessResponse res
        ).catch( (error) =>
          sendErrorResponse res, error, 406
        ).done()

      app.post "/api/variable/:name/update", (req, res, next) =>
        variableName = req.params.name
        variableValue = req.body.value
        variableExpression = req.body.expression
        unless variableName? then return sendErrorResponse res, 'No name given', 400
        unless variableValue? or variableExpression?
          return sendErrorResponse res, 'No value or expression given', 400

        unless variableName.match /^[a-z0-9\-_]+$/i
          return sendErrorResponse(
            res, 
            "variable name must only contain alpha numerical symbols, \"-\" and  \"_\"",
            400
          )

        unless framework.variableManager.isVariableDefined(variableName)
          return sendErrorResponse(res, 
            "No variable with the name \"#{variableName}\" found.", 400
          )

        Q.fcall( => 
          updateVariable(variableName, variableValue, variableExpression)
        ).then( =>
          sendSuccessResponse res
        ).catch( (error) =>
          sendErrorResponse res, error, 406
        ).done()

      app.get "/api/variable/:name/remove", (req, res, next) =>
        variableName = req.params.name
        try
          framework.variableManager.removeVariable(variableName)
          sendSuccessResponse res
        catch error
          sendErrorResponse res, error, 500

      app.get "/api/rule/:ruleId/remove", (req, res, next) =>
        ruleId = req.params.ruleId
        try
          framework.ruleManager.removeRule ruleId
          sendSuccessResponse res
        catch error
          sendErrorResponse res, error, 500

      app.get "/api/messages", (req, res, next) =>
        memoryTransport = env.logger.transports.memory
        sendSuccessResponse res, { messages: memoryTransport.getBuffer() }

      app.get "/api/devices", (req, res, next) =>
        devicesList = for id, a of framework.devices 
          id: a.id, name: a.name
        sendSuccessResponse res, { devices: devicesList }

      app.get "/api/variables", (req, res, next) =>
        variableList = framework.variableManager.getAllVariables()
        sendSuccessResponse res, { variables: variableList }

      app.get "/api/plugins/installed", (req, res, next) =>
        framework.pluginManager.getInstalledPlugins().then( (plugins) =>

          pluginList = 
            for name in plugins
              packageJson = framework.pluginManager.getInstalledPackageInfo name
              name = name.replace 'pimatic-', ''
              loadedPlugin = framework.getPlugin name
              listEntry = 
                name: name
                active: loadedPlugin?
                description: packageJson.description
                version: packageJson.version
                homepage: packageJson.homepage

          sendSuccessResponse res, { plugins: pluginList}
        ).catch( (error) =>
          sendErrorResponse res, error, 406
        ).done()


      app.get "/api/plugins/search", (req, res, next) =>
        framework.pluginManager.searchForPlugins().then( (plugins) =>
          pluginList =
            for k, p of plugins 
              name = p.name.replace 'pimatic-', ''
              loadedPlugin = framework.getPlugin name
              installed = framework.pluginManager.isInstalled p.name
              packageJson = (
                if installed then framework.pluginManager.getInstalledPackageInfo p.name
                else null
              )
              listEntry =
                name: name
                description: p.description
                version: p.version
                installed: installed
                active: loadedPlugin?
                isNewer: (if installed then semver.gt(p.version, packageJson.version) else false)


          sendSuccessResponse res, { plugins: pluginList}
        ).catch( (error) =>
          sendErrorResponse res, error, 406
        ).done()
        
      app.post "/api/plugins/add", (req, res, next) =>
        plugins = req.body.plugins
        unless plugins? then return sendErrorResponse res, "No plugins given", 400
        pluginNames = (p.plugin for p in framework.config.plugins)
        added = []
        for p in plugins
          unless p in pluginNames
            framework.config.plugins.push
              plugin: p
            added.push p
        framework.saveConfig()
        sendSuccessResponse res, added: added

      app.post "/api/plugins/remove", (req, res, next) =>
        plugins = req.body.plugins
        unless plugins? then return sendErrorResponse res, "No plugins given", 400
        removed = []
        for pToRemove in plugins
          for p, i in framework.config.plugins
            if p.plugin is pToRemove
              framework.config.plugins.splice(i, 1)
              removed.push p.plugin
              break
          framework.saveConfig()
        sendSuccessResponse res, removed: removed

      app.get "/api/outdated/pimatic", (req, res, next) =>
        framework.pluginManager.isPimaticOutdated().then( (result) =>
          sendSuccessResponse res, isOutdated: result 
        ).catch( (error) =>
          sendErrorResponse res, error, 406
        ).done()

      app.get "/api/outdated/plugins", (req, res, next) =>
        framework.pluginManager.getOutdatedPlugins().then( (result) =>
          outdated = []
          for i, p of result
            if semver.gt(p.latest, p.current)
              outdated.push p
          sendSuccessResponse res, outdated: outdated 
        ).catch( (error) =>
          sendErrorResponse res, error, 406
        ).done()

      app.post "/api/update", (req, res, next) =>
        modules = req.body.modules
        deferred = Q.defer()
        # resolve when complete
        framework.pluginManager.update(modules).then(deferred.resolve)
        # or after 10 seconds to prevent a timeout
        Q.delay('still running', 10000).then(deferred.resolve)
        # If the promise gets fullfilled:
        deferred.promise.then( (result) =>
          sendSuccessResponse res, result: result
        ).catch( (error) =>
          sendErrorResponse res, error, 406
        ).done()
       
      app.get "/api/restart", (req, res, next) =>
        try
          framework.restart()
          sendSuccessResponse res
        catch error
          sendErrorResponse res, error, 406

  return new RestApi