require "active_support"
require "typhoeus"
require "fetchable"

%w{
  version
  callbacks
  base
  async
  module
  configuration
}.each do |file|
  require "fetch/#{file}"
end

module Fetch
  class << self
    # Convenience method that returns +Fetch::Configuration+.
    def config
      @config ||= Configuration.new
    end

    # Yields a configuration block (+Fetch::Configuration+).
    #
    #   Fetch.configure do |config|
    #     config.user_agent = "Custom User Agent"
    #   end
    def configure(&block)
      yield config
    end
  end
end