<?php

$manifest = array(
  'author' => 'Freshdesk', 'description' => 'Freshdesk for SugarCRM',
  'name' => 'Freshdesk',

  'acceptable_sugar_versions' => array(
        'regex_matches' => array(
            '7\.[012345]\.\d\w*'
            ),
),
  'acceptable_sugar_flavors' => array('CE', 'PRO', 'CORP', 'ENT', 'ULT'),
  
  'key' => 'freshdesk',
  'type' => 'module',
  'icon' => '',
  'is_uninstallable' => true,
  
  'published_date' => '2014-06-26',
  'readme' => 'README.txt',
  'version' => '1.0',
);

$installdefs = array (
  'id' => 'freshdesk',
  'layoutdefs' => 
  array (
  ),
  'relationships' => 
  array (
  ),
  'image_dir' => '<basepath>/icons',
  'copy' => 
  array (
    0 => 
    array (
      'from' => '<basepath>/SugarModules/modules/freshdesk',
      'to' => 'modules/freshdesk',
    ),
    1 => array (
      'from' => '<basepath>/SugarModules/Extension',
      'to' => 'custom/Extension',
    ),
    2 => array (
      'from' => '<basepath>/FreshDashlet/api',
      'to' => 'custom/clients/base/api',
    ),
    3 => array (
      'from' => '<basepath>/FreshDashlet/helper',
      'to' => 'custom/clients/base/helper',
    ),
    4 => array (
      'from' => '<basepath>/FreshDashlet/views',
      'to' => 'custom/clients/base/views'
    ),
    5 => array (
      'from' => '<basepath>/FreshdeskBwcFix.php',
      'to' => 'custom/Extension/application/Ext/Include/FreshdeskBwcFix.php',
    )
   ),
  'language' => 
  array (
    0 => 
    array (
      'from' => '<basepath>/SugarModules/language/en_us.lang.php',
      'to_module' => 'application',
      'language' => 'en_us',
    ),
    1 => 
    array(
      'from' => '<basepath>/FreshDashlet/dashlets_lang/en_us.lang.php',
      'to_module' => 'application',
      'language' => 'en_us',
    ),
  )
);

$upgrade_manifest = array (
  'upgrade_paths' =>
  array (  ),
);
