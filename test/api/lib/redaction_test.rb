require './test/test_helper'

class RedactionTest < ActionView::TestCase

  CREDIT_CARD_NUMBER = {
    visa: ['4532991634668254', '4024007138642334', '4024007160163288807', '4222222222222', '4111111111111111'],
    american_express: ['377261620324999', '378282246310005', '375593374675560', '345337344788864'],
    master: ['50384541566428342', '5388062346276406', '5282839872715551', '5131606280931689'],
    laser: ['670676038979126821'],
    dankort: ['5019717010103742'],
    dinners_club: ['30569309025904', '36800645322372', '36156171798463', '36499459382620'],
    discover: ['6011000990139424', '6011771856537204', '6011375084166214', '6011504995422712284'],
    jcb: ['3530111333300000', '3531699656279404', '3540044720483691'],
    australian_bank: ['5610591081018250'],
    switch: ['6331101999990016'],
    maestro: ['5893944090915131', '6759901290959559'],
    visa_electron: ['4917434441451767', '4917425719174438', '4508833334185801', '4026752922124571']
  }.freeze

  def setup
    super
    @configs = { credit_card_number: true }
  end

  CREDIT_CARD_NUMBER.each_pair do |key, value|
    value.each_with_index do |card_number, index|
      define_method "test_#{key}_#{index}_redaction" do
        data = "Hi, this is #{key} credit card number - #{card_number}"
        redacted_data = Redaction.new(data: data, configs: @configs).redact!
        assert_equal false, redacted_data.first.include?(card_number)
      end
    end
  end

  def test_credit_card_redaction_with_mid_html
    data = '67067603<br>8979<br>126821'
    redacted_data = Redaction.new(data: data, configs: @configs).redact!
    assert redacted_data.include?(data)
  end

  def test_redaction_error
    Redaction.any_instance.stubs(:redact_credit_card_number!).raises(StandardError)
    NewRelic::Agent.expects(:notice_error).at_least_once
    data = '7067603<br>8979<br>126821'
    result = Redaction.new(data: data, configs: @configs).redact!
    assert_nil result
  ensure
    Redaction.any_instance.unstub(:redact_credit_card_number!)
  end
end
