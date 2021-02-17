# Introduction

This package of programs allows the moderation of games of _Flamme
Rouge_ by correspondence. The author has used it to run games on
Discourse and BoardGameGeek.

# Requirements

You'll need these non-core Perl modules:

- Imager
- List::MoreUtils
- YAML::XS

In Debian, install libimager-perl, liblist-moreutils-perl and
libyaml-libyaml-perl.

For `plot` you'll also need `inkscape` installed; it's used to render
SVG icons into bitmaps.

# The programs

Most programs operate on a YAML file. You can give this as a command
line parameter. If you don't, the program will search through the
current directory and use the latest one it can find, working out the
name of the next file if needed. The general format for filenames is
(racenumber).(turnnumber).(actionnumber).yaml

Each YAML file is a snapshot of the entire state of the competition.
All persistent data are stored there.

Because I don't want all these programs sitting on my path, I run them
from the tour directory, as it might be `../plot`. They make
assumptions about this – for example `plot` is expecting to find its
icons in `../icons/`, and most programs load up `../tiles.yaml` for
tile details.

Courses are defined as a series of letters and numbers. a..t and A..T
are the tiles from the base game, in lower and upper
(white-on-black-square) case; _Peloton_ tiles are shown as 1..9 for
the black-on-white side, and ^1..^9 for the white-on-black-square
backs. (The Brettspiel Adventskalendar 2017 promo tile is "%B" for the
plain side, "%C" for the climb side; this hasn't been used in any
published courses and the representation may change.)

## addteam

Adds a team to the tour. Needs:

- -t team name
- -n colour name
- -c optional hex triplet colour rrggbb
- -1 rider 1 type (r, s, p, g)
- -2 rider 2 type

If you don't give a hex triplet, the colour name is looked up first in
the standard Flamme Rouge colours and then in `/etc/X11/rgb.txt`.
(Custom colours may be handy if you have players with colour vision
deficits.)

Rider types r (rouleur) and s (sprinteur) are as in the standard game:
Rouleur has cards 3..7 three times each (75 energy), and Sprinteur has
2..5 and 9 three times each (69 energy). For the Grimpeur and Puncheur
see _Player Briefing_ below.

## analyse

Given either a YAML file with a course defined in it or a course
directly on the command line, prints some information about track
length, amounts of various terrain types, and warnings about areas
where a rider can jump directly from one downhill/supply zone to
another.

## breakaway

Does all the custom breakaway calculations. No special parameters; it
works out from the state of the decks how far things have gone and
what still needs to be done.

## endrace

Does the end-of-race calculations: scores riders for combativity over
the race just finished, counts their exhaustion cards and works out
recovery rates, and stores their exhaustion total.

## energy

