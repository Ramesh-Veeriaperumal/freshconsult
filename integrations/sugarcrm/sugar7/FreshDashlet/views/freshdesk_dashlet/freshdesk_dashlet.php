<?php

$viewdefs['base']['view']['freshdesk_dashlet'] = array(
    'dashlets' => array(
        array(
            'name' => 'LBL_DASHLET_FRESHDESK_NAME',
            'label' => 'LBL_DASHLET_FRESHDESK_NAME',
	    'description' => 'LBL_DASHLET_FRESHDESK_DESCRIPTION',
            'config' => array(
                'limit' => '3',
            ),
            'preview' => array(
                'limit' => '3',
            ),
            'filter' => array(
                'module' => array(
                    'Accounts',
		    'Leads',
	            'Contacts'
                ),
                'view' => 'record'
            ),
        ),
    ),
    'config' => array(
        'fields' => array(
            array(
                'name' => 'limit',
                'label' => 'LBL_DASHLET_CONFIGURE_DISPLAY_ROWS',
                'type' => 'enum',
                'searchBarThreshold' => -1,
                'options' => array(
                    1 => 1,
                    2 => 2,
                    3 => 3,
                    4 => 4,
                    5 => 5,
                    6 => 6,
                    7 => 7,
                    8 => 8,
                ),
            ),
        ),
    ),
    'custom_toolbar' => array(
    	'buttons' => array(
    		array(
    		   'dropdown_buttons' => array(
    			array(
    				'type' => 'dashletaction',
    				'action' => 'personalCredentials',
    				'label' => 'LBL_PERSONAL_CREDENTIAL',
    			),
			array(
				'type' => 'dashletaction',
				'action' => 'refreshClicked',
				'label' => 'LBL_DASHLET_REFRESH_LABEL',
			),
			array(
				'type' => 'dashletaction',
				'action' => 'toggleClicked',
				'label' => 'LBL_DASHLET_MINIMIZE',
				'event' => 'minimize',
			),
			array(
				'type' => 'dashletaction',
				'action' => 'removeClicked',
				'label' => 'LBL_DASHLET_REMOVE_LABEL',
			),
    		    ),
    		),
    	),
    )
);
