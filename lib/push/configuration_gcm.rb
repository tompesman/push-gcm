module Push
  class ConfigurationGcm < Push::Configuration
    store :properties, accessors: [:key]
    attr_accessible :app, :enabled, :connections, :key
    validates :key, :presence => true

    def name
      :gcm
    end
  end
end