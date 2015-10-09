# Introduction #
There can be trouble with SWC file to load in into Flash CS4, as i had.
Therefore this guide. Hopefully this will help you out.
It should include all classes in you project so you can get up and run.
There is already a tutorial how to load SWC library file into Flash CS4 but as for me,
it created more problems than solutions.

# Details #

Step by Step:

1. Download **completeSourceClasses.rar** AND **AS3MP3StreamPlayer.swc** from download directory and **Flex SDK** at http://download.macromedia.com/pub/flex/sdk/flex_sdk_3.zip

2. Open your **completeSourceClasses.rar** Rar file and extract everything into this directory:
C:\Documents and Settings\{User}\{Local Settings}\Application Data\Adobe\Flash CS4\en\Configuration\Classes

2.a. You should now have a folder named **fly** among **aso**, **com**, **FP7**, **FP8**, **FP9**, **FP10** and **mx** folders
C:\Documents and Settings\{User}\{Local Settings}\Application Data\Adobe\Flash CS4\en\Configuration\Classes\fly

2.b. Now you should have **fly.sound** and **fly.binary**

3. Open up you Flash CS4 and go to **Edit** -> **Preferences...**

4. In Preferences dialog click on **ActionScript** category and then **ActionScript 3.0 Settings...**

5. In **Flex SDK path** direct it to **flex\_sdk\_3\frameworks\libs** (in the folder you packed up you Flex SDK)
It would then look like this (depending where you have Flex SDK): C:\Program\Adobe\Adobe Flash CS4\Common\Configuration\ActionScript 3.0\libs\flex\_sdk\_3\frameworks\libs

6. In **Library Path** click on SWC file button and direct flash to SWC file you downloaded before. It should then add and pathway looking something like this: C:\Flex Libs\AS3MP3StreamPlayer.swc

7. It should now be Done!