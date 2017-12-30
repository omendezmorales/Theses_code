If you've read my [thesis][t], you'll find that I've come up with a method that identifies code clones with the aid of tools like CC reformer and some perl scripting.

[t]: http://swerl.tudelft.nl/twiki/pub/Main/OrlandoMendez/OrlandoMendez.pdf
__Why__

Code-clone identification is necessary because in OO systems with a (very) big code base, 
tangling or scattering of crosscutting concerns occurs throughout the system -with all the unwanted side-effects associated.
So once these clones are identified, the code lends to refactoring, and thus the resulting system 
is expected to be more understandable, easier to maintain, and potentially easy to reuse.

 // TODO: insert the method I developed to identify clones.
