class BitmapActionWorker < BaseWorker
  include Sidekiq::Worker
  sidekiq_options queue: :bitmap_callbacks, retry: 0, failures: :exhausted

  Dir[Rails.root.join('lib', 'bitmap_helper', '*.rb')].each { |file| require(file) if File.exist?(file) }
  Dir[Rails.root.join('lib', 'launch_party', '*.rb')].each { |file| require(file) if File.exist?(file) }

  TYPE = %i[add_feature revoke_feature].freeze

  def perform(args)
    args.symbolize_keys!
    account_id = args[:account_id]
    begin
      key = TYPE.include?(args[:change].try(&:to_sym)) && args[:change].to_sym
      class_name = FeatureClassMapping.get_feature_class(args[:feature_name].to_s)
      method_name = :"on_#{key}"
      logger.info "Bitmap callback class name for account_id #{account_id} is #{class_name}"
      feature_class_instance = begin
                                 class_name.constantize.new
                               rescue StandardError
                                 nil
                               end
      feature_class_instance.send(method_name, account_id) if feature_class_instance && feature_class_instance.respond_to?(method_name.to_sym)
    rescue StandardError => e
      logger.info "Error when executing the bitmap callback, args #{args.inspect}, error #{e.inspect}"
    end
  end
end
