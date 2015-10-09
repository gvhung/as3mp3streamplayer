MP3 Streams in Flash

[Questions](Questions.md)

# The problem #

It is very easy to load an MP3 stream into Flash:

```
var sound:Sound = new Sound();
sound.load(new URLRequest("http://mystream"));
sound.play(0);
```

After a while however you will notice that the memory of you player will keep rising. This is because the Flash player will see the given url as a regular MP3 file. It will just load it in indefinately.


# The solution #

The easiest solution would be to stream the sound using the rtmp protocol. You would need a Flash Media kind of server to convert the MP3 stream to the rtmp protocol. The problem here is that all trafic generated would have to come through your server.

The process this player uses is a bit more complicated. The global steps (more detailed steps later):

## 1. Get the MP3 data in usable chunks ##

MP3 data is split into MP3 frames. These frames contain information over the sound they contain. An MP3 file or MP3 stream is nothing more then a collection of these frames. Thanks to the swf file format specification I was able to extract the information of these frames.

## 2. Compile a collection of MP3 frames into an swf ##

The only way to get dynamically generated content into the Flash player is by loading an swf. With the help of the swf file format specification I was able to generate an swf containing the MP3 sound data.

This swf could then be loaded in with the _loader.loadBytes_ method.

## 3. Extracting the sound ##

We can instantiate the sound asset from the loaded swf and start playing it. This however would not work very well as there is no way to glue these sound instances together. The SoundComplete event is too unreliable and not fast enough.

Flash player 10 introduced the sound.extract method which allows you to extract uncompressed sound data. This data can then be cut into pieces and fed to the SampleDataEvent.

The problem that arises here is that it will generate hickups in the sound. Apparently the actual sound data of an MP3 is not contained within one MP3 frame. The sound data needs information of previous frames.

To solve this problem more MP3 frames are added to start and end of the swf's sound data. This creates an overlap. Then during the extraction of the sound, these extra samples are cut off in order to get a blipfree sound.


## Detailed steps ##

1. Make a connection to the shoutcast server using the Socket class
2. Send a header indicating we can parse shoutcast metadata
3. Parse the metadata to figure out what the interval of the metadata is
4. Within the progress handler strip out the metadata
5. Parse MP3 frames from the raw bytes
6. When there are enough MP3 frames compile them into an swf
7. Load the swf
8. Instantiate the sound class and extract the uncompressed sound data
9. Feed the sound data to the SampleDataEvent
10. Repeat from step 4