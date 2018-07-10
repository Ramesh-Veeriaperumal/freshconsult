class Admin::SandboxDecorator < ApiDecorator
  include SandboxConstants
  delegate :id, :status, :sandbox_account_id, :build_error?, :created_at, :updated_at,  to: :record

  def to_hash
    ret_hash = {
      id: id,
      status: PROGRESS_KEYS_BY_TOKEN[status],
      updated_at: updated_at,
      created_at: created_at,
    }
    ret_hash[:sandbox_url] = Account.current.sandbox_domain if status >= STATUS_KEYS_BY_TOKEN[:sandbox_complete] && !build_error?
    ret_hash
  end
end
