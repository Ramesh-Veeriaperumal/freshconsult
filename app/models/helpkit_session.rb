class HelpkitSession < ActiveRecord::SessionStore::Session
  include Cache::Memcache::HelpkitSession
  belongs_to :user
  belongs_to_account
  before_save :set_attributes, unless: :attributes_present?
  after_destroy :clear_session_cache

  def self.find_by_session_id(session_id)
    key = SESSION_BY_ID % { :session_id => session_id }
    MemcacheKeys.fetch(key) { super }
  end

  private

    def set_attributes
      self[:account_id] = current_account_id
      self[:user_id] = User.current.try(:id)
    end

    def current_account_id
      Account.current.try(:id) || User.current.try(:account_id)
    end

    def attributes_present?
      self[:account_id].present? && self[:user_id].present?
    end
end