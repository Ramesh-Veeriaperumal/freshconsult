class CollabPreEnableWorker
  include Sidekiq::Worker

  sidekiq_options queue: :collaboration_publish, retry: 5, dead: true, failures: :exhausted

  def perform(enable)
    if enable
      Collaboration::Account.new.pre_collab_enable
    else
      Collaboration::Account.new.pre_collab_disable
    end
  end
end
