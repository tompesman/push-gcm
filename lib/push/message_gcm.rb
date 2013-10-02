module Push
  class MessageGcm < Push::Message
    # TODO: validates max size -> The message size limit is 4096 bytes.
    # The total size of the payload data that is included in a message can't exceed 4096 bytes.
    # Note that this includes both the size of the keys as well as the values.

    store :properties, accessors: [:collapse_key, :delay_when_idle, :time_to_live, :payload]
    attr_accessible :app, :device, :collapse_key, :delay_when_idle, :time_to_live, :payload if defined?(ActiveModel::MassAssignmentSecurity)

    def to_message
      hsh = Hash.new
      hsh['registration_ids'] = [device]
      hsh['collapse_key'] = collapse_key if collapse_key
      hsh['delay_when_idle'] = delay_when_idle if delay_when_idle
      hsh['time_to_live'] = time_to_live if time_to_live
      hsh['data'] = payload
      MultiJson.dump(hsh)
    end

    def use_connection
      Push::Daemon::GcmSupport::ConnectionGcm
    end

    private

    def check_for_error(connection)
      response = connection.response
      if response.code.eql? "200"
        hsh = MultiJson.load(response.body)
        if hsh["failure"] == 1
          msg = hsh["results"][0]["error"]

          # MissingRegistration, handled by validation
          # MismatchSenderId, configuration error by client
          # MessageTooBig, TODO: add validation

          if msg == "NotRegistered" or msg == "InvalidRegistration"
            with_database_reconnect_and_retry(connection.name) do
              Push::FeedbackGcm.create!(:app => connection.provider.configuration[:name], :failed_at => Time.now,
                :device => device, :follow_up => 'delete')
            end
          end

          Push.logger.error("[#{connection.name}] Error received.")
          raise Push::DeliveryError.new(response.code, id, msg, "GCM", false)
        elsif hsh["canonical_ids"] == 1
          # success, but update device token
          update_to = hsh["results"][0]["registration_id"]
          with_database_reconnect_and_retry(connection.name) do
            Push::FeedbackGcm.create!(:app => connection.provider.configuration[:name], :failed_at => Time.now,
              :device => device, :follow_up => 'update', :update_to => update_to)
          end
        end
      else
        Push.logger.error("[#{connection.name}] Error received.")
        raise Push::DeliveryError.new(response.code, id, response.message, "GCM", false)
      end
    end
  end
end