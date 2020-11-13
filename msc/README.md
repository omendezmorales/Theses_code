If you've read my [thesis][t], you'll find that I've come up with a method that identifies code clones with the aid of tools like [CCFinder][cc] and some perl scripting.

[t]: ./Aspect_mining_using_clone_detection_OrlandoMendez_MSc.pdf
[cc]:http://www.ccfinder.net/index.html

__Why__

Code-clone identification is necessary because in OO systems with a (very) big code base, 
tangling or scattering of crosscutting concerns occurs throughout the system -with all the unwanted side-effects associated.
So once these clones are identified, the code lends to refactoring, and thus the resulting system 
is expected to be more understandable, easier to maintain, and potentially easy to reuse.

__How__

In order to identify these code clones, I developed the following method -explained more in detail in section 3.1.2 of my above mentioned thesis:

1) Run CCFinder taking as input a list containing the names of source files we are to analyze
2) Select those clone classes with the highest values in metrics like class population (number of clones from the same type) and spreading ratio of clones (i.e., in which files, directories or packages are the clones located)
3) Further inspect the code fragments fulfilling the previous features to find out their function within the code and what their dependencies are with regards to the elements (methods, attributes, classes, etc.) they interact with.
4) Finally, having analyzed the code in the previous step, decide whether we found an [aspect][a] or not.

[a]:https://en.wikipedia.org/wiki/Aspect-oriented_programming

