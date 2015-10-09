module HelpdeskReports::Field::Ticket

  # Filter data for reports, Check template at the end of file
  def show_options(column_order, columns_keys_by_token, columns_option)
    
    excluded_filters = ReportsAppConfig::EXCLUDE_FILTERS[report_type]
    if excluded_filters
      column_order -=  excluded_filters[Account.current.subscription.subscription_plan.name]||[]
    end
    
    @show_options ||= begin
      defs = {}
      @nf_hash = {}
      #default fields

      column_order.each do |name|
        container = columns_keys_by_token[name]
        defs[name] = {
          operator_list(container).to_sym => container,
          :condition  =>  name ,
          :name       =>  columns_option[name],
          :container  =>  "multi_select",
          :operator   =>  operator_list(container),
          :options    =>  default_choices(name),
          :value      =>  "",
          :field_type =>  "default",
          :ff_name    =>  "default",
          :active     =>  false
        }
        field_label_id_hash(defs[name])
      end

      #Custom fields
      Account.current.custom_dropdown_fields_from_cache.each do |col|
        condition = id_from_field(col).to_sym
        defs[condition] = {
          op_from_field(col).to_sym => container_from_field(col),
          :condition  =>  condition,
          :name       =>  col.label,
          :container  =>  "multi_select",
          :operator   =>  op_from_field(col),
          :options    =>  col.dropdown_choices_with_id,
          :value      =>  "",
          :field_type =>  "custom",
          :ff_name    =>  col.name,
          :active     =>  false
        }
        field_label_id_hash(defs[condition])
      end

      Account.current.nested_fields_from_cache.each do |col|
        nested_fields = []
        col.nested_ticket_fields(:include => :flexifield_def_entry).each do |nested_col|
          condition = id_from_field(nested_col).to_sym
          nested_fields.push({        
            operator_list('dropdown').to_sym => 'dropdown',
            :condition  =>  condition,
            :name       =>  nested_col.label,
            :container  =>  "nested_field",
            :operator   =>  operator_list('dropdown'),
            :options    =>  [],
            :value      =>  "" ,
            :field_type =>  "custom",
            :ff_name    =>  nested_col.name,
            :active     =>  false
            })
        end

        condition = id_from_field(col).to_sym
        defs[condition] = {
          op_from_field(col).to_sym => container_from_field(col),
          :condition      =>  condition,
          :name           =>  col.label,
          :container      =>  "nested_field",
          :operator       =>  op_from_field(col),
          :options        =>  col.nested_choices_with_id,
          :value          =>  "",
          :field_type     =>  "custom",
          :field_id       =>  col.id,
          :nested_fields  =>  nested_fields,
          :ff_name        =>  col.name,
          :active         =>  false
        }
        field_label_id_hash(defs[condition])
      end
      defs
    end
  end
  
  def field_label_id_hash(parent_field)
    @nf_hash[parent_field[:condition]] = parent_field[:options].collect{|op| [op.first, op.second]}.to_h
    (parent_field[:nested_fields]||[]).each_with_index do |nf, index|
      helper = []
      if index == 0
        parent_field[:options].each{|op| helper << op.third.collect{|i| [i.first, i.second]}}
      else
        parent_field[:options].each{|op| op.third.each{|nested_op| helper << nested_op.third.collect{|i| [i.first, i.second]}}}
      end
      @nf_hash[nf[:condition]] = helper.flatten(1).to_h
    end
  end


  def id_from_field(tf)
    tf.flexifield_def_entry.flexifield_name
  end

  def container_from_field(tf)
    tf.field_type.gsub('custom_', '').gsub('nested_field','dropdown')
  end

  def op_from_field(tf)
    operator_list(container_from_field(tf))
  end

  def operator_list(name)
    containers = Wf::Config.data_types[:helpdesk_tickets][name]
    container_klass = Wf::Config.containers[containers.first].constantize
    container_klass.operators.first
  end

  def default_choices(field)
    case field.to_sym
    when :status
      Helpdesk::TicketStatus.status_names_from_cache(Account.current)
    when :ticket_type
      Account.current.ticket_types_from_cache.collect { |tt| [tt.id, tt.value] }
    when :source
      TicketConstants.source_list.sort
    when :priority
      TicketConstants.priority_list.sort
    when :agent_id
      Account.current.agents_from_cache.collect { |au| [au.user.id, au.user.name] }
    when :group_id
      Account.current.groups_from_cache.collect { |g| [g.id, g.name]}
    when :product_id
      Account.current.products.collect {|p| [p.id, p.name]}
    when :company_id
      Account.current.companies_from_cache.collect { |au| [au.id, au.name] }
    else
      []
    end
  end

  ###### SAMPLE TEMPLATE #####
