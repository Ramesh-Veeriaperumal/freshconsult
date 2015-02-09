class ScenarioAutomation < VaRule

  include Search::ElasticSearchIndex
  include Helpdesk::Accessible::ElasticSearchMethods
  
  attr_protected :account_id

  has_one :accessible,
    :class_name => 'Helpdesk::Access',
    :as => 'accessible',
    :dependent => :destroy

  accepts_nested_attributes_for :accessible 
  
  alias_attribute :helpdesk_accessible, :accessible 

  delegate :groups, :users, :visible_to_me?,:visible_to_only_me?, :to => :accessible

  before_validation :validate_name, on: [:create, :update]
  before_save :set_active

  scope :all_managed_scenarios, lambda { |user|
    {
      :joins => %(JOIN helpdesk_accesses acc ON
                  acc.accessible_id = va_rules.id AND
                  acc.accessible_type = 'VARule' AND
                  va_rules.account_id=%<account_id>i AND
                  acc.account_id = va_rules.account_id) % { :account_id => user.account_id },
      :conditions => %(acc.access_type!=%<users>s) % {
        :users => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users],
      }
    }
  }

  scope :only_me, lambda { |user|
    {
      :joins => %(JOIN helpdesk_accesses acc ON
                  acc.accessible_id = va_rules.id AND
                  acc.accessible_type = 'VARule' AND
                  va_rules.account_id=%<account_id>i AND
                  acc.account_id = va_rules.account_id
                  inner join user_accesses ON acc.id= user_accesses.access_id AND
                  acc.account_id= user_accesses.account_id) % { :account_id => user.account_id },
      :conditions => %(acc.access_type=%<only_me>s and user_accesses.user_id=%<user_id>i ) % {
        :only_me => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users],
        :user_id => user.id
      }
    }
  }

  def to_indexed_json
    to_json({
      :root =>"scenario_automation", 
      :tailored_json => true, 
      :only => [:account_id, :name, :rule_type, :active],
      :methods => [:es_access_type, :es_group_accesses, :es_user_accesses],
      })
  end

  private

  def validate_name
   if (visibility_not_myself? && (self.name_changed? || access_type_changed?))
    scenario = Account.current.scn_automations.all_managed_scenarios(User.current).find_by_name(self.name)
    unless scenario.nil?
      self.errors.add_to_base("Duplicate scenario. Name already exists")
      return false
    end
   end
   true
  end

  def visibility_not_myself?
    (self.accessible.access_type != Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users])
  end

  def access_type_changed?
    if (!self.new_record? and self.accessible.access_type_changed?)
      return (self.accessible.changes.fetch("access_type")[0]==Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users])
    end
    false
  end

  def set_active
    self.active = true
  end

end
