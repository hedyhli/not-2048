# Not 2048

This is not 2048.

Just me attempting to "clone" a game I found to remove the ads.

This is legal, because none of my implementations can come close to being as
good as the original.

Look how crude it is right now:

<img src="https://raw.githubusercontent.com/hedyhli/not-2048/main/love.png" width=300/>

A rewrite into Fennel **is planned**, don't worry.

## The game

As I've repeated stated, this is **not 2048**.

There are several columns, you are not allowed to swipe horizontally or
vertically to move pieces ("tiles"). On each next tile that comes, you pick a
column for it to go. It is placed at the bottom of the tile.

Like-tiles (ones of the same value) can merge into twice of their initial
values. The game ends when you've used all rows of all columns.

There are also other ways for tiles to merge, such as horizontally (yes, across
columns, but you can't do that manually), and a three-way merge (no, this is
neither 2048 nor Git).

It's a very interesting concept; admittedly, not one I'd have thought of myself.
However, the original game is riddled[^1] with ads, like most software nowadays;
so I seized the opportunity to not only figure out how it works by implementing
it myself, but also [learn a whole bunch of other
frameworks](https://github.com/hedyhli/todomvc-tui) along the way.


[^1]: I found this use of the word quite intriguing. It's to be credited to:
[This article about Rust & Vlang community
drama](https://web.archive.org/web/20231122124218/http://asvln.com/rants/pathetic.html)
which ThePrimeagen has a reaction video of, who has also gave some emphasis to
the word in his "analyses".
