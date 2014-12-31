module Timezone::Constants

	UTC = {
		"0" => ["Casablanca","Dublin","Edinburgh","Lisbon","London","Monrovia","UTC","Europe/London"],
		"1" => ["Azores","Cape Verde Is."],
		"2" => ["Mid-Atlantic"],
		"3" => ["Brasilia","Buenos Aires","Georgetown","Greenland"],
		"4" => ["Newfoundland","Atlantic Time (Canada)","La Paz","Santiago"],
		"5" => ["Caracas","Bogota","America/Bogota","Eastern Time (US & Canada)","Indiana (East)","Lima","Quito"],
		"6" => ["Central America","Central Time (US & Canada)","Guadalajara","Mexico City","Monterrey",
						"Saskatchewan","America/Chicago"],
		"7" => ["Arizona","Chihuahua","Mazatlan","Mountain Time (US & Canada)"],
		"8" => ["Pacific Time (US & Canada)","Tijuana", "America/Los_Angeles"],
		"9" => ["Alaska"],
		"10" => ["Hawaii"],
		"11" => ["International Date Line West","Midway Island","Samoa","Nuku'alofa"],
		"12" => ["Auckland","Fiji","Kamchatka","Marshall Is.","Wellington"],
		"13" => ["Magadan","New Caledonia","Solomon Is."],
		"14" => ["Brisbane","Canberra","Guam","Hobart","Melbourne","Port Moresby","Sydney","Vladivostok"],
		"15" => ["Adelaide","Darwin","Osaka","Sapporo","Seoul","Tokyo","Yakutsk"],
		"16" => ["Beijing","Chongqing","Hong Kong","Irkutsk","Kuala Lumpur","Perth","Singapore",
							"Taipei","Ulaan Bataar","Urumqi"],
		"17" => ["Bangkok","Hanoi","Jakarta","Krasnoyarsk"],
		"18" => ["Rangoon","Almaty","Astana","Dhaka","Novosibirsk"],
		"19" => ["Kathmandu","Chennai","Kolkata","Mumbai","New Delhi","Sri Jayawardenepura",
							"Ekaterinburg","Islamabad","Karachi","Tashkent"],
		"20" => ["Kabul","Abu Dhabi","Baku","Muscat","Tbilisi","Yerevan"],
		"21" => ["Tehran","Baghdad","Kuwait","Moscow","Nairobi","Riyadh","St. Petersburg","Volgograd"],
		"22" => ["Athens","Bucharest","Cairo","Harare","Helsinki","Istanbul","Jerusalem","Kyev","Minsk",
							"Pretoria","Riga","Sofia","Tallinn","Vilnius"],
		"23" => ["Amsterdam","Belgrade","Berlin","Bern","Bratislava","Brussels","Budapest","Copenhagen",
							"Ljubljana","Madrid","Paris","Prague","Rome","Sarajevo","Skopje","Stockholm","Vienna",
							"Warsaw","West Central Africa","Zagreb"]
	}

	UTC_MORNINGS = Hash[UTC.map { |k,v| [((k.to_i)+10)%24, v]}]

	MAIL_FORMAT = '%b %d, %Y'

end