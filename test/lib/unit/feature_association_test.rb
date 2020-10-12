require_relative '../test_helper'
class FeaturesTest < ActiveSupport::TestCase

  def test_creation_of_db_features_in_mass_assignment
    features = { features: { open_forums: false, open_solutions: false, hide_portal_forums: true } }
    create_test_features
    destroy_test_features
    @account.disable_setting(:hide_portal_forums)
    @account.update_attributes!(features)
    refute @account.open_forums_enabled?
    refute @account.open_solutions_enabled?
    assert @account.hide_portal_forums_enabled?
    features = @account.features.map(&:to_sym)
    refute features.include? :open_forums
    refute features.include? :open_solutions
    assert features.include? :hide_portal_forums
  end

  def create_test_features
    @account.add_feature(:basic_settings_feature)
    [:open_forums, :open_solutions].each { |setting| @account.enable_setting(setting) }
    assert @account.open_forums_enabled?
    assert @account.open_solutions_enabled?
    features = @account.features.map(&:to_sym)
    assert features.include? :open_forums
    assert features.include? :open_solutions
  end

  def destroy_test_features
    @account.disable_setting(:hide_portal_forums)
    refute @account.hide_portal_forums_enabled?
    refute @account.features.map(&:to_sym).include? :hide_portal_forums
  end
end
