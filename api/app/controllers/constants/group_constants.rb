module GroupConstants
  GROUP_ARRAY_FIELDS = [{ 'agents' => [] }]
  GROUP_FIELDS = %w(name description escalate_to unassigned_for auto_ticket_assign agents) | GROUP_ARRAY_FIELDS

  GROUP_FIELDS_WITHOUT_TICKET_ASSIGN = %w(name description escalate_to unassigned_for agents) | GROUP_ARRAY_FIELDS

  UNASSIGNED_FOR_MAP = { '30m' => 1800, '1h' => 3600, '2h' => 7200, '4h' => 14_400,
                         '8h' => 28_800, '12h' => 43_200, '1d' => 86_400, '2d' => 172_800, '3d' => 259_200, nil => 1800 }
end
