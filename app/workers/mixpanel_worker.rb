class MixpanelWorker

  include Sidekiq::Worker

  sidekiq_options :queue => 'mixpanel_queue', :retry => false

end

