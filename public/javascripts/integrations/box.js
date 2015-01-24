var popupWidth = 660, popupHeight = 440;
var midX = screen.width/2, midY = screen.height/2;
var cLeft = midX - popupWidth/2, cTop = midY - popupHeight/2;

window.Box = {

	chooser_options : new Template('height=#{height},width=#{width},location=no,menubar=no,scrollbars=yes,status=no,toolbar=no,top=#{top},left=#{left},address=no,addressbar=no'),

	choose: function(options){
		this.chooser_window = window.open('/integrations/box/choose', 'freshdesk_box_chooser',
								this.chooser_options.evaluate({
									height: popupHeight, width: popupWidth, left: cLeft, top: cTop
							  }));
		this.chooser_window.box_attaching_document = document;
		this.chooser_window.opener = window;
		Box.on_choose = options.success || function(files){alert(JSON.stringify(files))};
		this.chooser_window.window.Box = Box;
		window.boxObject = this;
	}
};

