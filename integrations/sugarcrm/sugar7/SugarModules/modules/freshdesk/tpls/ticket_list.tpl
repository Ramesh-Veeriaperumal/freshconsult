<div id="fd_datacontainer">
  <div class="btn-group" style="margin: 10px; width: 300px; float:left">
    Showing: 
  {if $filter == 'all_tickets'}
      <a href="#fd_container"   onclick="javascript:fetchTickets('unresolved')">Open and Pending Tickets</a> | 
      <strong>All Tickets</strong>
  {else}
      <strong>Open and Pending Tickets</strong> | 
      <a  href="#fd_container"  onclick="javascript:fetchTickets('all_tickets')">All Tickets</a>
  {/if}
  </div>
  <a href="{$settings_link}" class="settings_link">Settings</a>

<table class="list view" border="0" cellspacing="0" cellpadding="0" style="border:none;margin:0px;">

  <tr height="20">
    <th style="border-radius:0px">&nbsp;</th>
    <th>Ticket</th>
    <th>Status</th>
    <th>Source</th>
    <th>Priority</th>
    <th>Assigned To</th>
    <th>Created On</th>
    <th>Updated On</th>
    <th>Due By</th>
    <th style="border-radius:0px">&nbsp;</th>
  </tr>
{if is_array($tickets)}
{foreach from=$tickets item=tkt}
  <tr class="{cycle values='oddListRowS1,evenListRowS1'}">
    <td></td>
    <td><a href="{$url_prefix}/helpdesk/tickets/{$tkt->id}" target="_new"><strong>{$tkt->subject}</strong> #{$tkt->id}</a> <br />
      {$tkt->description|truncate}
    </td>
    <td>{$tkt->status}</td>
    <td>{$tkt->source}</td>
    <td>{$tkt->priority}</td>
    <td>{$tkt->assignee}</td>
    <td>{$tkt->created_at}</td>
    <td>{$tkt->updated_at}</td>
    <td>{$tkt->due_by}</td>
    <td></td>
  </tr>
{/foreach}
{else}
  <tr class="evenListRowS1">
    <td></td>
    <td colspan="9" style="text-align:center"><br />No Tickets available for this {$object_type}. <br /><br /></td>
    <td></td>
  </tr>
{/if}  

  <tr>
    <td colspan="4" align="center">
      {if $page > 1}
        <button type="button" title="Previous" class="button" onclick="window.scrollBy(0,(0-document.getElementById('fd_container').offsetHeight)); fetchTickets('{$filter}','{$prev_page}')">Previous</button>
      {/if}
    </td>
    <td colspan="3"> </td>
    <td colspan="4" style="text-align:right"> 
      {if $ticket_count >= 30}
        <button type="button" title="Next" class="button" onclick="window.scrollBy(0,(0-document.getElementById('fd_container').offsetHeight)); fetchTickets('{$filter}','{$next_page}')">Next</button>
      {/if}
    </td>
  </tr>
</table>
</div>