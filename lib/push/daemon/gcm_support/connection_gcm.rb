module Push
  module Daemon
    module GcmSupport
      class ConnectionError < StandardError; end

      class ConnectionGcm
        attr_reader :response, :name, :provider
        PUSH_URL = "https://fcm.googleapis.com/fcm/send"
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
          return http
        end

        def notification_request(data)
          headers = { "Authorization" => "key=#{@provider.configuration[:key]}",
                     "Content-type" => "application/json",
                     "Content-length" => "#{data.length}" }
          uri = URI.parse(PUSH_URL)
          post(uri, data, headers)
        end

        def post(uri, data, headers)
          reconnect_idle if idle_period_exceeded?

          retry_count = 0

          begin
            response = @connection.post(uri.path, data, headers)
            @last_use = Time.now
          rescue EOFError, Errno::ECONNRESET, Timeout::Error => e
            retry_count += 1

            Push::Daemon.logger.error("[#{@name}] Lost connection to #{PUSH_URL} (#{e.class.name}), reconnecting ##{retry_count}...")

            if retry_count <= 3
              reconnect
              sleep 1
              retry
            else
              raise ConnectionError, "#{@name} tried #{retry_count-1} times to reconnect but failed (#{e.class.name})."
            end
          end

          response
        end

        def idle_period_exceeded?
          # Timeout on the http connection is 5 minutes, reconnect after 5 minutes
          @last_use + IDLE_PERIOD < Time.now
        end

        def reconnect_idle
          Push::Daemon.logger.info("[#{@name}] Idle period exceeded, reconnecting...")
          reconnect
        end

        def reconnect
          @connection.finish
          @last_use = Time.now
          @connection.start
        end
      end
    end
  end
end