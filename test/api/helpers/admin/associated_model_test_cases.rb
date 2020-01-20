Dir[File.join(Rails.root, 'test/api/helpers/admin/ticket_fields/*.rb')].each do |file|
  require file if file.ends_with?('test_cases.rb')
end
module Admin::AssociatedModelTestCases
  include Admin::TicketFields::SectionMappingTestCases
  include Admin::TicketFields::FsmFieldsUpdateDeleteTestCases
end
