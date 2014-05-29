module.exports = (env) ->

  assert = env.require "cassert"
  express = env.require 'express'
  request = env.require 'supertest'
  Q = env.require 'q'

  describe "pimatic-rest-api", ->

    plugin = (require 'pimatic-rest-api') env
    frameworkDummy = 
      ruleManager:
        rules: {}
    app = express()
    app.use express.bodyParser()

    describe "init", ->
        
      it 'should init', ->
        plugin.init app, frameworkDummy, {}

    describe "get /api/device/:actuatorId/:actionName", ->

      it 'should execute the action', (finish) ->

        hasActionCalled = false
        testActionCalled = false
        actuatorDummy =
          actions:
            testAction:
              params: {}
          hasAction: (actionName) ->
            assert actionName is 'testAction'
            hasActionCalled = true
            return true
          testAction: () -> 
            testActionCalled = true
            return Q.fcall -> true

        getActuatorByIdCalled = false
        frameworkDummy.getDeviceById = (id) ->
          assert id is 'testId'
          getActuatorByIdCalled = true
          return actuatorDummy

        request(app)
          .get('/api/device/testId/testAction')
          .expect('Content-Type', /json/)
          .expect(200)
          .end( (err) ->
            if err then return finish err
            assert getActuatorByIdCalled
            assert hasActionCalled
            assert testActionCalled
            finish()
          )

      it 'should reject unknown actuator', ->

        getActuatorByIdCalled = false
        frameworkDummy.getDeviceById = (id) ->
          assert id is 'testId'
          getActuatorByIdCalled = true
          return null

          request(app)
            .get('/api/actuator/testId/testAction')
            .expect('Content-Type', /json/)
            .expect(404)
            .end( (err) ->
              if err then return finish err
              assert getActuatorByIdCalled
              finish()
            )
    describe "post /api/rule/:ruleId/update", ->

      #before ->
      #  env.logger.transports.console.level = 'ignore'

      #after ->
      #  env.logger.transports.console.level = 'error'

      it 'should call updateRuleByString', (finish) ->

        updateRuleByStringCalled = false
        frameworkDummy.ruleManager.updateRuleByString = (id, {name, ruleString}) ->
          assert id is 'test-id'
          assert ruleString is 'if 1 then 2'
          updateRuleByStringCalled = true
          return Q.fcall -> true

        request(app)
          .post('/api/rule/test-id/update')
          .send(rule: 'if 1 then 2', name:'test')  
          .expect('Content-Type', /json/)
          .expect(200)
          .end( (err) ->
            if err then return finish err
            assert updateRuleByStringCalled
            finish()
          )

      it 'should reject if errors', (finish) ->

        updateRuleByStringCalled = false
        frameworkDummy.ruleManager.updateRuleByString = (id, {name, ruleString}) ->
          assert id is 'test-id'
          assert ruleString is 'if 1 then 2'
          updateRuleByStringCalled = true
          return Q.fcall -> throw new Error('a expected error')

        request(app)
          .post('/api/rule/test-id/update')
          .send(rule: 'if 1 then 2', name:'test')  
          .expect('Content-Type', /json/)
          .expect(406)
          .end( (err, res) ->
            if err then return finish err
            assert updateRuleByStringCalled
            finish()
          )

    describe "post /api/rule/:ruleId/add", ->

      it 'should call addRuleByString', (finish) ->

        addRuleByStringCalled = false
        frameworkDummy.ruleManager.addRuleByString = (id, {name, ruleString}) ->
          assert id is 'test-id'
          assert ruleString is 'if 1 then 2'
          addRuleByStringCalled = true
          return Q.fcall -> true

        request(app)
          .post('/api/rule/test-id/add')
          .send(rule: 'if 1 then 2', name:'test')  
          .expect('Content-Type', /json/)
          .expect(200)
          .end( (err) ->
            if err then return finish err
            assert addRuleByStringCalled
            finish()
          )

      it 'should reject if errors', (finish) ->

        addRuleByStringCalled = false
        frameworkDummy.ruleManager.addRuleByString = (id, {name, ruleString}) ->
          assert id is 'test-id'
          assert ruleString is 'if 1 then 2'
          addRuleByStringCalled = true
          return Q.fcall -> throw new Error('a expected error')

        request(app)
          .post('/api/rule/test-id/add')
          .send(rule: 'if 1 then 2', name:'test')  
          .expect('Content-Type', /json/)
          .expect(406)
          .end( (err, res) ->
            if err then return finish err
            assert addRuleByStringCalled
            finish()
          )

    describe "get /api/rule/:ruleId/remove", ->

      it 'should call removeRule', (finish) ->

        removeRuleCalled = false
        frameworkDummy.ruleManager.removeRule = (id) ->
          assert id is 'test-id'
          removeRuleCalled = true
          return

        request(app)
          .get('/api/rule/test-id/remove')  
          .expect('Content-Type', /json/)
          .expect(200)
          .end( (err) ->
            if err then return finish err
            assert removeRuleCalled
            finish()
          )

      it 'should reject if errors', (finish) ->

        removeRuleCalled = false
        frameworkDummy.ruleManager.removeRule = (id) ->
          assert id is  'test-id'
          removeRuleCalled = true
          throw new Error('a expected error')
          return

        request(app)
          .get('/api/rule/test-id/remove')
          .expect('Content-Type', /json/)
          .expect(500)
          .end( (err, res) ->
            if err then return finish err
            assert removeRuleCalled
            finish()
          )

    describe "get /api/messages", ->

      orgLogger = env.logger
      getBufferCalled = false

      before ->
        env.logger =
          transports:
            memory: 
              getBuffer: () -> 
                getBufferCalled = true
                return ["1", "2"]

      after ->
        env.logger = orgLogger

      it 'should return the log messages', (finish) ->

        request(app)
          .get('/api/messages')
          .expect('Content-Type', /json/)
          .expect(200)
          .end( (err, res) ->
            if err then return finish err
            assert getBufferCalled
            finish()
          )

    describe "get /api/devices", ->

      it 'should return the devices list', (finish) ->

        frameworkDummy.devices = [
          {
            id: 'id1'
            name: 'name1'
          }
          {
            id: 'id2'
            name: 'name2'
          }
        ]

        request(app)
          .get('/api/devices')
          .expect('Content-Type', /json/)
          .expect(200)
          .end( (err, res) ->
            if err then return finish err
            finish()
          )
