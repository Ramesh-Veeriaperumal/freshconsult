class Helpdesk::Source < Helpdesk::Choice
  include Cache::Memcache::Account
  include Redis::DisplayIdRedis

  before_destroy :check_if_default

  before_validation :assign_account_choice_id, on: :create, unless: :default

  after_commit :clear_ticket_source_from_cache

  private

    def check_if_default
      if default?
        errors.add(:base, I18n.t('cannot_delete_default_source'))
        false
      end
    end

    def assign_account_choice_id
      key = format(TICKET_SOURCE_ID, account_id: account_id)
      self.account_choice_id = Redis::LuaStore.evaluate(
        $redis_display_id,
        Redis::DisplayIdLua.get_ticket_source_choice_id_lua_script,
        Redis::DisplayIdLua.ticket_source_choice_id_lua_script_sha,
        [:keys], key.to_a
      )
    end
end
