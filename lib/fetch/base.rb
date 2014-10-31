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
    define_callback :before_fetch,
                    :after_fetch,
                    :progress

    # Sets the fetch modules to be used when fetching.
    # If you supply a block, it will be evaluated in context of the fetcher.
    #
    #   class SomeFetcher < Fetch::Base
    #     modules Twitter::UserFetch,
    #             Github::UserFetch
    #   end
    #
    #   class SomeFetcher < Fetch::Base
    #     modules do
    #       # Return modules after doing something
    #       # in the instance of the class.
    #     end
    #   end
    def self.modules(*modules, &block)
      if modules.any?
        @modules = modules.flatten
      elsif block_given?
        @modules = block
      else
        @modules
      end
    end

    attr_reader :fetchable

    # Initialize the fetcher with an optional fetchable instance.
    def initialize(fetchable = nil)
      @fetchable = fetchable
    end

    # Fetch key of the fetch, taken from the fetchable.
    def fetch_key
      fetchable.fetch_key if fetchable
    end

    # Begin fetching.
    # Will run synchronous fetches first and async fetches afterwards.
    # Updates progress when each module finishes its fetch.
    def fetch
      modules = instantiate_modules

      @total_count = modules.count
      @completed_count = 0

      update_progress
      before_fetch
      fetchable.before_fetch

      hydra = Typhoeus::Hydra.new

      modules.each do |fetch_module|
        fetch_module.before_fetch
        if fetch_module.async?
          requests = fetch_module.typhoeus_requests do
            fetch_module.after_fetch
            update_progress(true)
          end

          requests.each do |request|
            hydra.queue(request)
          end
        else
          fetch_module.fetch
          fetch_module.after_fetch
          update_progress(true)
        end
      end

      hydra.run

      fetchable.after_fetch
      after_fetch
    end

    private

    # Array of instantiated fetch modules.
    def instantiate_modules
      module_klasses.map { |m| m.new(fetchable) }
    end

    def module_klasses
      klasses = self.class.modules
      klasses = instance_eval(&klasses) if klasses.is_a?(Proc)
      klasses
    end

    # Updates progress.
    def update_progress(one_completed = false)
      @completed_count += 1 if one_completed
      progress(progress_percent)
    end

    # Returns the fetch progress in percent.
    def progress_percent
      return 100 if @total_count == 0
      ((@completed_count.to_f / @total_count) * 100).to_i
    end

  end
end