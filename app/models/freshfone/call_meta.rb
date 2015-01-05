class Freshfone::CallMeta < ActiveRecord::Base
  set_table_name :freshfone_calls_meta

  belongs_to_account
  belongs_to :freshfone_call, :class_name => "Freshfone::Call"
  belongs_to :group

  USER_AGENT_TYPE =[ 
      [:browser, 1],
      [:android, 2 ],
      [:ios, 3],
      [:available_on_phone, 4]
    ]

    USER_AGENT_TYPE_HASH = Hash[*USER_AGENT_TYPE.map { |i| [i[0], i[1]] }.flatten]
    USER_AGENT_TYPE_REVERSE_HASH = Hash[*USER_AGENT_TYPE.map { |i| [i[1], i[0]] }.flatten]
end