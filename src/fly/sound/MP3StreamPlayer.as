package fly.sound
{
	import code.google.as3httpclient.HTTP_SEPARATOR;
	import code.google.as3httpclient.SocketHTTPRequest;
	
	import flash.display.Loader;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.HTTPStatusEvent;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SampleDataEvent;
	import flash.events.SecurityErrorEvent;
	import flash.media.Sound;
	import flash.media.SoundChannel;
	import flash.net.Socket;
	import flash.net.URLRequest;
	import flash.net.URLRequestHeader;
	import flash.net.URLRequestMethod;
	import flash.system.Capabilities;
	import flash.system.LoaderContext;
	import flash.utils.ByteArray;
	import flash.utils.setTimeout;
	
	import fly.binary.swf.SWFByteArray;
	import fly.binary.swf.tags.DefineSound;
	import fly.binary.swf.tags.Tag;
	import fly.binary.swf.tags.soundClasses.MP3Frame;
	import fly.binary.swf.tags.soundClasses.MP3SoundData;
	import fly.binary.swf.tags.soundClasses.SoundInformation;
	import fly.binary.swf.tags.soundClasses.errors.InvalidBitrateError;
	import fly.binary.swf.tags.soundClasses.errors.InvalidHeaderStart;
	import fly.binary.swf.tags.soundClasses.errors.InvalidMPEGVersionError;
	import fly.binary.swf.tags.soundClasses.errors.InvalidSamplingRateError;
	import fly.binary.swf.tags.soundClasses.errors.NotEnoughBytesError;
	import fly.binary.swf.tags.tagClasses.TagNames;
	import fly.sound.events.SoundBufferEvent;
	import fly.sound.events.TitleChangeEvent;
	import fly.sound.shoutcast.ShoutcastResponseHeader;
	
	/**
	 * Dispatched when the socket is closed.
	 */
	[Event(name="close", type="flash.events.Event")]
	
	/**
	 * Dispatched when a socket throws an ioError
	 */
	[Event(name="ioError", type="flash.events.IOErrorEvent")]
	
	/**
	 * Dispatched when the socket throws a security error
	 */
	[Event(name="securityError", type="flash.events.SecurityErrorEvent")]
	
	/**
	 * Dispatched when buffering is complete and the sound starts playing. 
	 * When this event has fired the sound and soundChannel properties are 
	 * available.
	 */
	[Event(name="complete", type="flash.events.Event")]
	
	/**
	 * Dispatched when the stream is buffering. Bytesloaded gives 
	 * the amount of mp3Frames in the buffer and bytesTotal is 
	 * the value of 'framePerSWF'.
	 * 
	 * @see #framePerSWF
	 */
	[Event(name="progress", type="flash.events.ProgressEvent")]
	
	/**
	 * Dispatched if the header is received from the server
	 */
	[Event(name="httpStatus", type="flash.events.HTTPStatusEvent")]	
	
	/**
	 * Dispatched when the title has changed. Timing of this event is not 
	 * very precise. On top of that, some streams dispatch the title at 
	 * regular intervals instead of once when the song changes.
	 */
	[Event(name="titleChange", type="fly.sound.events.TitleChangeEvent")]
		
	/**
	 * Dispatched when the actual sound buffer is empty. If you get this 
	 * event alot, raise the soundBufferSize property.
	 * 
	 * @see #soundBufferSize
	 */
	[Event(name="bufferEmpty", type="fly.sound.events.SoundBufferEvent")]	
	
	/**
	 * This event is dispatched only when the soundBufferSize property is 
	 * set.
	 */
	[Event(name="buffering", type="fly.sound.events.SoundBufferEvent")]	
	
	/**
	 * This class allows you to play a shoutcast stream.
	 * 
	 * @see #playStream()
	 * @see #stopStream()
	 */
	public class MP3StreamPlayer extends EventDispatcher
	{
		static private const _samples:uint = 8192;
		//each sample part is 8 bytes (2 floats)
		static private const _preferedLength:uint = _samples * 8;
		
		//StreamTitle='Gwen - Le Son Fresh'
		static private const _titleExtractor:RegExp = /StreamTitle\='(.*?)(?:'$|';)/i;
		
		static private var _showFrame:Tag;
		static private var _endFrame:Tag;
		{
			_showFrame = new Tag();
			_showFrame.name = TagNames.SHOW_FRAME;
			
			_endFrame = new Tag();
			_endFrame.name = TagNames.END;			
		}
		
		/**
		 * The amount of mp3 frames that will be written to each swf. Make sure 
		 * this value is larger then 2 times the overlap.
		 * <p />
		 * If you lower this value, more swf's need to be generated, but the 
		 * time it takes to extract the sound from each swf will go down.
		 * <p />
		 * This value can be seen as the primary buffer.
		 * <p />
		 * If the sound is not buffering good enough you can enable the soundBuffer
		 * 
		 * @see #soundBuffer
		 *  
		 * @default 250 
		 */
		public var framesPerSWF:uint;
		
		/**
		 * If you set this propery, the actual playing of the sound will start after the 
		 * actual sound buffer contains the given amount of entries.
		 * <p />
		 * Set this property if you get alot of BufferEvent.BUFFER_EMPTY events.
		 * <p />
		 * Raising this property will increase the delay between buffering and playing.
		 * 
		 */
		public var soundBufferSize:uint;
		
		private var _overlap:uint;
		
		private var _foundHeader:Boolean;
		private var _foundMP3Start:Boolean;
		
		private var _socket:Socket;
		private var _socketRequest:SocketHTTPRequest;
		
		private var _loader:Loader;
		
		private var _mp3Frames:Array;
		private var _streamBuffer:SWFByteArray;
		private var _soundBuffer:Array;
		
		private var _lastSoundBytes:ByteArray;
		private var _sound:Sound;
		private var _soundChannel:SoundChannel;
		
		private var _isPlaying:Boolean;

		private var _byteCounter:uint;
		private var _metadataInterval:uint;
		
		private var _responseHeader:ShoutcastResponseHeader;
		
		private var _titleChanged:Boolean;
		private var _title:String;
		
		public function MP3StreamPlayer()
		{
			_initialize();		
		}

		private function _initialize():void
		{
			_overlap = 7;
			framesPerSWF = 250;
			
			_socket = new Socket();
			_socket.addEventListener(Event.CONNECT, _socketConnectHandler);
			_socket.addEventListener(ProgressEvent.SOCKET_DATA, _progressHandler);
			_socket.addEventListener(IOErrorEvent.IO_ERROR, _socketIOErrorHandler);
			_socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, _socketSecurityErrorHandler);
			
			_streamBuffer = new SWFByteArray();
			_mp3Frames = new Array();
			_soundBuffer = new Array();
			
			_sound = new Sound();
			_sound.addEventListener(SampleDataEvent.SAMPLE_DATA, _sampleDataHandler);
		}

		/**
		 * Starts the process of playing a stream. The sound will start to play as soon as 
		 * the complete event is fired.
		 */
		public function playStream(streamURL:String):void
		{
			if (_socket.connected)
			{
				stopStream();
			}
			
			var urlRequestHeader:URLRequestHeader = new URLRequestHeader("Icy-Metadata", "1");
			
			var urlRequest:URLRequest = new URLRequest(streamURL);
			urlRequest.method = URLRequestMethod.GET;
			urlRequest.requestHeaders = [urlRequestHeader];
			
			_socketRequest = SocketHTTPRequest.createInstanceFromURLRequest(urlRequest);
			
			_socket.connect(_socketRequest.baseURL, _socketRequest.port);
		}
		
		/**
		 * Stops playing the stream
		 */
		public function stopStream():void
		{
			_foundHeader = false;
			_foundMP3Start = false;
			_socket.close();
			_socketRequest = null
			_mp3Frames.splice(0);
			_streamBuffer = new SWFByteArray();
			_soundBuffer.splice(0);
			_lastSoundBytes = null;
			//_sound = null;
			if (_soundChannel)
			{
				_soundChannel.stop();
				_soundChannel = null;
			}
			_isPlaying = false;
			_byteCounter = 0;
			_metadataInterval = 0;
			_responseHeader = null;
			_titleChanged = false;
			_title = null;
		}
		
		private function _socketConnectHandler(e:Event):void
		{
			_socket.writeBytes(_socketRequest.constructRequest());
			_socket.flush();
		}
		
		private function _progressHandler(e:ProgressEvent):void
		{
			_streamBuffer.clearBitBuffer();
			
			if (_metadataInterval)
			{
				_byteCounter += _socket.bytesAvailable;
			}
			
			_socket.readBytes(_streamBuffer, _streamBuffer.length, _socket.bytesAvailable);
			
			var buffering:Boolean = _checkMetadata();
			
			if (buffering)
			{
				return;
			}
			
			_streamBuffer.position = 0;
			
			if (_foundHeader)
			{
				if (_foundMP3Start)
				{
					_gatherMP3Data();
				} else
				{
					_findMP3DataStart();
				}
			} else
			{
				_findHeader();
			}
			
			if (!_isPlaying && !_soundBuffer.length && !_loader)
			{
				var progressEvent:ProgressEvent = new ProgressEvent(ProgressEvent.PROGRESS, false, false, _mp3Frames.length, framesPerSWF);
				dispatchEvent(progressEvent);
			}
		}
		
		private function _checkMetadata():Boolean
		{
			var buffering:Boolean;
			
			if (_foundHeader && _metadataInterval)
			{
				if (_byteCounter > _metadataInterval + 1)
				{
					var position:uint = _metadataInterval + (_streamBuffer.length - _byteCounter);
					_streamBuffer.position = position;
					var length:uint = _streamBuffer.readUnsignedByte() * 16;
					
					if (length)
					{
						if (_streamBuffer.length >= position + 1 + length)
						{
							var title:String = _streamBuffer.readUTFBytes(length);
							title = _titleExtractor.exec(title)[1];
							_titleChanged = (title != _title);
							_title = title;
						} else
						{
							buffering = true;
						}
					}

					if (!buffering)
					{
						_streamBuffer.position = 0;
						
						var temp:SWFByteArray = new SWFByteArray();
						//read the first part
						_streamBuffer.readBytes(temp, 0, position);
						_streamBuffer.position = position + length + 1;
						//read the second part
						_streamBuffer.readBytes(temp, temp.length);
						
						_streamBuffer = temp;
						
						_byteCounter -= _metadataInterval + length + 1;
					}
				} else
				{
					buffering = true;
				}
				
				if (!buffering && _byteCounter > _metadataInterval + 1)
				{
					_checkMetadata();
				}	
			}
			
			return buffering;
		}
		
		private function _findHeader():void
		{
			var headerEndMarker:String;
			
			while (_streamBuffer.bytesAvailable > 3)
			{
				headerEndMarker = _streamBuffer.readUTFBytes(4);
				
				if (headerEndMarker == HTTP_SEPARATOR + HTTP_SEPARATOR)
				{
					_foundHeader = true;
					
					var headerEndPosition:uint = _streamBuffer.position;
					
					_streamBuffer.position = 0;
					
					var header:String = _streamBuffer.readUTFBytes(headerEndPosition);
					
					_responseHeader = new ShoutcastResponseHeader(header);
					
					var httpStatusEvent:HTTPStatusEvent = new HTTPStatusEvent(HTTPStatusEvent.HTTP_STATUS, false, false, _responseHeader.status);
					dispatchEvent(httpStatusEvent);
					
					if (_responseHeader.status != 200)
					{
						_socket.close();
						return;
					}
					
					//remove the read bytes
					var rest:SWFByteArray = new SWFByteArray();
					_streamBuffer.readBytes(rest);
					
					_streamBuffer = rest;
					
					if (_responseHeader.headerObject.hasOwnProperty("icy-metaint"))
					{
						_metadataInterval = parseInt(_responseHeader.headerObject["icy-metaint"]);
						_byteCounter = _streamBuffer.length;
					}
					
					break;
				}
				_streamBuffer.position -= 3;
			}
		}
		
		private function _findMP3DataStart():void
		{
			/*
				In this method we check if we can find 2 frames in a row. This 
				is done in order to make sure we get actual frames and not a 
				piece of sound that accidentally has the correct bytes.
			*/
			var mp3Frame1:MP3Frame;
			var mp3Frame2:MP3Frame;
			var originalPosition:uint;
			
			while (_streamBuffer.bytesAvailable > 1)
			{
				originalPosition = _streamBuffer.position;
				
				try
				{
					mp3Frame1 = new MP3Frame();
					mp3Frame1.readFrom(_streamBuffer);

					if (_streamBuffer.bytesAvailable < 2)
					{
						throw new NotEnoughBytesError("Not enough bytes available to search for second frame");
					}
					
					mp3Frame2 = new MP3Frame();
					mp3Frame2.readFrom(_streamBuffer);
					
					if (mp3Frame1.bitrate != mp3Frame2.bitrate ||
						mp3Frame1.mpegVersion != mp3Frame2.mpegVersion ||
						mp3Frame1.channelMode != mp3Frame2.channelMode ||
						mp3Frame1.layer != mp3Frame2.layer ||
						mp3Frame1.samplingRate != mp3Frame2.samplingRate)
					{
						throw new InvalidBitrateError("Both frames are not compatible");
					}
					
					//remove the bytes up to the original position
					_streamBuffer.position = originalPosition;
					
					var rest:SWFByteArray = new SWFByteArray();
					_streamBuffer.readBytes(rest);
					_streamBuffer = rest;
					
					_foundMP3Start = true;
					
					break;
				} catch (e:NotEnoughBytesError)
				{
					//we need to wait for more bytes
					_streamBuffer.position = originalPosition;
					break;
				} catch (e:InvalidHeaderStart)
				{
					_streamBuffer.position = originalPosition + 1;
				} catch (e:InvalidSamplingRateError)
				{
					_streamBuffer.position = originalPosition + 1;
				} catch (e:InvalidMPEGVersionError)
				{
					_streamBuffer.position = originalPosition + 1;
				} catch (e:InvalidBitrateError)
				{
					_streamBuffer.position = originalPosition + 1;
				}
			}			
		}
		
		private function _gatherMP3Data():void
		{
			var originalPosition:uint;
			var mp3Frame:MP3Frame;
			
			while (_streamBuffer.bytesAvailable > 2)
			{
				originalPosition = _streamBuffer.position;
				
				mp3Frame = new MP3Frame();
				
				try
				{
					mp3Frame.readFrom(_streamBuffer);
					_mp3Frames.push(mp3Frame);
				} catch (e:InvalidHeaderStart)
				{
					/*
						Sometimes we suddenly encounter a bad frame. Usually this is 
						caused by some kind of commercial at the start of the stream.
					*/
					_streamBuffer.position = originalPosition + 1;
				} catch (e:NotEnoughBytesError)
				{
					//we need to wait for more bytes
					_streamBuffer.position = originalPosition;
					break;
				}
			}				

			//remove the rest of the bytes
			var rest:SWFByteArray = new SWFByteArray();
			_streamBuffer.readBytes(rest);
			_streamBuffer = rest;
			
			//if we have enough frames, create a new SWF
			if (_mp3Frames.length >= framesPerSWF)
			{
				var swfByteArray:SWFByteArray = _createSWF(_mp3Frames.slice(0, framesPerSWF));
				
				_mp3Frames.splice(0, framesPerSWF - _overlap * 2);
				
				_loadSoundSWF(swfByteArray);
			}
		}
		
		private function _loadSoundSWF(swfByteArray:SWFByteArray):void
		{
			_loader = new Loader();
			_loader.contentLoaderInfo.addEventListener(Event.COMPLETE, _loaderCompleteHandler);
			
			var loaderContext:LoaderContext = new LoaderContext();
			if (Capabilities.playerType == "Desktop")
			{
				loaderContext.allowLoadBytesCodeExecution = true;
			}
			
			_loader.loadBytes(swfByteArray, loaderContext);			
		}
		
		private function _loaderCompleteHandler(e:Event):void
		{	
			var soundClass:Class = Class(_loader.contentLoaderInfo.applicationDomain.getDefinition("fly.assets.SoundAsset"));
			_parseSound(soundClass);
		}
		
		private function _parseSound(soundClass:Class):void
		{
			var sound:Sound = new soundClass();
			
			var samplesRead:uint;
			// 1152 is the samples per frame for MPEG 1
			var samplesToCut:uint = 1152 * _overlap;
			
			if (_lastSoundBytes && _lastSoundBytes.length < _preferedLength)
			{
				//we need to add bytes to the last sample
				_lastSoundBytes.position = _lastSoundBytes.length;
				//we do not extract the first frame
				samplesRead = sound.extract(_lastSoundBytes, _samples - (_lastSoundBytes.length / 8), samplesToCut);
			} else
			{
				//read all bytes
				_lastSoundBytes = new ByteArray();
				//we do not extract the first frame
				samplesRead = sound.extract(_lastSoundBytes, _samples, samplesToCut);
			}
			
			while (_lastSoundBytes.length == _preferedLength)
			{
				_soundBuffer.push(_lastSoundBytes);

				_lastSoundBytes = new ByteArray();
				samplesRead = sound.extract(_lastSoundBytes, _samples);
				
				if (samplesRead < _samples)
				{
					//we need to remove the last frame
					
					var bytesToRemove:uint = samplesToCut * 8;
					
					if (_lastSoundBytes.length < bytesToRemove)
					{
						//we can not remove enough samples, so we need to get the last one and remove them there
						bytesToRemove -= _lastSoundBytes.length;
						_lastSoundBytes = ByteArray(_soundBuffer.pop());
					}
					
					var temp:ByteArray = new ByteArray();
					_lastSoundBytes.position = 0;
					_lastSoundBytes.readBytes(temp, 0, _lastSoundBytes.length - bytesToRemove);
					_lastSoundBytes = temp;
				}
			}
			
			_loader.unload();
			_loader = null;
			
			if (!_isPlaying)
			{
				if (_soundBuffer.length > soundBufferSize)
				{
					_isPlaying = true;
					//wait 200 miliseconds to ease the load on the CPU
					setTimeout(_startPlaying, 200);
				} else
				{
					dispatchEvent(new SoundBufferEvent(SoundBufferEvent.BUFFERING, false, false, _soundBuffer.length, soundBufferSize));
				}
			}
			
			if (_titleChanged)
			{
				_titleChanged = false;
				dispatchEvent(new TitleChangeEvent(TitleChangeEvent.TITLE_CHANGE, false, false, _title));
			}
		}
		
		private function _startPlaying():void
		{
			_soundChannel = _sound.play(0);
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		private function _sampleDataHandler(e:SampleDataEvent):void
		{
			if (_soundBuffer.length)
			{
				e.data.writeBytes(ByteArray(_soundBuffer.shift()));
			} else
			{
				_soundChannel = null;
				_isPlaying = false;
				dispatchEvent(new SoundBufferEvent(SoundBufferEvent.BUFFER_EMPTY));
			}
		}
		
		private function _socketCloseHandler(e:Event):void
		{
			var closeEvent:Event = new Event(Event.CLOSE);
			
			dispatchEvent(closeEvent);
		}
		
		private function _socketIOErrorHandler(e:IOErrorEvent):void
		{
			if (hasEventListener(IOErrorEvent.IO_ERROR))
			{
				dispatchEvent(e);
			} else
			{
				throw new Error("MP3StreamPlayer: unhandled IOErrorEvent #" + e.text + ": " + e.text);
			}
		}		
		
		private function _socketSecurityErrorHandler(e:SecurityErrorEvent):void
		{
			if (hasEventListener(SecurityErrorEvent.SECURITY_ERROR))
			{
				dispatchEvent(e);
			} else
			{
				throw new Error("MP3StreamPlayer: unhandled SecurityError #" + e.text + ": " + e.text);
			}
		}		
		
		private function _createSWF(mp3Frames:Array):SWFByteArray
		{
			var swfByteArray:SWFByteArray;
			
			swfByteArray = new RawSWFData();
			swfByteArray.position = swfByteArray.length;
			
			var defineSoundTag:Tag = _createDefineSoundTag(mp3Frames);
			defineSoundTag.writeTo(swfByteArray);
			
			_showFrame.writeTo(swfByteArray);
			_endFrame.writeTo(swfByteArray);
			
			//write the size
			swfByteArray.position = 4;
			swfByteArray.writeUnsignedInt(swfByteArray.length);
			
			swfByteArray.position = 0;
			
			return swfByteArray;			
		}
		
		private function _createDefineSoundTag(mp3Frames:Array):Tag
		{
			var tag:Tag = new Tag();
			tag.name = TagNames.DEFINE_SOUND;
			
			var defineSound:DefineSound = new DefineSound();
			defineSound.soundID = 1;
			defineSound.soundFormat = SoundInformation.FORMAT_MP3;
			defineSound.soundRate = SoundInformation.RATE_WHOLE;
			defineSound.soundSize = SoundInformation.SIZE_16_BIT;
			defineSound.soundType = SoundInformation.TYPE_STEREO;

			
			var mp3SoundData:MP3SoundData = new MP3SoundData();
			mp3SoundData.mp3Frames = mp3Frames;
			mp3SoundData.seekSamples = 0;
			
			defineSound.soundData = mp3SoundData;
			
			tag.tagContent = defineSound;
			
			return tag;
		}
		
		/**
		 * The actual MP3 data is not bound to a single MP3 frame, but overlaps 
		 * multiple frames. For this reason we need to write more bytes to an 
		 * swf than we actually use. This variable determines the overlap.
		 * <p />
		 * Raising the overlap helps removing strange clicks.
		 * <p />
		 * You can not set the overlap higher then 7.
		 * 
		 * @default 7 
		 */
		public function get overlap():uint
		{
			return _overlap;
		}
		
		public function set overlap(overlap:uint):void
		{		
			if (overlap < 8)
			{
				_overlap = overlap;
			} else
			{
				throw new Error("MP3StreamPlayer: can not have an overlap greater then 7");
			}
		}
		
		/**
		 * A reference to the sound object playing the sound. This reference is available 
		 * after the complete event has fired.
		 */
		public function get sound():Sound
		{
			return _sound;
		}
		
		/**
		 * A reference to the sound channel returned from calling 
		 * the play method. This reference is available 
		 * after the complete event has fired.
		 */
		public function get soundChannel():SoundChannel
		{
			return _soundChannel;
		}
		
		/**
		 * A reference to the response header received from the shoutcast server. This reference is available 
		 * after the complete event has fired.
		 */
		public function get responseHeader():ShoutcastResponseHeader
		{
			return _responseHeader;
		}
	}		
}

import flash.utils.ByteArray;

class SoundBufferEntry
{
	public var bytes:ByteArray;
	public var isSplit:Boolean;
}

class SoundSWF
{
	public var bytes:ByteArray;
	public var soundClass:Class;
}