BOOMR.init({
		beacon_url: "/images/spacer.gif",
		BW: {
			enabled:false
		}
	});
BOOMR.subscribe('before_beacon', function(o) {
	console.log(o.t_other);
	o.t_other.split(',').each(function(value,index){
		var arr = value.split('|');
		o[arr[0]] = arr[1];
	});
	var html = "";
	
	// if(o.bw) { html += "Your bandwidth to this server is " + parseInt(o.bw/1024) + "kbps (&#x00b1;" + parseInt(o.bw_err*100/o.bw) + "%)<br>"; }
	// if(o.lat) { html += "Your latency to this server is " + parseInt(o.lat) + "&#x00b1;" + o.lat_err + "ms<br>"; }

	// if(o.t_head) { html += "Your HTML header  section :: <b>" + (o.t_head) + "ms</b><br>"; }
	// if(o.t_body) { html += "Your HTML content  section " + (o.t_body) + "ms<br>"; }
	// if(o.t_domloaded) { html += "Your domloaded in  " + (o.t_domloaded) + "ms<br><br>"; }

	if(o.t_done) { html += "Finnally This page took ::: <b>" + o.t_done/1000 + " s <b>to load."; }

	document.getElementById('benchmarkresult').innerHTML = html;
});

var t_bodyend = new Date().getTime();                        
BOOMR.plugins.RT.setTimer("t_head", t_headerend - t_pagestart).
	setTimer("t_body", t_bodyend - t_headerend); 