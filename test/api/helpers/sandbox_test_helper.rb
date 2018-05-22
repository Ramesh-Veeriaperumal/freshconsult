module SandboxTestHelper
  include SandboxConstants

  def sandbox_index_pattern(sandbox_job)
    [
        {
            "id"     =>  sandbox_job.id,
            "status" =>  SandboxConstants::PROGRESS_KEYS_BY_TOKEN[sandbox_job.status].to_s
        }
    ]
  end

  def destroy_sandbox_job
    sandbox_job = Account.current.sandbox_job
    sandbox_job.destroy if sandbox_job
  end

end