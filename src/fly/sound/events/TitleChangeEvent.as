package fly.sound.events
{
	import flash.events.Event;

	/**
	 * This event is dispatched when the title of a song has changed
	 */
	public class TitleChangeEvent extends Event
	{
		static public const TITLE_CHANGE:String = "titleChange";
		
		/**
		 * The actual title
		 */
		public var title:String;
		
		public function TitleChangeEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false, title:String = null)
		{
			super(type, bubbles, cancelable);
			
			this.title = title; 
		}
		
		override public function clone():Event
		{
			var clonedEvent:TitleChangeEvent = new TitleChangeEvent(type, bubbles, cancelable, title);
			
			return clonedEvent;
		}
	}
}