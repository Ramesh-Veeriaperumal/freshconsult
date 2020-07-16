module CannedFormsTestHelper

  def canned_form_handle_pattern(canned_form_handle)
    {
      id: canned_form_handle.id,
      handle_url: canned_form_handle.handle_url
    }
  end

  def canned_form_pattern(canned_form, options={})
    fields = JSON.parse(canned_form.fields.to_json)
    if options['fields'].present?
      fields.each do |field|
        update_hash = options['fields'].detect{ |updated_field| updated_field['name'] === field['name'] }
        if field['choices'].present?
          field['choices'].each do |choice|
            choice.merge!(update_hash['choices'].detect{ |updated_choice| updated_choice['id'] === choice['id'] })
          end
          update_hash.delete 'choices'
          field['choices'].sort_by! { |c| c['position'] } 
        end
        field.merge!(update_hash) 
      end
      fields.sort_by! { |f| f['position'] }
    end
    {
      'id': canned_form.id,
      'name': options['name'] || canned_form.name,
      'version':  options['version'] || canned_form.version,
      'welcome_text': options['welcome_text'] || canned_form.welcome_text,
      'thankyou_text': options['thankyou_text'] || canned_form.thankyou_text,
      'fields': fields
    }
  end

  def canned_form_index_pattern(canned_form)
    {
      id: canned_form.id,
      name: canned_form.name,
      updated_at: canned_form.updated_at
    }
  end

  def create_canned_form(params={})
    canned_form_params = form_payload(params)
    canned_form = FactoryGirl.build(:canned_form, canned_form_params)
    canned_form.save
    canned_form
  end

  def form_payload(params={})
    {
      'name' => params[:name] || Faker::Name.name,
      'version' => params[:version] || 1,
      'welcome_text' => params[:welcome_text] || Faker::Lorem.characters(100),
      'thankyou_text' => params[:thankyou_text] || Faker::Lorem.characters(100),
      'fields' => params[:fields] || fields_payload
    }
  end

  def fields_payload
    [{
      "name" => "text_#{Faker::Number.number(10)}",
      "label" => Faker::Lorem.characters(10),
      "type" => 1,
      "position" => 1,
      "placeholder" => Faker::Lorem.characters(10),
      "deleted" => false,
      "custom" => true,
      "choices" => [
      ],
      "id" => nil
    }, {
      "name" => "dropdown_#{Faker::Number.number(10)}",
      "label" => Faker::Lorem.characters(10),
      "type" => 2,
      "position" => 2,
      "placeholder" => nil,
      "deleted" => false,
      "custom" => true,
      "choices" => [{
        "value" => Faker::Lorem.characters(10),
        "type" => nil,
        "position" => 1,
        "custom" => true,
        "_destroy" => false,
        "id" => Faker::Number.number(10)
        }, {
        "value" => Faker::Lorem.characters(10),
        "type" => nil,
        "position" => 2,
        "custom" => true,
        "_destroy" => false,
        "id" => Faker::Number.number(10)  
      }, {
        "value" => Faker::Lorem.characters(10),
        "type" => nil,
        "position" => 3,
        "custom" => true,
        "_destroy" => false,
        "id" => Faker::Number.number(10)  
      }],
      "id" => nil
    }, {
      "name" => "checkbox_#{Faker::Number.number(10)}",
      "label" => Faker::Lorem.characters(10),
      "type" => 5,
      "position" => 3,
      "placeholder" => nil,
      "deleted" => false,
      "custom" => true,
      "choices" => [
      ],
      "id" => nil
    }, {
      "name" => "paragraph_#{Faker::Number.number(10)}",
      "label" => Faker::Lorem.characters(10),
      "type" => 6,
      "position" => 4,
      "placeholder" => Faker::Lorem.characters(10),
      "deleted" => false,
      "custom" => true,
      "choices" => [
      ],
      "id" => nil
    }
  ]
  end

  def text_payload
    {
      "name" => "text_#{Faker::Number.number(10)}",
      "label" => Faker::Lorem.characters(10),
      "type" => 1,
      "placeholder" => Faker::Lorem.characters(10),
      "deleted" => false,
      "custom" => true,
      "choices" => [
      ],
      "id" => nil
    }
  end

  def checkbox_payload
    {
      "name" => "checkbox_#{Faker::Number.number(10)}",
      "label" => Faker::Lorem.characters(10),
      "type" => 5,
      "placeholder" => nil,
      "deleted" => false,
      "custom" => true,
      "choices" => [
      ],
      "id" => nil
    }
  end

  def paragraph_payload
    {
      "name" => "paragraph_#{Faker::Number.number(10)}",
      "label" => Faker::Lorem.characters(10),
      "type" => 6,
      "placeholder" => Faker::Lorem.characters(10),
      "deleted" => false,
      "custom" => true,
      "choices" => [
      ],
      "id" => nil
    }
  end

  def dropdown_payload
    {
      "name" => "dropdown_#{Faker::Number.number(10)}",
      "label" => Faker::Lorem.characters(10),
      "type" => 2,
      "placeholder" => nil,
      "deleted" => false,
      "custom" => true,
      "choices" => [{
        "value" => Faker::Lorem.characters(10),
        "type" => nil,
        "position" => 1,
        "custom" => true,
        "_destroy" => false,
        "id" => Faker::Number.number(10)
        }, {
        "value" => Faker::Lorem.characters(10),
        "type" => nil,
        "position" => 2,
        "custom" => true,
        "_destroy" => false,
        "id" => Faker::Number.number(10)  
      }],
      "id" => nil
    }
  end

  def choice_payload
    {
      "value" => Faker::Lorem.characters(10),
      "type" => nil,
      "position" => 3,
      "custom" => true,
      "_destroy" => false,
      "id" => Faker::Number.number(10)
    }
  end

  def update_form_label_position_and_placeholder
    [{
      "label" => Faker::Lorem.characters(10),
      "position" => 4,
      "placeholder" => Faker::Lorem.characters(10)
    }, {
      "label" => Faker::Lorem.characters(10),
      "position" => 1,
      "placeholder" => "",
      "choices" => [{
        "value" => Faker::Lorem.characters(10),
        "position" => 2
      }, {
        "value" => Faker::Lorem.characters(10),
        "position" => 3
      }, {
        "value" => Faker::Lorem.characters(10),
        "position" => 1
      }]
    }, {
      "label" => Faker::Lorem.characters(10),
      "position" => 3
    }, {
      "label" => Faker::Lorem.characters(10),
      "position" => 2,
      "placeholder" => Faker::Lorem.characters(10)
    }]
  end
end