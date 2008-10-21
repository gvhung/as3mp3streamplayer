package fly.sound.events
{
	import flash.events.Event;

	public class SoundBufferEvent extends Event
	{
		static public const BUFFER_EMPTY:String = "bufferEmpty";
		static public const BUFFERING:String = "buffering";
		
		public var entriesLoaded:uint;
		public var entriesTotal:uint;
		
		public function SoundBufferEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false, entriesLoaded:uint = 0, entriesTotal:uint = 0)
		{
			super(type, bubbles, cancelable);
			
			this.entriesLoaded = entriesLoaded;
			this.entriesTotal = entriesTotal;
		}
		
		override public function clone():Event
		{
			var clonedEvent:SoundBufferEvent = new SoundBufferEvent(type, bubbles, cancelable, entriesLoaded, entriesTotal);
			
			return clonedEvent;
		}
	}
}