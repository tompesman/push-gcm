module Push
  module Daemon
    module GcmSupport
      class ConnectionGcm
        attr_reader :response, :name, :provider
        PUSH_URL = "https://android.googleapis.com/gcm/send"
        IDLE_PERIOD = 5.minutes

        def initialize(provider, i)
          @provider = provider
          @name = "#{@provider.configuration[:name]}: ConnectionGcm #{i}"
        end

        def connect
          @last_use = Time.now
          uri = URI.parse(PUSH_URL)
          @connection = open_http(uri.host, uri.port)
          @connection.start
          Push::Daemon.logger.info("[#{@name}] Connected to #{PUSH_URL}")
        end

        def write(data)
          @response = notification_request(data)

          # if @response.code.eql? "200"
          #   puts "success, but can have an exception in "
          # elsif @response.code.eql? "400"
          #   puts "formatting exception"
          # elsif @response.code.eql? "401"
          #   puts "authentication exception"
          # elsif @response.code.eql? "500"
          #   puts "internal error GCM server"
          # elsif response.code.eql? "503"
          #   puts "service un-available: exponential back-off"
          #
          #   # do not retry for now
          #
          #   # @response.header.each_header do |key, value|
          #   #   if key.capitalize == "Retry-After".capitalize
          #   #     # TODO USE DELAY
          #   #     @delay_by = value
          #   #   end
          #   # end
          #   # TODO or exponentional back-off
          # end
        end

        private

        def open_http(host, port)
          http = Net::HTTP.new(host, port)
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          return http
        end

        def notification_request(data)
          headers = { "Authorization" => "key=#{@provider.configuration[:key]}",
                     "Content-type" => "application/json",
                     "Content-length" => "#{data.length}" }
          uri = URI.parse(PUSH_URL)

          # Timeout on the http connection is 5 minutes, reconnect after 5 minutes
          if @last_use + IDLE_PERIOD < Time.now
            @connection.finish
            @connection.start
          end
          @last_use = Time.now

          @connection.post(uri.path, data, headers)
        end
      end
    end
  end
end