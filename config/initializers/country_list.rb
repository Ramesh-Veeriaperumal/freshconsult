SANCTION_LIST = ["Cuba", "Iran", "Myanmar", "Belarus", "Cote d'Ivoire", "Congo", "Iraq", 
        "Lebanon", "Liberia", "Libya", "North Korea", "Sierra Leone", "Somalia", "Sudan", "Syria", 
        "Yemen", "Zimbabwe"]

ActionView::Helpers::FormOptionsHelper::COUNTRIES = 
  ActionView::Helpers::FormOptionsHelper::COUNTRIES - SANCTION_LIST