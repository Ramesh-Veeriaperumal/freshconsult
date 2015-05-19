<?php

$admin_panels = array();
$admin_panels['freshdesk']['general'] = array(
  'freshdesk',
  'General Settings',
  'Set your Freshdesk account domain',
  'index.php?module=freshdesk&action=settings'
);

$admin_group_header[] = array('Freshdesk - the helpdesk software with social and automation capabilities', '', false, $admin_panels, 'Configure the Freshdesk for SugarCRM module.');
