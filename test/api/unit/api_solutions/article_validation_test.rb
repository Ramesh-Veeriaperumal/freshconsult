require_relative '../../unit_test_helper'

class ApiSolutions::ArticleValidationTest < ActionView::TestCase
  def test_invalid_attachments
    Account.stubs(:current).returns(Account.first)
    String.any_instance.stubs(:size).returns(20_000_000)
    Account.any_instance.stubs(:language_object).returns(Language.find_by_code(:en))
    ValidationHelper.stubs(:attachment_size).returns(100)
    controller_params = {
      title: Faker::Name.name,
      description: Faker::Lorem.paragraph,
      attachments: ['file.png'],
      status: 1, type: 1
    }
    item = nil
    meta = nil
    article = ArticleValidation.new(
      controller_params, item, meta,
      Account.current.language_object.id, true
    )
    refute article.valid?
    errors = article.errors.full_messages
    assert errors.include?('Attachments array_datatype_mismatch')
    assert_equal({
                   title: {}, description: {}, status: {},
                   type: {}, attachments: { expected_data_type: 'valid file format' }
                 }, article.error_options)
    assert errors.count == 1
    Account.unstub(:current)
    ValidationHelper.unstub(:attachment_size)
  end
end
