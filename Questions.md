## Which types of Flash environments will this work in ##

It will work in Flash player 10 stand alone and in Adobe AIR 1.5 (beta available at Adobe opensource).


## Can I use this library in an swf that will play in the browser ##

You can only use this swf in the browser if you control the shoutcast server. The Socket used in the library needs to be granted access. Check out the flash security policy information for more details:

http://www.adobe.com/devnet/flashplayer/articles/fplayer9_security.html


## I have no way of getting a the Socket class to connect to my server, are there alternatives? ##

It is possible to use the URLStream class, which requires (if I am not mistaken) a normal policy file if run from the browser. Switching to the URLStream would mean you would lose the ability to get shoutcast metadata.

The URLStream can not send custom request headers if the request is a GET request. Most shoutcast server can not handle POST requests.

## How can I use this library in Flash CS4? ##

Actually, all you need to do is add the SWC to the ActionScript 3.0 publish settings as a library path.

_Publish settings > Flash > Settings next to ActionScript 3.0 > Library path_

Screenshots can be found here: http://actionscriptexamples.com/2008/10/26/using-the-flex-sdk-with-flash-cs4/


## I noticed you used some classes in your code for which no source code is available, can you explain? ##

The source code for classes in the 'code.google.as3httpclient' package can be found in the as3httpclient project:

http://code.google.com/p/as3httpclient/

The source code for classes in the 'fly.binary.swf' package are from another project I was working on. These classes are not well documented and not complete at time of this release. You can find them in the download section.


## Other questions? ##

Just mail me at my gmail account.