/* 
*  Custom Fixed Column for Jquery Datatable
*  @purpose : Jquery Datatable Addon script to attach fixed column.
*  @Datatable_version_supported : 1.10.9
*  @author  : Srihari
*  @usage :  
	*  1. Include the js & associated css in the page.
	*  2. Add a timeout function with delay 0 and invoke the init function of add-on, 
		  after the datatable initialization code.
	   3. If the page is via PJAX, then while leaving the page do not forget to trigger flush. !important
   @Not a Plugin : This feature is not implemented in the plugin structure of a datatable,because
      dom querying is required and there are no render callbacks for other plugins.So only way to query
      dom is after datatable loads.    
*/

fixedColumn = {
	defaults : { 
		hasFixedColumnPlugin : true,
		hasScroll : true,
		hasCustomScrollButtonPlugin : true,
		scrollSpeed : 600 //Use the same speed as scrollButtons plugin,otherwise header and body will animate in different speed.
	},
	constructDom : function(){

		this.body = jQuery(".dataTable tbody");

		var first_cols = this.body.find("tr[role=row] td:first-child,tr.group td:first-child");
		first_cols = first_cols.map(function(i,el){
			var $parent_tr = jQuery(el).parent();
			var row = '';
			if($parent_tr.hasClass('group')) {
				var group_title = $parent_tr.attr('data-group');
				if(group_title != undefined && group_title.length > 73){
					group_title = group_title.substr(0,73) + '...'
				}
				row = '<tr><td class="fixedWidth" ><strong>' + group_title + '</strong></td></tr>';
			} else {
				row = '<tr><td role="row" class = "workable">' + jQuery(el).html().trim() + '</td></tr>';
			}
			
			return row;
		});
		var height = jQuery(".dataTables_scroll").height();
		table = '<div class=\'left_wrapper\' style="height:' + height + 'px"><table class=\'custom_fixed_column dataTable\'><thead class="title"><tr class="row"><th></th></tr></thead><tbody>';
		jQuery.each(first_cols,function(idx,el) {
 			table += el;	
		});
		table += '</tbody></table></div>'

		this.flush();
		jQuery(".left_wrapper").remove();
		jQuery(".dataTables_scroll").append(table)
	},
	init : function(params,dataTableContainer){
		
		var _this = this;
		_this.settings = jQuery.extend({},_this.defaults,params);			
		_this.constructDom();
		_this.bindEvents();		
	},
	bindEvents : function(){
		var _this = this;
		
	},
	flush : function(){
		jQuery(".fixedColumn").remove();
	}
};
