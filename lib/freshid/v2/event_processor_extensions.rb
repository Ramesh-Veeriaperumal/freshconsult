module Freshid::V2::EventProcessorExtensions
  ACCOUNT_ORGANISATION_MAPPED = :ACCOUNT_ORGANISATION_MAPPED

  def initialize(params)
    initialize_attributes(params)
  end

  def user_active?(user)
    ###### Overridden ######
    user.active_and_verified?
  end

  def fetch_user_by_uuid(uuid)
    ###### Overridden ######
    Account.current.all_technicians.find_by_freshid_uuid(uuid)
  end

  def post_migration(account, event_type=nil)
    return if ( event_type != ACCOUNT_ORGANISATION_MAPPED || account.freshid_org_v2_enabled? )
    account.rollback(:freshid)
    account.launch_freshid_with_omnibar(true)
  end

  def self.prepended(base)
    class << base
      prepend ClassMethods
    end
  end

  module ClassMethods
    def process_later(args)
      ###### Overridden ######
      Freshid::V2::ProcessEvents.perform_async args
    end
  end
end
