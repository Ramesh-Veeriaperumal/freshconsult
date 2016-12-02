module Admin
  class ProvisionSandbox < BaseWorker

    sidekiq_options :queue => :sandbox_sync, :retry => 0, :backtrace => true, :failures => :exhausted

    def perform(args)
      args.symbolize_keys!
      job = Account.current.sandbox_jobs.find(args[:job_id])
    
      job.set_sandbox_to_maintainance_mode

      message   = "Storing Config #{Time.now.strftime("%H:%M:%S")}"
      committer = {
        :name  => User.current.name,
        :email => User.current.email
      }
      
      job.sync_from_prod
      ::Sync::Workflow.new().sync_config_from_production(committer, message, Admin::Sandbox::Account::CONFIGS.map(&:to_s))

      job.provision_staging
      ::Sync::Workflow.new(job.sandbox_account_id).provision_staging_instance
      
      job.complete     
      
      job.set_sandbox_to_live 
    end
  end
end
