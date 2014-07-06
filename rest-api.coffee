module.exports = (env) ->

  class RestApi extends env.plugins.Plugin

    init: (app, framework, @config) =>
      env.logger.warn """
        The pimatic-rest-api plugin is deprecated, because pimatic >= 0.8.0 has build in support
        for rest calls and a new external api. Please remove the plugin from your config.
      """

  return new RestApi