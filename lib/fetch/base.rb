# Base module for fetch handlers, e.g. +ProductFetch+, +UserFetch+, etc.
module Fetch
  class Base
    include Callbacks

    # Set callbacks to be called when fetching.
    #
    #   before_fetch do
    #     # do something before fetching
    #   end
    #
    #   after_fetch do
    #     # do something after fetching
    #   end
    #
    #   progress do |progress|
    #     # update progress in percent
    #   end
    define_callback :modules,
                    :before_fetch,
                    :after_fetch,
                    :progress

    # Initialize the fetcher with optional arguments to be sent to fetch
    # modules.
    def initialize(*module_args)
      @module_args = module_args
    end

    # Begin fetching.
    # Will run synchronous fetches first and async fetches afterwards.
    # Updates progress when each module finishes its fetch.
    def fetch
      modules = instantiate_modules.select(&:fetch?)

      total = modules.count
      done = 0

      update_progress(total, done)
      before_fetch

      hydra = Typhoeus::Hydra.new

      modules.each do |fetch_module|
        fetch_module.before_fetch
        if fetch_module.async?
          requests = fetch_module.typhoeus_requests do
            fetch_module.after_fetch
            update_progress(total, done += 1)
          end

          requests.each do |request|
            hydra.queue(request)
          end
        else
          fetch_module.fetch
          fetch_module.after_fetch
          update_progress(total, done += 1)
        end
      end

      hydra.run

      after_fetch
    end

    private

    # Holds the arguments to be sent to fetch modules.
    attr_reader :module_args

    # Array of instantiated fetch modules.
    def instantiate_modules
      modules.map { |m| m.new(*module_args) }
    end

    # Updates progress with a percentage calculated from +total+ and +done+.
    def update_progress(total, done)
      percentage = total.zero? ? 100 : ((done.to_f / total) * 100).to_i
      progress(percentage)
    end
  end
end