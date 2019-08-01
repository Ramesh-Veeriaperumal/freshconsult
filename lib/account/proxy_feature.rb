module Account::ProxyFeature
  module ClassMethods
    def proxy_features(features)
      Account::ProxyFeature::ProxyFeatureAssociation.class_eval do
        features.each do |feature|
          define_method(feature) { Account::ProxyFeature::Feature.new(feature, @account) }
          define_method("#{feature}?") { self.feature?(feature) }
        end
      end
    end
  end

  def self.included(receiver)
    receiver.extend ClassMethods
  end
end
