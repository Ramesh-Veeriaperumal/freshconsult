class Admin::Sandbox::DiffWorker < BaseWorker
  include SandboxHelper
  sidekiq_options queue: :sandbox_diff, retry: 0,  failures: :exhausted

  def perform
    committer = {
      name: User.current.name,
      email: User.current.email
    }
    @account = Account.current
    Sharding.select_shard_of(@account.id) do
      @job = @account.sandbox_job
      @sandbox_account_id = @job.sandbox_account_id
      s = ::Sync::Workflow.new(@sandbox_account_id)
      production_config_time_taken = Benchmark.realtime { s.sync_config_from_production(committer) }
      sandbox_config_time_taken = Benchmark.realtime { s.sync_config_from_sandbox(committer) }
      @account.make_current
      diff_changes = s.sandbox_config_changes
      @job.additional_data[:conflict] = diff_changes[:conflict].present?
      templatization_time_taken = Benchmark.realtime { @job.additional_data[:diff] = ::Sync::Templatization.new(diff_changes, @sandbox_account_id).build_delta }
      update_last_diff_details
      @job.mark_as!(:diff_complete)
      Rails.logger.info(" **** [SANDBOX]  Diff worker AccountId #{@account.id} Product config time: #{production_config_time_taken}
                        Sandbox config time #{sandbox_config_time_taken} Templatization time #{templatization_time_taken}****")
    end
  rescue StandardError => e
    Rails.logger.error("Sandbox Diff Exception in account: #{@account.id} \n#{e.message}\n#{e.backtrace[0..7].inspect}")
    NewRelic::Agent.notice_error(e, description: "Sandbox diff Error in Account: #{@account.id}")
    @job.update_last_error(e, :error) if @job
    send_error_notification(e, @account)
  end
  private
    def update_last_diff_details
      diff_details = {:last_diff => Time.now.utc, :diff_by => User.current.id}
      @job.additional_data.merge!(diff_details)
    end

end
