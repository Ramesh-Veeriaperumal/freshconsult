<?php

$dictionary['Contact']['fields']['freshdesk_tickets_list'] =
array (
'name' => 'freshdesk_tickets_list',
'vname' => 'Freshdesk Tickets',
'type' => 'html',
'function' => array('name'=>'getTickets', 'returns'=>'html', 'include'=>'modules/freshdesk/TicketList.php'),
'len' => '6',
'comment' => '',
'source' => 'non-db',
'studio' => 'visible',
);
