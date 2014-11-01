require "cgi"

module Fetch
  # A request to be completed with Typhoeus.
  class Request
    # Initializes the request and sets properties to the values defined in
    # +options+.
    #
    #   request = Fetch::Request.new("http://www.google.com", timeout: 5)
    #   request.url     # => "http://www.google.com"
    #   request.timeout # => 5
    #
    #   request = Fetch::Request.new(timeout: 5)
    #   request.url     # => nil
    #   request.timeout # => 5
    def initialize(*args)
      options = args.pop if args.last.is_a?(Hash)

      if args.any?
        self.url = args.first
      end

      if options
        options.each { |key, value| send("#{key}=", value) }
      end
    end

    # The URL to be requested.
    attr_accessor :url

    # Whether to follow redirects.
    # Default: +true+
    def follow_redirects
      return @follow_redirects if defined?(@follow_redirects)
      @follow_redirects = true
    end

    attr_writer :follow_redirects

    # The method to be used for the request.
    def method
      @method || :get
    end

    attr_writer :method

    # The post body to be sent with the request.
    def body
      @body ||= {}
    end

    attr_writer :body

    # The post body represented as a string.
    def body_string
      body.map { |k, v| "#{CGI::escape(k.to_s)}=#{CGI::escape(v.to_s)}" }.join("&")
    end

    # The timeout for the request.
    # Default: Taken from +Fetch.config.timeout+
    def timeout
      return @timeout if defined?(@timeout)
      Fetch.config.timeout
    end

    attr_writer :timeout

    # The headers to be sent with the request.
    def headers
      @headers ||= {
        "User-Agent" => Fetch.config.user_agent
      }
    end

    attr_writer :headers

    # The user agent being sent with the request.
    def user_agent
      headers["User-Agent"]
    end

    def user_agent=(value)
      headers.merge! "User-Agent" => value
    end

    # Sets the callback to be run when the request completes
    def process(&block)
      raise "You must supply a block to #{self.class.name}#process" unless block
      @process_callback = block
    end

    def process!(body, url, effective_url)
      @process_callback.call(body, url, effective_url) if @process_callback
    rescue => e
      failed!(e)
    end

    def failure(&block)
      raise "You must supply a block to #{self.class.name}#failed" unless block
      @failure_callback = block
    end

    def failed!(exception)
      @failure_callback.call(exception) if @failure_callback
    end
  end
end