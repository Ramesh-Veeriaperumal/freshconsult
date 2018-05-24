class Admin::SandboxDecorator < ApiDecorator
  include SandboxConstants
  delegate :id, :status, :sandbox_account_id, :error?,  to: :record

  def to_hash
    ret_hash = {
      id: id,
      status: PROGRESS_KEYS_BY_TOKEN[status]
    }
    ret_hash[:sandbox_url] = DomainMapping.find_by_account_id(sandbox_account_id).domain if status >= STATUS_KEYS_BY_TOKEN[:sandbox_complete] && !error?
    ret_hash
  end
end
