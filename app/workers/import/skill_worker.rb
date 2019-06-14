class Import::SkillWorker
  include Sidekiq::Worker

  sidekiq_options :queue => :skill_import, :retry => 0,
                  :failures => :exhausted

  def perform(args)
    params = args.deep_symbolize_keys
    Rails.logger.debug("params for Import::SkillWorker :: #{params.inspect}")
    Import::Skills::Agent.new(params[:data]).import
  end
end
