SANCTION_LIST = ["Cuba", "Iran", "Iran, Islamic Republic of", "Myanmar", "Belarus",
  "Cote d'Ivoire", "Congo", "Congo, the Democratic Republic of the", "Iraq", 
  "Lebanon", "Liberia", "Libya", "Libyan Arab Jamahiriya", "North Korea", "Sierra Leone",
  "Somalia", "Sudan", "Syria", "Syrian Arab Republic", "Yemen", "Zimbabwe"]

ActionView::Helpers::FormOptionsHelper::COUNTRIES = 
  ActionView::Helpers::FormOptionsHelper::COUNTRIES - SANCTION_LIST