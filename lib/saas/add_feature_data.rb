module SAAS::AddFeatureData
  def handle_round_robin_add_data
    Role.add_manage_availability_privilege account
  end
end