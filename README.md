SAPSPLIT <-> ZX2-Chunk

An experimental compression format for use with the Atari 8-bit's POKEY Soundchip.

Based on an idea I once thought of about making use of an hybrid ZX0/ZX2 format that is read in Indexed Chunks using a Lookup Table to reconstruct the original data.
Essentially, the same idea as LZSS, but handled in a very different way, with possibly much higher compression ratio, at the cost of being a lot more complex to use efficiently.

This project could be useful for something requiring very compact data with reasonable CPU usage, I guess.
Otherwise, LZSS should be more than good enough for general uses.

The Sample POKEY Player as well as the Decompression Routines should work mostly fine, there's nothing super fancy in there really.
Everyone is welcome to borrow the code if any use comes up for it, of course.

Some ideas might or might not work, since most of this project is unfinished.
I figured I could at least upload the changes I did before leaving the project in stand-by in the last 2 years.

I am not responsible for anything that could, and will go wrong.
