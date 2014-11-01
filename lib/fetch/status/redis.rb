require "time"

module Fetch
  module Status
    module Redis
      def self.included(base)
        base.before_fetch do
          status.started!
        end

        base.progress do |percent|
          status.progress!(percent)
        end

        base.after_fetch do
          status.completed!
        end
      end

      # Returns an instance of +Progress+.
      def redis_status
        @redis_status ||= Status.new(fetch_key)
      end

      alias :status :redis_status

      class Status
        attr_reader :fetch_key

        # Initializes the progress instance with a fetch key.
        def initialize(fetch_key)
          @fetch_key = fetch_key
        end

        # Returns the time where the progress was started, or +nil+ if the
        # fetch hasn't started.
        def started_at
          time = redis.get("#{redis_prefix}:started_at")
          Time.parse(time) if time
        end

        # Returns +true+ if the progress has been started, or +false+ if it
        # hasn't.
        def started?
          !!started_at
        end

        # Marks the progress as started, setting +started_at+ to the current
        # time, +percent+ to 0 and +completed_at+ to nil.
        # Can be used to manually mark the progress as being started, for
        # example right before you send a fetch job to a background queue.
        def started!
          redis.pipelined do
            redis.set("#{redis_prefix}:started_at", Time.now)
            redis.set("#{redis_prefix}:progress", 0)
            redis.del("#{redis_prefix}:completed_at")
          end
        end

        # Returns the time where the progress was completed, or +nil+ if the
        # fetch hasn't completed.
        def completed_at
          time = redis.get("#{redis_prefix}:completed_at")
          Time.parse(time) if time
        end

        # Returns +true+ if the progress has been completed, or +false+ if it
        # hasn't.
        def completed?
          !!completed_at
        end

        # Marks the progress as completed, setting +completed_at+ to the
        # current time.
        def completed!
          redis.pipelined do
            redis.set("#{redis_prefix}:progress", 100)
            redis.set("#{redis_prefix}:completed_at", Time.now)
          end
        end

        # Returns +true+ if the fetch is started and isn't completed.
        def running?
          started? && !completed?
        end

        # Returns the current progress in percent.
        def progress
          redis.get("#{redis_prefix}:progress").to_i
        end

        # Updates the progress +percent+.
        def progress!(percent)
          redis.set("#{redis_prefix}:progress", percent)
        end

        private

        # Shortcut to the main Fetch redis.
        def redis
          Fetch.config.redis
        end

        # Prefix for progress keys in redis.
        def redis_prefix
          "fetch:progress:#{fetch_key}"
        end
      end
    end
  end
end