=begin
      @show_options = {
            "responder_id": {
              "is_in": "dropdown",
              "condition": "responder_id",
              "name": "Agent",
              "container": "multi_select",
              "operator": "is_in",
              "options": [
                [1, "Support"]
              ],
              "value": "",
              "field_type": "default",
              "ff_name": "default",
              "active": false
            },
            "group_id": {
              "is_in": "dropdown",
              "condition": "group_id",
              "name": "Group",
              "container": "multi_select",
              "operator": "is_in",
              "options": [
                [1,"Product Management"],
                [2,"QA"],
                [3,"Sales"]
              ],
              "value": "",
              "field_type": "default",
              "ff_name": "default",
              "active": false
            },
            "ticket_type": {
              "is_in": "dropdown",
              "condition": "ticket_type",
              "name": "Type",
              "container": "multi_select",
              "operator": "is_in",
              "options": [
                ["Question","Question"],
                ["Incident","Incident"],
                ["Problem","Problem"],
                ["Feature Request","Feature Request"],
                ["Lead","Lead"]
              ],
              "value": "",
              "field_type": "default",
              "ff_name": "default",
              "active": false
            },
            "source": {
              "is_in": "dropdown",
              "condition": "source",
              "name": "Source",
              "container": "multi_select",
              "operator": "is_in",
              "options": [
                [1,"Email"],
                [2,"Portal"],
                [3,"Phone"],
                [4,"Forum"],
                [5,"Twitter"],
                [6,"Facebook"],
                [7,"Chat"],
                [8,"MobiHelp"],
                [9,"Feedback Widget"]
              ],
              "value": "",
              "field_type": "default",
              "ff_name": "default",
              "active": false
            },
            "priority": {
              "is_in": "dropdown",
              "condition": "priority",
              "name": "Priority",
              "container": "multi_select",
              "operator": "is_in",
              "options": [
                [1,"Low"],
                [2,"Medium"],
                [3,"High"],
                [4,"Urgent"]
              ],
              "value": "",
              "field_type": "default",
              "ff_name": "default",
              "active": false
            },
            "status": {
              "is_in": "dropdown",
              "condition": "status",
              "name": "Status",
              "container": "multi_select",
              "operator": "is_in",
              "options": [
                [2,"Open"],
                [3,"Pending"],
                [4,"Resolved"],
                [5,"Closed"],
                [6, "Waiting on Customer"],
                [7,"Waiting on Third Party"]
              ],
              "value": "",
              "field_type": "default",
              "ff_name": "default",
              "active": false
            },
            "product_id": {
              "is_in": "dropdown",
              "condition": "product_id",
              "name": "Product",
              "container": "multi_select",
              "operator": "is_in",
              "options": [
              ],
              "value": "",
              "field_type": "default",
              "ff_name": "default",
              "active": false
            },
            "customer_id": {
              "is_in": "dropdown",
              "condition": "customer_id",
              "name": "Customer",
              "container": "multi_select",
              "operator": "is_in",
              "options": [
              ],
              "value": "",
              "field_type": "default",
              "ff_name": "default",
              "active": false
            },
            "flexifields.ffs_01": {
              "is_in": "dropdown",
              "condition": "flexifields.ffs_01",
              "name": "Chocolate",
              "container": "multi_select",
              "operator": "is_in",
              "options": [
                ["DairyMilk","DairyMilk"],
                ["Munch","Munch"],
                ["KitKat","KitKat"]
              ],
              "value": "",
              "ff_name": "chocolate_40529",
              "active": false
            },
            "flexifields.ffs_02": {
              "is_in": "dropdown",
              "condition": "flexifields.ffs_02",
              "name": "Country",
              "container": "nested_field",
              "operator": "is_in",
              "options": [
                ["India","India",
                  [
                    ["Tamilnadu","Tamilnadu",
                      [
                        ["Chennai","Chennai"],
                        ["Trichy","Trichy"]
                      ]
                    ],
                    ["Rajesthan","Rajesthan",
                      [
                        ["jaipur","jaipur"],
                        ["Ajmeir","Ajmeir"]
                      ]
                    ]
                  ]
                ],
                ["Pakistan","Pakistan",
                  [
                    ["Punjab","Punjab",
                      [
                        ["Karachi","Karachi"],
                        ["Lahore","Lahore"]
                      ]
                    ]
                  ]
                ],
                ["China","China",
                  [
                    ["GuangDong","GuangDong",
                      [
                        ["HonKong","HonKong"],
                        ["Macau","Macau"]
                      ]
                    ]
                  ]
                ]
              ],
              "value": "",
              "field_type": "nested_field",
              "field_id": 12,
              "nested_fields": {
                "flexifields.ffs_03": {
                  "is_in": "dropdown",
                  "condition": "flexifields.ffs_03",
                  "name": "State",
                  "container": "nested_field",
                  "operator": "is_in",
                  "options": [
                  ],
                  "value": "",
                  "field_type": "nested_field",
                  "ff_name": "state_40529",
                  "active": false
                },
                "flexifields.ffs_04": {
                  "is_in": "dropdown",
                  "condition": "flexifields.ffs_04",
                  "name": "City",
                  "container": "nested_field",
                  "operator": "is_in",
                  "options": [
                  ],
                  "value": "",
                  "field_type": "nested_field",
                  "ff_name": "city_40529",
                  "active": false
                }
              },
              "ff_name": "country_40529",
              "active": false
            }
          }
=end
end
