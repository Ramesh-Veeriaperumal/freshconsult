module FreddySkillsHelper
  def stub_features
    Account.current.add_feature(:ticket_properties_suggester_eligible)
    Account.current.add_feature(:ticket_properties_suggester)
    Account.current.revoke_feature(:detect_thank_you_note_eligible)
    Account.current.revoke_feature(:detect_thank_you_note)
    yield
  ensure
    Account.current.revoke_feature(:ticket_properties_suggester_eligible)
    Account.current.revoke_feature(:ticket_properties_suggester)
  end

  def show_json(params = {})
    enabled = params.key?(:enabled) ? params[:enabled] : true
    {
      name: 'ticket_properties_suggester',
      enabled: enabled
    }
  end

  def index_json(params = {})
    enabled = params.key?(:enabled) ? params[:enabled] : true
    [
      {
        name: 'ticket_properties_suggester',
        enabled: enabled
      }
    ]
  end
end
