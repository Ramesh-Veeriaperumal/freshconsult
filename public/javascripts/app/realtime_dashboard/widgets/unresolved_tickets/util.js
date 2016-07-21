
var Unresolved_util = function(container,widget_name,data,preview_limit) {

		var _fd = {
			constructChart: function () {
				var self = this;
				var chartname = _fd.widget_name;

				var categories = _fd.resp.order;
				var series = _fd.resp.series;
				var chartData = [] , temp = {};
				
				jQuery.each(series,function(i,el) {
					chartData.push({
						name : el,
						data : []
					});
					temp[el] = [];
				});	

				jQuery.each(categories,function(i,el) {
					var category = _fd.resp['data'][el];
					jQuery.each(category,function(j,row) {
						temp[row.name].push(row.value);
					});
				});

				jQuery.each(chartData,function(i,el) {
					 el['data'] = temp[el.name];
				});

				opts = {
					type : _fd.widget_name,
					chartData : chartData,
					xAxisLabel : categories,
					container : _fd.container
				}
				stackedColumnGraph(opts);
			}
		};
		_fd.container = container;
		_fd.widget_name = widget_name;
		_fd.preview_limit = preview_limit;
		_fd.resp = data;
		return _fd;

}