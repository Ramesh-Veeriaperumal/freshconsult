module GroupConstants
  ARRAY_FIELDS = ['agent_ids'].freeze
  FIELDS = %w(name description escalate_to unassigned_for auto_ticket_assign).freeze | ARRAY_FIELDS

  FIELDS_WITHOUT_TICKET_ASSIGN = %w(name description escalate_to unassigned_for agent_ids).freeze | ARRAY_FIELDS

  UNASSIGNED_FOR_MAP = { '30m' => 1800, '1h' => 3600, '2h' => 7200, '4h' => 14_400,
                         '8h' => 28_800, '12h' => 43_200, '1d' => 86_400, '2d' => 172_800, '3d' => 259_200, nil => 1800 }.freeze
  ATTRIBUTES_TO_BE_STRIPPED = %w(name).freeze

  UNASSIGNED_FOR_ACCEPTED_VALUES = UNASSIGNED_FOR_MAP.keys.compact.freeze
end.freeze
