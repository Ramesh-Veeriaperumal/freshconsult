/* 
*  Custom Fixed Header for Jquery Datatable
*  @purpose : Jquery Datatable Addon script to attach fixed Header.
   @why : Out of box Fixed Header plugin is not compatible with horizontal scroller.
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

fixedHeader = {
	defaults : { 
		hasFixedColumnPlugin : true,
		hasScroll : true,
		hasCustomScrollButtonPlugin : true,
		scrollSpeed : 600 //Use the same speed as scrollButtons plugin,otherwise header and body will animate in different speed.
	},
	constructDom : function(){

		this.topRowOffset = jQuery(".dataTable tbody").offset();
		this.scrollHead_base = jQuery(".dataTables_scrollHead");
		var headerRenderedWidth = this.scrollHead_base.width() - 2; //subtract border width

		this.flush();
		//Create a Header Container and Append to dom
		var header_left = fixedHeader.topRowOffset.left;
		var header = '<div class="fixedHead" style="width:'+ headerRenderedWidth +'px;left:'+ header_left +'px;"></div>';
		jQuery("body").append(header);
		this.head = jQuery(".fixedHead");
		fixedHeader._appendHead();		
	},
	_appendHead : function(){
		var _this = this;
		//Clone the Head Row
		_this.head.empty().html(this.scrollHead_base.clone(true,true));
		//Requery the clone header, because emptying the div will remove reference
		_this.clonedHeader = jQuery(".fixedHead .dataTables_scrollHead");
		
		if(this.settings.hasFixedColumnPlugin){
			var fixedColumnHeader = jQuery(".DTFC_LeftHeadWrapper .dataTable.DTFC_Cloned");
			_this.head.append(fixedColumnHeader.clone(true));
			var calculatedWidthOfFixedColumnByPlugin = jQuery(".DTFC_LeftWrapper").css('width');
			jQuery(".fixedHead .dataTable.DTFC_Cloned").addClass('fixedColumns').css('width',calculatedWidthOfFixedColumnByPlugin);
		}
		this.setScrollPos();
	},
	init : function(params,dataTableContainer){
		
		var _this = this;
		_this.settings = jQuery.extend({},_this.defaults,params);
		
		if(_this.settings.hasScroll || _this.settings.hasCustomScrollButtonPlugin){
			
			_this.clonedHeader = jQuery(".fixedHead .dataTables_scrollHead");
			_this.scrollBody_base = jQuery(".dataTables_scrollBody");
			_this.scrollButtons = jQuery(".scrollers .controls");
			_this.constructDom();
			_this.bindEvents();		
			_this.handleSort(dataTableContainer);	
		}else{
			console.log('This add-on is not required.Use out of box plugin');
		}
	},
	bindEvents : function(){
		var _this = this;
		//OnScroll Behavior
		jQuery(window).scroll(function(){
			var current_window_pos = jQuery(window).scrollTop();
			//toggle the visibility of fixed header
			if(current_window_pos > fixedHeader.topRowOffset.top){
				//Set the header left to body left,this is because if the body was moved when header was not present
				//they will be misaligned
				_this.setScrollPos();
				_this.head.show();
				_this.scrollButtons.addClass("fixedControls");
				
			} else{
				_this.head.hide();
				_this.scrollButtons.removeClass("fixedControls");
			}
		});	

		jQuery(document).on("scrollButtons.scroll_event",function(ev,data){
				jQuery(_this.clonedHeader).animate({
	                scrollLeft: data - 1
	            },
	            _this.settings.scrollSpeed);
		});
	},
	setScrollPos : function(){
		jQuery(this.clonedHeader).scrollLeft(this.scrollBody_base.scrollLeft());
	},
	flush : function(){
		jQuery(".fixedHead").remove();
	},
	/* Even tough the header is deep cloned, only events work. The newly inserted dom header
	 * will not be reflecting the changes to sort icons. So when sorting happens,
	 * we refresh the header alone.
	 */
	handleSort : function(dataTableContainer){
		var _this = this;
		jQuery(dataTableContainer).on('order.dt',function(){
			setTimeout(function(){
				_this._appendHead();
			},0);
			
		})
	}
};
