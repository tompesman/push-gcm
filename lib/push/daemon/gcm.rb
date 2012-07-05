module Push
  module Daemon
    class Gcm
      attr_accessor :configuration
      def initialize(options)
        self.configuration = options
      end

      def pushconnections
        self.configuration[:connections]
      end

      def totalconnections
        pushconnections
      end

      def connectiontype
        GcmSupport::ConnectionGcm
      end

      def stop; end
    end
  end
end