module QmsTestHelper
  def enable_qms
    Account.current.add_feature(:quality_management_system)
    ::QualityManagementSystem::PerformQmsOperationsWorker.new.perform
  end

  def disable_qms
    Account.current.revoke_feature(:quality_management_system)
    ::QualityManagementSystem::PerformQmsOperationsWorker.new.perform
  end
end
