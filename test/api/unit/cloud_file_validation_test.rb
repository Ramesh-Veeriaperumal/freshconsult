require_relative '../unit_test_helper'

class CloudFileValidationTest < ActionView::TestCase

  def test_required_fields_validation
    cloudfile_validation = CloudFileValidation.new({}, nil)
    refute cloudfile_validation.valid?
    errors = cloudfile_validation.errors.full_messages
    assert errors.include?('Url missing_field')
    assert errors.include?('Filename missing_field')
    assert errors.include?('Application missing_field')
  end

  def test_numericality
    controller_params = { filename: "image.jpg", url: "https://www.dropbox.com/image.jpg", application_id: Faker::Lorem.word }
    cloudfile_validation = CloudFileValidation.new(controller_params, nil)
    refute cloudfile_validation.valid?
    errors = cloudfile_validation.errors.full_messages
    assert errors.include?('Application datatype_mismatch')

    controller_params = { filename: "image.jpg", url: "https://www.dropbox.com/image.jpg", application_id: 10 }
    cloudfile_validation = CloudFileValidation.new(controller_params, nil)
    assert cloudfile_validation.valid?
  end
end
