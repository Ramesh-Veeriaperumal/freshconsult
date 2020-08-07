class ScenarioAutomation < VaRule

  attr_accessible :name, :description, :action_data, :accessible_attributes
  belongs_to_account
  
  default_scope -> { where(rule_type: VAConfig::SCENARIO_AUTOMATION) }

  has_one :accessible,
    :class_name => 'Helpdesk::Access',
    :as => 'accessible',
    :dependent => :destroy

  has_many :groups,
           through: :accessible,
           source: :groups

  has_many :users,
           through: :accessible,
           source: :users

  accepts_nested_attributes_for :accessible 
  
  alias_attribute :helpdesk_accessible, :accessible 

  delegate :visible_to_me?, :visible_to_only_me?, to: :accessible

  before_validation :validate_name, :validate_add_note_action
  before_save :set_active

  scope :shared_scenarios, -> (user){
    where(%(acc.access_type != %<users>s) % {
      users: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users],
    }).
    joins(%(JOIN helpdesk_accesses acc ON
      acc.accessible_id = va_rules.id AND
      acc.accessible_type = 'VARule' AND
      va_rules.account_id=%<account_id>i AND
      acc.account_id = va_rules.account_id) % { 
        account_id: user.account_id 
    }).
    order(:name)
  }

  scope :only_me, ->(user) {
    where(%(acc.access_type=%<only_me>s and user_accesses.user_id=%<user_id>i ) % {
        :only_me => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users],
        :user_id => user.id
      })
    .joins(%(JOIN helpdesk_accesses acc ON
                  acc.accessible_id = va_rules.id AND
                  acc.accessible_type = 'VARule' AND
                  va_rules.account_id=%<account_id>i AND
                  acc.account_id = va_rules.account_id
                  inner join user_accesses ON acc.id= user_accesses.access_id AND
                  acc.account_id= user_accesses.account_id) % { :account_id => user.account_id })
    .order(:name)
  }

  INCLUDE_ASSOCIATIONS_BY_CLASS = {
    ScenarioAutomation => {:include => [{:accessible => [:group_accesses, :user_accesses]}]}
  }

  def to_indexed_json
   as_json({
     :root =>"scenario_automation", 
     :tailored_json => true, 
     :only => [:account_id, :name, :rule_type, :active],
     :methods => [:es_access_type, :es_group_accesses, :es_user_accesses],
     }).to_json
  end

  def to_count_es_json
    as_json({
    :root => false,
    :tailored_json => true,
    :only => [:account_id, :name, :rule_type, :active],
    :methods => [:es_access_type, :es_group_accesses, :es_user_accesses],
    }).to_json
  end

  private

  def validate_name
    if !self.accessible.user_access_type? && (self.name_changed? || access_type_changed?)
      scen_ids = Account.current.scn_automations.shared_scenarios(User.current).where("va_rules.name = ?", self.name).pluck(:id)
      scen_ids = scen_ids.select{|id| id != self.id} if !self.new_record?
      unless scen_ids.empty?
        self.errors.add(:base,I18n.t('automations.duplicate_title'))
        return false
      end
    end
    true
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

  def validate_add_note_action
    action_data.each do |action|
      next unless action['name'] == Admin::AutomationConstants::ADD_COMMENT

      begin
        Liquid::Template.parse(action['comment'])
      rescue Exception => e
        errors.add(:action_add_note, e.to_s)
        return false
      end
    end
    true
  end
end
