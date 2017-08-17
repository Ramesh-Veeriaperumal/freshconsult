class CollabPreEnableWorker
  include Sidekiq::Worker

  sidekiq_options queue: :collaboration_publish, retry: 5, dead: true, failures: :exhausted

  def perform
    Collaboration::Account.new.pre_collab_enable
  end
end
