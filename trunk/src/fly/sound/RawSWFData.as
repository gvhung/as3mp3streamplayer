package fly.sound
{
	import fly.binary.swf.SWFByteArray;

	[Embed(source="rawSWFData.bin", mimeType="application/octet-stream")]
	/**
	 * The data contains the absolute minimum for an swf containing a sound.
	 * <p />
	 * It contains the following tags:
	 * <ul>
	 * 	<li>FILE_ATTRIBUTES</li>
	 * 	<li>DO_ABC (Contains only one empty class (fly.assets.SoundAsset) to which the sound will be bound)</li>
	 * 	<li>SYMBOL_CLASS (Which bounds ID 1 to the class defined in DO_ABC)</li>
	 * <p />
	 * In order to complete this swf and be able to load and extract sound you need to 
	 * do the following:
	 * <ul>
	 *	<li>Add a DEFINE_SOUND tag containing the actual sound data</li> 
	 *	<li>Add a SHOW_FRAME tag</li> 
	 *	<li>Add an END tag</li> 
	 *	<li>Adjust the size int at position 4 (writeUnsignedInt)</li> 
	 * </ul>
	 */
	public class RawSWFData extends SWFByteArray
	{
	}
}