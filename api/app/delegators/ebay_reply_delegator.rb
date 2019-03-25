class EbayReplyDelegator < ConversationBaseDelegator
  attr_accessor :note
  validate :validate_ebay_account
  validate :validate_ticket_source
  validate :validate_agent_id, if: -> { user_id.present? }
  validate :validate_unseen_replies, on: :ecommerce_reply, if: :traffic_cop_required?

  def initialize(record, options = {})
    super(record, options)
  end

  def validate_ticket_source
    if notable.ebay_question.blank?
      errors[:ticket_id] << :invalid_ebay_ticket_source
    end
  end

  def validate_ebay_account
    ebay_account = Account.current.ecommerce_accounts.where(id: notable.ebay_question.ebay_account_id).first
    return errors[:ebay_account_id] << :"is invalid" unless ebay_account
    errors[:ebay_account_id] << :"requires re-authorization" if ebay_account.reauth_required?
  end

  def validate_agent_id
    user = Account.current.agents_details_from_cache.find { |x| x.id == user_id }
    errors[:agent_id] << :"is invalid" unless user
  end
end
