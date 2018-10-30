require_relative '../unit_test_helper'

class ProactiveRuleValidationTest < ActionView::TestCase
  include ::Proactive::RuleFiltersConcern

  def create_rule_params
    {
      name: Faker::Lorem.characters(150),
      description: Faker::Lorem.sentence(3, false, 0)
    }
  end

  def create_abandoned_cart_params
    create_rule_params.merge(
      event:'abandoned_cart',
      action:{
        email:{ 
          subject:"dasf asdfa",
          description:"<div>sadfasdfasfasdf dsafas</div>",
          email:"sample@freshdesk.com",
          email_config_id:5,
          status:5,
          type:"Question",
          priority:4,
          group_id:1,
          schedule_details:{
            frequency:2,
            frequency_count:3
          },
        }
      },
      filter:{
        match_type:"all",
        conditions:[
          {
              entity:"contact_fields",
              field:"name",
              operator:"equals",
              value:"123"
          },
          {
              entity:"shopify_fields",
              field:"customer.tags",
              operator:"none_of",
              value:"Clothing"
          }
          
        ]
      },
      integration_details:{
        type:'shopify',
        store_name:'freshdesk-3.myshopify.com'
      }
    )
  end

  def test_filter_without_conditions
    params= create_abandoned_cart_params
    params[:filter].delete(:conditions)
    rule_validation = ProactiveRuleValidation.new(params, nil, true)
    refute rule_validation.valid?(:create) # fails if test is true value
    errors = rule_validation.errors.sort.to_h
    error_options = rule_validation.error_options.sort.to_h
    assert_equal({:filter=>:datatype_mismatch}, errors)
    assert_equal({:filter=>{:expected_data_type=>Array, :code=>:missing_field, :nested_field=>:conditions}}, error_options)
  end

  def test_filter_for_minimum_conditions
    params= create_abandoned_cart_params
    params[:filter].delete(:conditions)
    params[:filter][:conditions] = []
    rule_validation = ProactiveRuleValidation.new(params, nil, true)
    refute rule_validation.valid?(:create) # fails if test is true value
    errors = rule_validation.errors.sort.to_h
    error_options = rule_validation.error_options.sort.to_h
    assert_equal({:filter=>:datatype_mismatch}, errors)
    assert_equal({:filter=>{:expected_data_type=>Array, :code=>:missing_field, :nested_field=>:conditions}}, error_options)
  end


  def test_filter_condition_without_entity
    params= create_abandoned_cart_params
    params[:filter][:conditions][0].delete(:entity)
    rule_validation = ProactiveRuleValidation.new(params, nil, true)
    refute rule_validation.valid?(:create) # fails if test is true value
    errors = rule_validation.errors.sort.to_h
    error_options = rule_validation.error_options.sort.to_h
    assert_equal({:conditions=>:datatype_mismatch}, errors)
    assert_equal({:conditions=>{:expected_data_type=>String, :code=>:missing_field, :nested_field=>:entity}, :filter=>{}}, error_options)
  end
  def test_filter_condition_without_field
    params= create_abandoned_cart_params
    params[:filter][:conditions][0].delete(:field)
    rule_validation = ProactiveRuleValidation.new(params, nil, true)
    refute rule_validation.valid?(:create) # fails if test is true value
    errors = rule_validation.errors.sort.to_h
    error_options = rule_validation.error_options.sort.to_h
    assert_equal({:conditions=>:datatype_mismatch}, errors)
    assert_equal({:conditions=>{:expected_data_type=>String, :code=>:missing_field, :nested_field=>:field}, :filter=>{}}, error_options)
  end

  def test_filter_condition_without_operator
    params= create_abandoned_cart_params
    params[:filter][:conditions][0].delete(:operator)
    rule_validation = ProactiveRuleValidation.new(params, nil, true)
    refute rule_validation.valid?(:create) # fails if test is true value
    errors = rule_validation.errors.sort.to_h
    error_options = rule_validation.error_options.sort.to_h
    assert_equal({:conditions=>:datatype_mismatch}, errors)
    assert_equal({:conditions=>{:expected_data_type=>String, :code=>:missing_field, :nested_field=>:operator}, :filter=>{}}, error_options)
  end

  def test_filter_condition_without_value
    params= create_abandoned_cart_params
    params[:filter][:conditions][0].delete(:value)
    rule_validation = ProactiveRuleValidation.new(params, nil, true)
    refute rule_validation.valid?(:create) # fails if test is true value
    errors = rule_validation.errors.sort.to_h
    error_options = rule_validation.error_options.sort.to_h
    assert_equal({:filter=>:datatype_mismatch}, errors)
    assert_equal({:conditions=>{}, :filter=>{:expected_data_type=>"valid data type", :code=>:missing_field, :nested_field=>"conditions.value"}}, error_options)
  end

  def test_all_customer_validation
    params= create_abandoned_cart_params
    params[:filter] = {}
    rule_validation = ProactiveRuleValidation.new(params, nil, true)
    assert_equal(rule_validation.valid?(:create), true)
  end


  #Delegator test cases

  def test_filter_condition_with_invalid_entity
    params= create_abandoned_cart_params
    params[:filter][:conditions] << {:entity=>"contacts", :field=>"email", :operator=>"equals", :value=>"123"}
    rule_delegator = ProactiveRuleDelegator.new(Object.new, filter: params[:filter], conditions: params[:filter][:conditions], contact_fields: contact_fields, company_fields: company_fields)
    refute rule_delegator.valid?
    errors = rule_delegator.errors.sort.to_h
    error_options = rule_delegator.error_options.sort.to_h
    assert_equal({:filter=>:not_included}, errors)
    assert_equal({:filter=>{:list=>"contact_fields, company_fields, shopify_fields", :nested_field=>"conditions.contacts", :code=>:invalid_value}}, error_options)
  end

  def test_filter_condition_with_invalid_field
    params= create_abandoned_cart_params
    params[:filter][:conditions] << {:entity=>"contact_fields", :field=>"emails", :operator=>"equals", :value=>"123"}
    rule_delegator = ProactiveRuleDelegator.new(Object.new, filter: params[:filter], conditions: params[:filter][:conditions], contact_fields: contact_fields, company_fields: company_fields)
    refute rule_delegator.valid?
    errors = rule_delegator.errors.sort.to_h
    error_options = rule_delegator.error_options.sort.to_h
    assert_equal({:filter=>:not_included}, errors)
    assert_equal({:filter=>{:list=>"email, name, job_title, time_zone, language", :nested_field=>"conditions.emails", :code=>:invalid_value}}, error_options)
  end

  def test_filter_condition_with_invalid_operator
    params= create_abandoned_cart_params
    params[:filter][:conditions] << {:entity=>"contact_fields", :field=>"email", :operator=>"greater_than", :value=>"123"}
    rule_delegator = ProactiveRuleDelegator.new(Object.new, filter: params[:filter], conditions: params[:filter][:conditions], contact_fields: contact_fields, company_fields: company_fields)
    refute rule_delegator.valid?
    errors = rule_delegator.errors.sort.to_h
    error_options = rule_delegator.error_options.sort.to_h
    assert_equal({:filter=>:not_included}, errors)
    assert_equal({:filter=>{:list=>"equals, not_equals, contains, not_contains, starts_with, ends_with", :nested_field=>"conditions.email.greater_than", :code=>:invalid_value}}, error_options)
  end

  def test_filter_condition_with_invalid_choices
    params= create_abandoned_cart_params
    params[:filter][:conditions] << {:entity=>"contact_fields", :field=>"language", :operator=>"equals", :value=>["zz"]}
    rule_delegator = ProactiveRuleDelegator.new(Object.new, filter: params[:filter], conditions: params[:filter][:conditions], contact_fields: contact_fields, company_fields: company_fields)
    refute rule_delegator.valid?
    errors = rule_delegator.errors.sort.to_h
    error_options = rule_delegator.error_options.sort.to_h
    assert_equal({:filter=>:not_included}, errors)
    assert_equal({:filter=>{:list=>"ar, ca, cs, da, de, en, es, es-LA, et, fi, fr, he, hu, id, it, ja, ja-JP, ko, lv-LV, nb-NO, nl, pl, pt-BR, pt-PT, ro, ru-RU, sk, sl, sv-SE, test-ui, th, tr, uk, vi, zh-CN, zh-HK, zh-TW", :nested_field=>"conditions.language.zz", :code=>:invalid_value}}, error_options)
  end

  def test_text_type_with_invalid_data_type
    params= create_abandoned_cart_params
    params[:filter][:conditions] << {:entity=>"contact_fields", :field=>"email", :operator=>"equals", :value=>123}
    rule_delegator = ProactiveRuleDelegator.new(Object.new, filter: params[:filter], conditions: params[:filter][:conditions], contact_fields: contact_fields, company_fields: company_fields)
    refute rule_delegator.valid?
    errors = rule_delegator.errors.sort.to_h
    error_options = rule_delegator.error_options.sort.to_h
    errors[:filter] = :datatype_mismatch
    (error_options[:filter] ||= {}).merge!(expected_data_type: "String", nested_field: "conditions.value", code: :invalid_value)
  end

  def test_multi_text_type_with_invalid_data_type
    params= create_abandoned_cart_params
    params[:filter][:conditions] << {:entity=>"contact_fields", :field=>"language", :operator=>"equals", :value=>"123"}
    rule_delegator = ProactiveRuleDelegator.new(Object.new, filter: params[:filter], conditions: params[:filter][:conditions], contact_fields: contact_fields, company_fields: company_fields)
    refute rule_delegator.valid?
    errors = rule_delegator.errors.sort.to_h
    error_options = rule_delegator.error_options.sort.to_h
    errors[:filter] = :datatype_mismatch
    (error_options[:filter] ||= {}).merge!(expected_data_type: "Array", nested_field: "conditions.value", code: :invalid_value)
  end

  def test_all_customer_delegator_validation
    params= create_abandoned_cart_params
    params[:filter] = {}
    rule_delegator = ProactiveRuleDelegator.new(Object.new, filter: params[:filter], conditions: nil, contact_fields: contact_fields, company_fields: company_fields)
    assert_equal(rule_delegator.valid?, true)
  end

  def company_fields
    {
      "company_fields" => [{:name => "name",
        :type => "multi_text",
        :operations => ["equals", "not_equals", "contains", "not_contains", "starts_with", "ends_with"],
        :auto_complete => true,
        :data_url => "/search/autocomplete/companies"
      }, {:name => "domains",
        :type => "text",
        :operations => ["equals", "not_equals"]
      }]
    }
  end

  def contact_fields
    {
      "contact_fields" => [{:name => "email",
        :type => "text",
        :operations => ["equals", "not_equals", "contains", "not_contains", "starts_with", "ends_with"],
        :auto_complete => true,
        :data_url => "/search/autocomplete/requesters"
      }, {:name => "name",
        :type => "text",
        :operations => ["equals", "not_equals", "contains", "not_contains", "starts_with", "ends_with"]
      }, {:name => "job_title",
        :type => "text",
        :operations => ["equals", "not_equals", "contains", "not_contains", "starts_with", "ends_with"]
      }, {:name => "time_zone",
        :type => "multi_text",
        :choices => [{:name =>:"American Samoa",
          :label => "(GMT-11:00) American Samoa"
        }, {:name =>:"International Date Line West",
          :label => "(GMT-11:00) International Date Line West"
        }, {:name =>:"Midway Island",
          :label => "(GMT-11:00) Midway Island"
        }, {:name =>:Hawaii,
          :label => "(GMT-10:00) Hawaii"
        }, {:name =>:Alaska,
          :label => "(GMT-09:00) Alaska"
        }, {:name =>:"Pacific Time (US & Canada)",
          :label => "(GMT-08:00) Pacific Time (US & Canada)"
        }, {:name =>:Tijuana,
          :label => "(GMT-08:00) Tijuana"
        }, {:name =>:Arizona,
          :label => "(GMT-07:00) Arizona"
        }, {:name =>:Chihuahua,
          :label => "(GMT-07:00) Chihuahua"
        }, {:name =>:Mazatlan,
          :label => "(GMT-07:00) Mazatlan"
        }, {:name =>:"Mountain Time (US & Canada)",
          :label => "(GMT-07:00) Mountain Time (US & Canada)"
        }, {:name =>:"Central America",
          :label => "(GMT-06:00) Central America"
        }, {:name =>:"Central Time (US & Canada)",
          :label => "(GMT-06:00) Central Time (US & Canada)"
        }, {:name =>:Guadalajara,
          :label => "(GMT-06:00) Guadalajara"
        }, {:name =>:"Mexico City",
          :label => "(GMT-06:00) Mexico City"
        }, {:name =>:Monterrey,
          :label => "(GMT-06:00) Monterrey"
        }, {:name =>:Saskatchewan,
          :label => "(GMT-06:00) Saskatchewan"
        }, {:name =>:Bogota,
          :label => "(GMT-05:00) Bogota"
        }, {:name =>:"Eastern Time (US & Canada)",
          :label => "(GMT-05:00) Eastern Time (US & Canada)"
        }, {:name =>:"Indiana (East)",
          :label => "(GMT-05:00) Indiana (East)"
        }, {:name =>:Lima,
          :label => "(GMT-05:00) Lima"
        }, {:name =>:Quito,
          :label => "(GMT-05:00) Quito"
        }, {:name =>:"Atlantic Time (Canada)",
          :label => "(GMT-04:00) Atlantic Time (Canada)"
        }, {:name =>:Caracas,
          :label => "(GMT-04:00) Caracas"
        }, {:name =>:Georgetown,
          :label => "(GMT-04:00) Georgetown"
        }, {:name =>:"La Paz",
          :label => "(GMT-04:00) La Paz"
        }, {:name =>:Santiago,
          :label => "(GMT-04:00) Santiago"
        }, {:name =>:Newfoundland,
          :label => "(GMT-03:30) Newfoundland"
        }, {:name =>:Brasilia,
          :label => "(GMT-03:00) Brasilia"
        }, {:name =>:"Buenos Aires",
          :label => "(GMT-03:00) Buenos Aires"
        }, {:name =>:Greenland,
          :label => "(GMT-03:00) Greenland"
        }, {:name =>:"Mid-Atlantic",
          :label => "(GMT-02:00) Mid-Atlantic"
        }, {:name =>:Azores,
          :label => "(GMT-01:00) Azores"
        }, {:name =>:"Cape Verde Is.",
          :label => "(GMT-01:00) Cape Verde Is."
        }, {:name =>:Casablanca,
          :label => "(GMT+00:00) Casablanca"
        }, {:name =>:Dublin,
          :label => "(GMT+00:00) Dublin"
        }, {:name =>:Edinburgh,
          :label => "(GMT+00:00) Edinburgh"
        }, {:name =>:Lisbon,
          :label => "(GMT+00:00) Lisbon"
        }, {:name =>:London,
          :label => "(GMT+00:00) London"
        }, {:name =>:Monrovia,
          :label => "(GMT+00:00) Monrovia"
        }, {:name =>:UTC,
          :label => "(GMT+00:00) UTC"
        }, {:name =>:Amsterdam,
          :label => "(GMT+01:00) Amsterdam"
        }, {:name =>:Belgrade,
          :label => "(GMT+01:00) Belgrade"
        }, {:name =>:Berlin,
          :label => "(GMT+01:00) Berlin"
        }, {:name =>:Bern,
          :label => "(GMT+01:00) Bern"
        }, {:name =>:Bratislava,
          :label => "(GMT+01:00) Bratislava"
        }, {:name =>:Brussels,
          :label => "(GMT+01:00) Brussels"
        }, {:name =>:Budapest,
          :label => "(GMT+01:00) Budapest"
        }, {:name =>:Copenhagen,
          :label => "(GMT+01:00) Copenhagen"
        }, {:name =>:Ljubljana,
          :label => "(GMT+01:00) Ljubljana"
        }, {:name =>:Madrid,
          :label => "(GMT+01:00) Madrid"
        }, {:name =>:Paris,
          :label => "(GMT+01:00) Paris"
        }, {:name =>:Prague,
          :label => "(GMT+01:00) Prague"
        }, {:name =>:Rome,
          :label => "(GMT+01:00) Rome"
        }, {:name =>:Sarajevo,
          :label => "(GMT+01:00) Sarajevo"
        }, {:name =>:Skopje,
          :label => "(GMT+01:00) Skopje"
        }, {:name =>:Stockholm,
          :label => "(GMT+01:00) Stockholm"
        }, {:name =>:Vienna,
          :label => "(GMT+01:00) Vienna"
        }, {:name =>:Warsaw,
          :label => "(GMT+01:00) Warsaw"
        }, {:name =>:"West Central Africa",
          :label => "(GMT+01:00) West Central Africa"
        }, {:name =>:Zagreb,
          :label => "(GMT+01:00) Zagreb"
        }, {:name =>:Athens,
          :label => "(GMT+02:00) Athens"
        }, {:name =>:Bucharest,
          :label => "(GMT+02:00) Bucharest"
        }, {:name =>:Cairo,
          :label => "(GMT+02:00) Cairo"
        }, {:name =>:Harare,
          :label => "(GMT+02:00) Harare"
        }, {:name =>:Helsinki,
          :label => "(GMT+02:00) Helsinki"
        }, {:name =>:Istanbul,
          :label => "(GMT+02:00) Istanbul"
        }, {:name =>:Jerusalem,
          :label => "(GMT+02:00) Jerusalem"
        }, {:name =>:Kyiv,
          :label => "(GMT+02:00) Kyiv"
        }, {:name =>:Pretoria,
          :label => "(GMT+02:00) Pretoria"
        }, {:name =>:Riga,
          :label => "(GMT+02:00) Riga"
        }, {:name =>:Sofia,
          :label => "(GMT+02:00) Sofia"
        }, {:name =>:Tallinn,
          :label => "(GMT+02:00) Tallinn"
        }, {:name =>:Vilnius,
          :label => "(GMT+02:00) Vilnius"
        }, {:name =>:Baghdad,
          :label => "(GMT+03:00) Baghdad"
        }, {:name =>:Kuwait,
          :label => "(GMT+03:00) Kuwait"
        }, {:name =>:Minsk,
          :label => "(GMT+03:00) Minsk"
        }, {:name =>:Moscow,
          :label => "(GMT+03:00) Moscow"
        }, {:name =>:Nairobi,
          :label => "(GMT+03:00) Nairobi"
        }, {:name =>:Riyadh,
          :label => "(GMT+03:00) Riyadh"
        }, {:name =>:"St. Petersburg",
          :label => "(GMT+03:00) St. Petersburg"
        }, {:name =>:Volgograd,
          :label => "(GMT+03:00) Volgograd"
        }, {:name =>:Tehran,
          :label => "(GMT+03:30) Tehran"
        }, {:name =>:"Abu Dhabi",
          :label => "(GMT+04:00) Abu Dhabi"
        }, {:name =>:Baku,
          :label => "(GMT+04:00) Baku"
        }, {:name =>:Muscat,
          :label => "(GMT+04:00) Muscat"
        }, {:name =>:Tbilisi,
          :label => "(GMT+04:00) Tbilisi"
        }, {:name =>:Yerevan,
          :label => "(GMT+04:00) Yerevan"
        }, {:name =>:Kabul,
          :label => "(GMT+04:30) Kabul"
        }, {:name =>:Ekaterinburg,
          :label => "(GMT+05:00) Ekaterinburg"
        }, {:name =>:Islamabad,
          :label => "(GMT+05:00) Islamabad"
        }, {:name =>:Karachi,
          :label => "(GMT+05:00) Karachi"
        }, {:name =>:Tashkent,
          :label => "(GMT+05:00) Tashkent"
        }, {:name =>:Chennai,
          :label => "(GMT+05:30) Chennai"
        }, {:name =>:Kolkata,
          :label => "(GMT+05:30) Kolkata"
        }, {:name =>:Mumbai,
          :label => "(GMT+05:30) Mumbai"
        }, {:name =>:"New Delhi",
          :label => "(GMT+05:30) New Delhi"
        }, {:name =>:"Sri Jayawardenepura",
          :label => "(GMT+05:30) Sri Jayawardenepura"
        }, {:name =>:Kathmandu,
          :label => "(GMT+05:45) Kathmandu"
        }, {:name =>:Almaty,
          :label => "(GMT+06:00) Almaty"
        }, {:name =>:Astana,
          :label => "(GMT+06:00) Astana"
        }, {:name =>:Dhaka,
          :label => "(GMT+06:00) Dhaka"
        }, {:name =>:Urumqi,
          :label => "(GMT+06:00) Urumqi"
        }, {:name =>:Rangoon,
          :label => "(GMT+06:30) Rangoon"
        }, {:name =>:Bangkok,
          :label => "(GMT+07:00) Bangkok"
        }, {:name =>:Hanoi,
          :label => "(GMT+07:00) Hanoi"
        }, {:name =>:Jakarta,
          :label => "(GMT+07:00) Jakarta"
        }, {:name =>:Krasnoyarsk,
          :label => "(GMT+07:00) Krasnoyarsk"
        }, {:name =>:Novosibirsk,
          :label => "(GMT+07:00) Novosibirsk"
        }, {:name =>:Beijing,
          :label => "(GMT+08:00) Beijing"
        }, {:name =>:Chongqing,
          :label => "(GMT+08:00) Chongqing"
        }, {:name =>:"Hong Kong",
          :label => "(GMT+08:00) Hong Kong"
        }, {:name =>:Irkutsk,
          :label => "(GMT+08:00) Irkutsk"
        }, {:name =>:"Kuala Lumpur",
          :label => "(GMT+08:00) Kuala Lumpur"
        }, {:name =>:Perth,
          :label => "(GMT+08:00) Perth"
        }, {:name =>:Singapore,
          :label => "(GMT+08:00) Singapore"
        }, {:name =>:Taipei,
          :label => "(GMT+08:00) Taipei"
        }, {:name =>:"Ulaan Bataar",
          :label => "(GMT+08:00) Ulaan Bataar"
        }, {:name =>:Osaka,
          :label => "(GMT+09:00) Osaka"
        }, {:name =>:Sapporo,
          :label => "(GMT+09:00) Sapporo"
        }, {:name =>:Seoul,
          :label => "(GMT+09:00) Seoul"
        }, {:name =>:Tokyo,
          :label => "(GMT+09:00) Tokyo"
        }, {:name =>:Yakutsk,
          :label => "(GMT+09:00) Yakutsk"
        }, {:name =>:Adelaide,
          :label => "(GMT+09:30) Adelaide"
        }, {:name =>:Darwin,
          :label => "(GMT+09:30) Darwin"
        }, {:name =>:Brisbane,
          :label => "(GMT+10:00) Brisbane"
        }, {:name =>:Canberra,
          :label => "(GMT+10:00) Canberra"
        }, {:name =>:Guam,
          :label => "(GMT+10:00) Guam"
        }, {:name =>:Hobart,
          :label => "(GMT+10:00) Hobart"
        }, {:name =>:Melbourne,
          :label => "(GMT+10:00) Melbourne"
        }, {:name =>:"Port Moresby",
          :label => "(GMT+10:00) Port Moresby"
        }, {:name =>:Sydney,
          :label => "(GMT+10:00) Sydney"
        }, {:name =>:Vladivostok,
          :label => "(GMT+10:00) Vladivostok"
        }, {:name =>:Magadan,
          :label => "(GMT+11:00) Magadan"
        }, {:name =>:"New Caledonia",
          :label => "(GMT+11:00) New Caledonia"
        }, {:name =>:"Solomon Is.",
          :label => "(GMT+11:00) Solomon Is."
        }, {:name =>:Auckland,
          :label => "(GMT+12:00) Auckland"
        }, {:name =>:Fiji,
          :label => "(GMT+12:00) Fiji"
        }, {:name =>:Kamchatka,
          :label => "(GMT+12:00) Kamchatka"
        }, {:name =>:"Marshall Is.",
          :label => "(GMT+12:00) Marshall Is."
        }, {:name =>:Wellington,
          :label => "(GMT+12:00) Wellington"
        }, {:name =>:"Nuku'alofa",
          :label => "(GMT+13:00) Nuku'alofa"
        }, {:name =>:Samoa,
          :label => "(GMT+13:00) Samoa"
        }, {:name =>:"Tokelau Is.",
          :label => "(GMT+13:00) Tokelau Is."
        }],
        :operations => ["equals", "not_equals"]
      }, {:name => "language",
        :type => "multi_text",
        :choices => [{:name =>:ar
        }, {:name =>:ca
        }, {:name =>:cs
        }, {:name =>:da
        }, {:name =>:de
        }, {:name =>:en
        }, {:name =>:es
        }, {:name =>:"es-LA"
        }, {:name =>:et
        }, {:name =>:fi
        }, {:name =>:fr
        }, {:name =>:he
        }, {:name =>:hu
        }, {:name =>:id
        }, {:name =>:it
        }, {:name =>:ja
        }, {:name =>:"ja-JP"
        }, {:name =>:ko
        }, {:name =>:"lv-LV"
        }, {:name =>:"nb-NO"
        }, {:name =>:nl
        }, {:name =>:pl
        }, {:name =>:"pt-BR"
        }, {:name =>:"pt-PT"
        }, {:name =>:ro
        }, {:name =>:"ru-RU"
        }, {:name =>:sk
        }, {:name =>:sl
        }, {:name =>:"sv-SE"
        }, {:name =>:"test-ui"
        }, {:name =>:th
        }, {:name =>:tr
        }, {:name =>:uk
        }, {:name =>:vi
        }, {:name =>:"zh-CN"
        }, {:name =>:"zh-HK"
        }, {:name =>:"zh-TW"
        }],
        :operations => ["equals", "not_equals"]
      }]
    }
  end



end