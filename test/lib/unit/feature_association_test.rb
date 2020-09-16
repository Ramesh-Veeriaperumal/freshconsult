require_relative '../test_helper'
class FeaturesTest < ActiveSupport::TestCase

  def test_creation_of_db_features_in_mass_assignment
    features = { features: {open_forums: false, open_solutions: false, hide_portal_forums: true } }
    create_test_features
    destroy_test_features
    @account.revoke_feature(:hide_portal_forums)
    @account.update_attributes!(features)
    refute @account.has_feature? :open_forums
    refute @account.has_feature? :open_solutions
    assert @account.has_feature? :hide_portal_forums
    features = @account.features.map(&:to_sym)
    refute features.include? :open_forums
    refute features.include? :open_solutions
    assert features.include? :hide_portal_forums
  end

  def create_test_features
    [:open_forums, :open_solutions].each { |feature| @account.add_feature(feature) }
    assert @account.has_feature? :open_forums
    assert @account.has_feature? :open_solutions
    features = @account.features.map(&:to_sym)
    assert features.include? :open_forums
    assert features.include? :open_solutions
  end

  def destroy_test_features
    @account.revoke_feature(:hide_portal_forums)
    refute @account.has_feature? :hide_portal_forums
    refute @account.features.map(&:to_sym).include? :hide_portal_forums
  end
end