Draws energy cards for every active rider. With `-b` does a
second-stage breakaway draw (i.e. only for the one rider per team
who's active even though the others are on the track).

## mover

Does the actual moving of riders. Follows every rule I can find.
Prints various information about what's going on, which the players
will probably want to see.

This will produce up to three YAML files:

- before slipstreaming
- after slipstreaming but before finishers are removed
- start of the next turn

## place

Places a team at the start of a race.

- -t team name
- -r/s/p/g X (use twice): the lettered space where the
  rouleur/sprinteur/puncheur/grimpeur starts

Example: `place -t Roger -r A -s D`

## play

Plays a team's energy cards.

- -t team name
- -r/s/p/g X (use twice): the card to play this turn.

If a team has only one active rider (e.g. in breakaway stage 2 or when
the other has finished) you may use -x to specify "the active rider".

Example: `play -t Roger -r 7 -s 9`

## plot

Draws the map to a png file. (You can give the course as a command
line parameter, in which case the file will be called "naimless.png".)
Also draws weather and rider positions if they're defined.

- -s N - make the standard unit size N pixels. Default 24. A single
  space on a straight track section is 1 unit wide and 2 units long.

If there's a "!colours.yaml" in the current directory, its terrain
entries will be used instead of the master colours.yaml. Probably I'll
move this into the game configuration file eventually.

Once you've got the image file, you'll need to upload it to wherever
the forum expects to find images.

## setuprace

Gets a race ready to start:

- allocates weather
- primes mountain point lists
- builds each rider's deck

## show-energy

Displays each team's hands, wrapped in (details) blocks so that
players don't see them accidentally.

## show-score

Displays current scores in each category, as well as tour point
totals.

- -f calculate TP bonuses for combativity, mountain points and time

## status

Shows who's played and who hasn't. '.' is an unplayed rider; '/' has
finished (or otherwise has no location); 'a' can be played
automatically (hand holds only 2s and Xs).

# Overview

Here's how to use the software to run a Flamme Rouge tour.

* Make a directory for the software, for example `~/flamme-rouge`. Put
  everything in there, svg files under `icons/`.
* Each tour will be a subdirectory off that, so create it and chdir to
  it.
* Get your players.
* For each player: `addteam`
* If running on BGG, add "style: bgg" to the YAML file.
* For each race:
  * Edit the latest YAML to include a `course` entry; pick one of the
    courses from courses.yaml or design your own.
  * `setuprace` which will show the setup order
  * `plot` will show the empty course
  * For each player: `place` their riders, `plot` as needed
  * Run the breakaway:
    * `energy` followed by `show-energy`
    * For each player, `play` their first breakaway card
    * `breakaway` shows the current status. When all have played it'll
      show the results
    * `energy -b`, `show-energy` to get second breakaway hands
    * `play` as before
    * `breakaway` will again show current status, then when you have
      all the card plays in it'll do the move and set things up for
      the first turn of the race
  * For each turn of the race:
    * `plot` then put the image where players can see it
    * `energy` followed by `show-energy`
    * For each player, `play` their cards; `status` shows who's not
      played yet
    * `mover` does the actual moving, and shows a log of what happened
    * That finishes with the number of riders still in the race. If
      there are any left, run another turn.
  * At the end of the race:
    * `endrace` does the bookkeeping and shows exhaustion recovery
    * `show-score` shows the full score to date

# Player briefing

Players need to know these things in addition to the rules of the
game, as well as the contents of _The Grand Tour_ section below.

- As well as rouleur and sprinteur, you can choose from the
  all-rounder puncheur (2,3,5,6,8 three times each for 72 energy) and
  the hill-climber grimpeur (2..4,6,7 three times each for 66 energy,
  but their uphill speed limit is 7 rather than everyone else's 5).

- Uphill, downhill, supply and cobbled areas are shown as solid areas
  of red, dark blue, pale blue and brown respectively.
  
- If all the spaces at the start or end of one of those areas are
  full, an appropriate sign will appear on the right side of the track
  to show just where the special area starts or ends.
  
- Weather (rain, headwind, tailwind, crosswind) is shown with square
  black icons. If riders are on or near the tile where it applies, the
  icon is centred on the leading left corner of the tile, with a black
  bar showing how far the effect extends. Otherwise it's shown
  translucent in the centre of the file.

- To make life easier, each turn you'll see a message containing
  _both_ your riders' hands. It's up to your sense of fair play to
  look at just one of these hands, choose the card you're going to
  play, and only then look at the other one. (And indeed not to look
  at other players' hands.)
  
- A special case of this is the first step of the breakaway, where you
  need to choose which of your riders will be making the break, then
  submit one of their cards. (For the second step, you'll only see
  that rider's hand.)

# The Grand Tour

This section is just for reference so that you know what's going on.
Everything here is handled automatically.

For each race, the first, second and third place finishers get 3, 2
and 1 tour points respectively. At the end of each race, riders retain
half their exhaustion (round up) in their deck for the next race.

Placement order after the first race is the reverse of those placing
points (lowest points places first). Ties are broken in favour of the
team that has the rider with the highest time (see below), then
randomly.

The first rider to leave each contiguous uphill section gets a number
of mountain points (the longer the uphill, the more points are
available). This is done by track order at the end of the turn on
which they crossed the line. Highest mountain point totals at the end
of the tour get 3, 2 and 1 tour points respectively. (Note that the
"U" uphill finish does not allow a rider to leave the uphill, so no
mountain points are scored for it.)

| length | category       | points        |
|--------|----------------|---------------|
| 1-2    | Cat. 4         | 1             |
| 3-5    | Cat. 3         | 2, 1          |
| 6-8    | Cat. 2         | 3, 2, 1       |
| 9-10   | Cat. 1         | 4, 3, 2, 1    |
| 11+    | Hors catégorie | 6, 4, 3, 2, 1 |

A rider who is in the lead (or joint lead) after movement gets a
combativity point. Highest combativity point totals at the end of the
tour get 3, 2 and 1 tour points respectively.

Each turn of riding adds a minute to the rider's time – except the
turn in which they finish, which instead subtracts 10 seconds per
space past the finish line. (The first two riders to finish get a
further 10-second subtraction.) Lowest time totals at the end of the
tour get 3, 2 and 1 tour points respectively.

Ties are broken generously: if two riders share equal top combativity,
both get the 3-point award, and the rider in next place gets the
2-point award.

Total tour points determine the individual winner; tour points
totalled for all riders for a single time determine the team winner.
Individual category winners may also be celebrated.

# For the Future

- bot teams

# Credits and Licence

Flamme Rouge game by Asger Harding Granerud

Grimpeur original design unknown; Puncheur and this version of
Grimpeur by Vincent Joly.
https://boardgamegeek.com/thread/1697244/new-types-riders-brainstorming
https://boardgamegeek.com/thread/1987853/new-rider-grimpeur

Weather icons are originally from game-icons.net: specifically "Windy
Stripes", "Poker Hand" and "Raining", all by Lorc and used under
CC-BY-3.0. Modifications to "Windy Stripes" and "Poker Hand" by Roger
Bell_West are under CC-BY-SA-3.0.
http://creativecommons.org/licenses/by/3.0/

Traffic sign icons (climb, descent, cobbles, "end") are taken from the
UK government document "Know Your Traffic Signs", this being public
sector information licensed under the Open Government Licence v3.0.
The Supply Zone icon is a public-domain image modified and
superimposed onto a UK road sign template from the same document.
http://www.nationalarchives.gov.uk/doc/open-government-licence/version/2/

All code by Roger Bell_West, released under the GNU General Public
Licence (version 3, or any later version at your discretion).
http://www.gnu.org/licenses/gpl.html
