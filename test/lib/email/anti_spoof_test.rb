require_relative '../../api/unit_test_helper'
class AntiSpoofTest < ActionView::TestCase
  include ::Email::AntiSpoof

  def test_generate_spoof_data_hash
    spoof_info = { rules: %w[DKIM_DATA SPF_DATA] }.stringify_keys!
    data_hash = generate_spoof_data_hash(spoof_info)
    assert_equal data_hash, email_spoof_data: { DKIM: false, SPF: false }
  end

  def test_generate_spoof_data_hash_with_correct_info
    spoof_info = { rules: %w[DKIM_VERIFIED SPF_PASS] }.stringify_keys!
    data_hash = generate_spoof_data_hash(spoof_info)
    assert_equal data_hash, email_spoof_data: { DKIM: true, SPF: true }
  end

  def test_generate_spoof_data_hash_with_garbage_info
    spoof_info = { rules: %w[GARBAGE_DATA] }.stringify_keys!
    data_hash = generate_spoof_data_hash(spoof_info)
    assert_equal data_hash, email_spoof_data: { DKIM: nil, SPF: nil }
  end

  def test_generate_spoof_data_hash_with_no_rules_hash
    spoof_info = {}
    data_hash = generate_spoof_data_hash(spoof_info)
    assert_equal data_hash, email_spoof_data: { DKIM: nil, SPF: nil }
  end
end
