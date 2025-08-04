extensions
[
  csv ;;loading in data for setup and exporting data from runs
  rnd ;;distribution functions
  profiler ;;profiling to detect bottlenecks
  stats ;;beta distribution pdf
  ;;string ;;String functions
  ;rnetlogo
]

__includes
[
  "./helpers/distributions.nls"
  "./coreScripts/initialisation.nls"
  "./coreScripts/withinSeason.nls"
  "./coreScripts/plotter.nls"
]
globals
[
  ;;Patch-sets
  num-islands ;;A single element list with the number of islands
  the-islands ;;Patch-set of all the island patches
  the-sea ;;Patch-set of the sea patches
  the-shore ;; Island patches that border the sea (currrently unused)

  island-id ;;List of ID's for the islands (1 - n; where n is the number of islands); sea is 0.
  colonies ;;list of patchsets for each island

  pred-islands
  safe-islands

  ;;Agent-sets
  prospective-males ;;list of colony patch-sets that contain the patches with male-count > 0
  breeders ;;turtle-set of all adult birds
  recruits
  new-recruits
  returning-breeders ;; The birds coming back to breed this year....

  ;;Island meta details
  isl-occ ;;the number of breeding bird on each island
  world-occ ;;the number of breeding birds in the world (adult breeders only)
  island-attractiveness ;;weighting for philopatry

  ;;Helpful counts
  adult-pop ;;the total number of adults
  juv-pop ;;the total number ofjuveniles
  pop-size ;;Total population

  philopatry-out ;;Count of birds who failed a philopatry test each year leaving the system
  philo-emigrators ;;Turtle-set of birds that have chosen to emigrate to a new isl or out of system
  emig-out ;;Count of birds leaving due to inability to breed...

  ;;ENSO parameters
  enso-table ;;The table that gets read in with it's headers
  enso-matrix ;;Transition matrix to code for the probability of changing from one state to another
  enso-state ;;The current ENSO state of the system - currently five states

  ;;Census information
  ;;Master list
  island-series

  ;;Sub-lists to be filled each year and bound to master list
  juv-live-isl-counts
  juv-dead-isl-counts
  new-adult-isl-counts
  philo-suc-counts
  philo-fail-counts ;;One longer than # of isls
  emig-att ;;One longer than # of isls
  emig-source-counts ;; The number of birds in the emigration pool from each island
  emig-counts ;;One longer than # of isls
  male-counts
  adult-isl-counts
  breeder-isl-counts
  fledged-isl-counts
  chick-isl-pred
  adult-mort-isl-counts
  adult-isl-pred
  attrition-counts
  prospect-counts
  collapse-counts
  burrow-counts
  isl-attractiveness ;;One longer than # of isls

  lost-males ;;counter for how many unallocated males there are

  ;;Reporter for graphs only
  mating-isl-props

  demography-series
  demography-year
  island-year

  old-pairs
  new-pairs

  ;;Plotting globals
  isl-adult-pen-names
  isl-breed-pen-names
  isl-mating-pen-names
  isl-fledge-pen-names
  isl-burrow-pen-names

  ;;Distribution parameters
  asymp-curve
]


patches-own
[

  ;;SETUP
  ;;initialisation globals for set up
  colony-id
  ;;chick-predation
  ;;prop-suitable
  low-lambda
  high-lambda
  ;;habitat-aggregation
  starting-juveniles
  starting-seabird-pop

  habitable? ;;whether this is a habitable patch (T/F)
  suitable? ;;classifier for whether the patches are particularly suitable for burrows


  ;;Variables that fluctuate during model run
  habitat-attrac ;;the attractiveness of the patch
  occupancy ;;the number of birds in this patch
  occupancy-limit ;;the maximum number of birds the patch can have
  male-count ;;number of males in burrows
  neighbourhood ;;agentset of all patches
  maxK

  predators? ;;whether there are predators in this patch

;  low-k             ;; capacity and
;  low-value-resource  ;; current level of low value resource

;  mh-d
;  on-island?
;  edge-shell        ;; used by irregular island code
]

turtles-own
[

  breeding-grounds ;;patchset of breeding grounds
  breeding-ground-id ;;The location of their breeding ground
  natal-ground-id ;;What island they were born on
  burrow ;;a single patch that this bird last bred at - surrogate for mate with no males present.

  settled? ;;Whether or not this bird has chosen a breeding ground. Happens once birds recruit and is constant unless an individual has x unsuccessful breeding seasons
  breeding? ;;Whether or not it has found a patch within the colony (reset yearly)
  mating? ;;Whether or not a bird has successfully established a burrow with a 'male' this season
  return? ;; Logical indicating which birds are returning and which are not - refreshes every season

  age ;;numeric counting the age of individuals
  life-stage ;;Juvenile/Adults
  time-since-breed ;;counter for how long it has been since the bird has bred.
  emigration-attempts ;;How many times they have swapped islands

  last-breeding-success? ;;T/F indicating whether their last breeding attempt was successful or unsuccessful



]

breed ; convience name
[
  females female ;female birds
]


to setup

  clear-all
  reset-ticks

  ;;Checking if it is a nlrx run or not as the seed will be set by nlrx if it is
  if not nlrx? and not behav?
   [

  ;;Setting seed specified by user...
  ifelse is-number? seed-id
    [
      random-seed seed-id
    ]
    ;;or use a random one if undefined...
    [
      set seed-id new-seed
      random-seed seed-id
    ]

  ]
  ;;Default values for patches
  init-patches

  ;;Reading in the data for the islands and creating them
  init-isl-from-file

  ;;Set up for seabirds
  init-adults
  assign-burrows
  init-juveniles

  ;;Climate variation in mortality and breeding success
  if enso?
  [
    init-enso
  ]

  ;;Custom plot setups
  init-by-isl-plots

  ;;Initialising column headers for data extraction
  ;if capture-data?
  ;[
   init-census-data
  ;]


  set pop-size []

end

to go

  while [ count turtles > 0 ]
  [
    step
  ]
end

to step

  if profiler? [ profiler:start ]

  if print-stage? [ show "Recruitment" ]
  recruit ;;adding new individuals
  ;; set deomg-yr lput x demog-yr

  if print-stage? [ show "Philopatry check" ]
  philopatry-check ;;checking if new recruits are natal ground bound

  if print-stage? [ show "Emigration" ]
  emigrate ;;potentially abandoning patches

 if print-stage? [  show "Burrowing" ]
  burrowing ;;males spread across patches (multi-nomial draw)

  if print-stage? [ show "Mating" ]
  find-mate ;;females find a 'male' and settle down in a patch

  if print-stage? [ show "Hatching-Fledging" ]
  hatching-fledging ;;this stage includes chick mortality - To do: create data output list for each island

  if print-stage? [ show "Adult Death" ]
  mortality ;;Killing off some proportion of the adults

  if print-stage? [ show "New Year" ]
  season-reset

  tick

  if profiler?
  [
    profiler:stop          ;; stop profiling
    print profiler:report  ;; view the results
    profiler:reset         ;; clear the data
  ]
end


to-report patch-occ
  report [ occupancy ] of patch-here / [ maxK ] of patch-here
end

to-report hab-quality
  report [ occupancy-limit ] of patch-here / [ maxK ] of patch-here
end

to-report local-occ
  report (mean[ occupancy ] of neighbourhood) / [ maxK ] of patch-here
end
@#$#@#$#@
GRAPHICS-WINDOW
690
10
1203
524
-1
-1
5.0
1
10
1
1
1
0
0
0
1
0
100
0
100
1
1
1
ticks
30.0

BUTTON
695
530
759
563
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
775
530
838
563
Go
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
10
425
190
458
female-philopatry
female-philopatry
0
1
0.95
0.01
1
NIL
HORIZONTAL

SLIDER
15
185
190
218
adult-mortality
adult-mortality
0
1
0.05
0.01
1
NIL
HORIZONTAL

SLIDER
15
105
190
138
juvenile-mortality
juvenile-mortality
0
1
0.65
0.01
1
NIL
HORIZONTAL

SLIDER
15
25
190
58
chick-mortality
chick-mortality
0
1
0.4
0.01
1
NIL
HORIZONTAL

SLIDER
10
385
190
418
age-at-first-breeding
age-at-first-breeding
0
12
6.0
1
1
NIL
HORIZONTAL

SLIDER
15
645
187
678
max-tries
max-tries
1
10
6.0
1
1
NIL
HORIZONTAL

PLOT
1485
200
1865
370
Proportion Mating
Ticks
Proportion
0.0
1.0
0.0
1.0
true
true
"" "isl-mating-plot"
PENS

MONITOR
1210
60
1307
105
Mating Females
count breeders with [ mating? ]
0
1
11

SWITCH
1270
595
1372
628
debug?
debug?
1
1
-1000

SLIDER
15
605
187
638
nhb-rad
nhb-rad
1
5
4.0
1
1
NIL
HORIZONTAL

SLIDER
15
265
190
298
max-age
max-age
1
100
28.0
1
1
NIL
HORIZONTAL

PLOT
1210
110
1475
250
Age histogram
Age
Frequency
6.0
40.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [age] of turtles"

SLIDER
15
305
190
338
old-mortality
old-mortality
0
1
0.8
0.01
1
NIL
HORIZONTAL

SLIDER
10
465
190
498
prop-returning-breeders
prop-returning-breeders
0
1
0.85
0.01
1
NIL
HORIZONTAL

SLIDER
15
65
187
98
chick-mortality-sd
chick-mortality-sd
0
2
0.1
0.01
1
NIL
HORIZONTAL

SWITCH
1270
635
1372
668
verbose?
verbose?
1
1
-1000

BUTTON
855
530
910
563
Step
step
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1210
10
1307
55
# Adults
count turtles with [ life-stage = \"Adult\" ]
0
1
11

SLIDER
215
500
387
533
emigration-timer
emigration-timer
1
10
4.0
1
1
NIL
HORIZONTAL

SWITCH
1130
635
1233
668
profiler?
profiler?
1
1
-1000

SWITCH
695
570
815
603
capture-data?
capture-data?
0
1
-1000

SWITCH
1130
555
1255
588
update-colour?
update-colour?
1
1
-1000

SLIDER
215
380
387
413
raft-half-way
raft-half-way
0
500
500.0
5
1
NIL
HORIZONTAL

SWITCH
440
255
540
288
collapse?
collapse?
0
1
-1000

SLIDER
215
420
387
453
emigration-curve
emigration-curve
0
2
0.05
0.25
1
NIL
HORIZONTAL

SWITCH
440
140
540
173
prospect?
prospect?
0
1
-1000

BUTTON
1270
555
1350
588
NIL
set-defaults
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
215
580
353
625
isl-att-curve
isl-att-curve
"uniform" "linear" "asymptotic" "sigmoid" "beta1" "beta2"
5

SLIDER
215
460
387
493
emig-out-prob
emig-out-prob
0
1
0.8
0.05
1
NIL
HORIZONTAL

INPUTBOX
440
435
675
500
initialisation-data
./data/recolonisation_analysis/0_starting.csv
1
0
String

PLOT
1486
8
1866
193
Island Adult Counts
Ticks
Number of Seabirds
0.0
10.0
0.0
10.0
true
true
"" "isl-adult-plot"
PENS

MONITOR
1320
10
1397
55
# Juveniles
count turtles with [ life-stage = \"Juvenile\" ]
17
1
11

SLIDER
215
540
385
573
emigration-max-attempts
emigration-max-attempts
1
5
2.0
1
1
NIL
HORIZONTAL

PLOT
1486
553
1866
728
Chicks Fledged
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" "isl-fledge-plot"
PENS

MONITOR
1320
60
1477
105
Emigrants Leaving System
emig-out
17
1
11

PLOT
1486
378
1866
543
Island Breeding Attempts
Number of Breeders Attempting
NIL
0.0
10.0
0.0
10.0
true
true
"" "isl-breed-plot"
PENS

INPUTBOX
820
570
1010
630
output-file-name
./output/test.csv
1
0
String

BUTTON
925
530
1002
563
Save file
csv:to-file output-file-name island-series
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
1130
540
1230
566
Systems checks
12
0.0
1

TEXTBOX
445
415
595
433
System Creation\n
12
0.0
1

TEXTBOX
15
365
165
383
Seabird Recruitment\n
12
0.0
1

TEXTBOX
215
365
360
383
Emigration
12
0.0
1

TEXTBOX
15
590
165
608
Mate Finding\n
12
0.0
1

SLIDER
15
225
187
258
adult-mortality-sd
adult-mortality-sd
0
1
0.01
0.01
1
NIL
HORIZONTAL

SLIDER
15
145
187
178
juvenile-mortality-sd
juvenile-mortality-sd
0
1
0.05
0.01
1
NIL
HORIZONTAL

INPUTBOX
820
635
1010
695
behav-output-path
./output/recolonisation_analysis/
1
0
String

SWITCH
215
175
318
208
enso?
enso?
0
1
-1000

INPUTBOX
215
215
390
275
enso-breed-impact
[0.5 0.2 0 0.2 0.5]
1
0
String

TEXTBOX
320
175
435
205
Added ENSO mortality \n(LN LNL N ENL EN)
11
0.0
1

INPUTBOX
215
280
390
340
enso-adult-mort
[0.25 0.1 0 0.1 0.25]
1
0
String

PLOT
1210
255
1475
390
ENSO States
Ticks
ENSO State
0.0
10.0
0.0
4.0
true
false
"" ""
PENS
"default" 1.0 0 -12345184 true "" "plot enso-state"

INPUTBOX
820
700
1010
760
nlrx-id
NIL
1
0
String

SWITCH
695
700
815
733
nlrx?
nlrx?
1
1
-1000

SWITCH
1130
595
1235
628
print-stage?
print-stage?
1
1
-1000

INPUTBOX
1020
530
1070
590
seed-id
42.0
1
0
Number

SLIDER
440
180
615
213
patch-burrow-limit
patch-burrow-limit
10
300
100.0
5
1
NIL
HORIZONTAL

TEXTBOX
215
160
365
178
ENSO
12
0.0
1

TEXTBOX
445
10
595
28
Habitat
12
0.0
1

SLIDER
440
100
612
133
burrow-attrition-rate
burrow-attrition-rate
0
1
0.2
0.01
1
NIL
HORIZONTAL

SWITCH
440
25
540
58
attrition?
attrition?
0
1
-1000

SLIDER
440
215
615
248
time-to-prospect
time-to-prospect
1
10
2.0
1
1
NIL
HORIZONTAL

SLIDER
440
295
612
328
collapse-half-way
collapse-half-way
10
400
50.0
5
1
NIL
HORIZONTAL

SLIDER
440
330
612
363
collapse-perc
collapse-perc
0
1
0.3
0.01
1
NIL
HORIZONTAL

SLIDER
440
365
612
398
collapse-perc-sd
collapse-perc-sd
0
0.2
0.05
0.01
1
NIL
HORIZONTAL

PLOT
1210
395
1475
525
Burrow Counts
Ticks
# of Burrows
0.0
10.0
0.0
10.0
true
true
"" "isl-burrow-plot"
PENS

SLIDER
440
65
612
98
patch-burrow-minimum
patch-burrow-minimum
0
10
5.0
1
1
NIL
HORIZONTAL

SLIDER
215
65
388
98
chick-predation
chick-predation
0
1
0.0
0.01
1
NIL
HORIZONTAL

SWITCH
695
635
815
668
behav?
behav?
0
1
-1000

SLIDER
215
105
387
138
adult-predation
adult-predation
0
1
0.0
0.01
1
NIL
HORIZONTAL

SLIDER
215
25
387
58
predator-arrival
predator-arrival
0
1000
0.0
5
1
NIL
HORIZONTAL

TEXTBOX
20
10
170
28
Baseline Mortality\n
12
0.0
1

TEXTBOX
220
10
370
28
Predation
12
0.0
1

SLIDER
10
505
190
538
sex-ratio
sex-ratio
0.1
2
1.0
0.01
1
NIL
HORIZONTAL

TEXTBOX
15
540
185
581
1 represents a even sex ratio. Higher values give more males\n
11
0.0
1

SLIDER
440
505
615
538
clust-radius
clust-radius
2
20
10.0
1
1
NIL
HORIZONTAL

SLIDER
440
545
615
578
diffusion-prop
diffusion-prop
0
1
0.4
0.01
1
NIL
HORIZONTAL

SLIDER
440
585
615
618
prop-suitable
prop-suitable
0
1
0.5
0.01
1
NIL
HORIZONTAL

SLIDER
440
625
615
658
habitat-aggregation
habitat-aggregation
0
1
0.2
0.01
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

bird side
false
0
Polygon -7500403 true true 0 120 45 90 75 90 105 120 150 120 240 135 285 120 285 135 300 150 240 150 195 165 255 195 210 195 150 210 90 195 60 180 45 135
Circle -16777216 true false 38 98 14

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="consistency_analysis" repetitions="200" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>step</go>
    <final>behav-csv</final>
    <timeLimit steps="1000"/>
    <enumeratedValueSet variable="nlrx-id">
      <value value="&quot;test&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="age-at-first-breeding">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prospect?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="habitat-aggregation">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isl-att-curve">
      <value value="&quot;beta2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="juvenile-mortality">
      <value value="0.55"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collapse?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prop-returning-breeders">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capture-data?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-prop">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adult-mortality-sd">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emig-out-prob">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="verbose?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attrition?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="raft-half-way">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="behav?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-timer">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="low-lambda">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collapse-half-way">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="behav-output-path">
      <value value="&quot;./output/consistency_analysis/&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chick-mortality">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed-id">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="old-mortality">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prop-suitable">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="starting-juvenile-population">
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-file-name">
      <value value="&quot;./output/test.csv&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collapse-perc-sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-curve">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="predator-arrival">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="juvenile-mortality-sd">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-max-attempts">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-stage?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adult-predation">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update-colour?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="female-philopatry">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chick-mortality-sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chick-predation">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nhb-rad">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-burrow-limit">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adult-mortality">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="starting-adult-population">
      <value value="40000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="high-lambda">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enso?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initialisation-data">
      <value value="&quot;./data/global_sensitivity_analysis/gsa_two_isl_baseline.csv&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-tries">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-age">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="debug?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enso-adult-mort">
      <value value="&quot;[0.02 0.01 0 0.01 0.02]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collapse-perc">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nlrx?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="time-to-prospect">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="burrow-attrition-rate">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-burrow-minimum">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="profiler?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enso-breed-impact">
      <value value="&quot;[0.20 0.1 0 0.1 0.20]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clust-radius">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="enso_analysis" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>step</go>
    <final>behav-csv</final>
    <timeLimit steps="600"/>
    <enumeratedValueSet variable="nlrx-id">
      <value value="&quot;test&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="age-at-first-breeding">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prospect?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="habitat-aggregation">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isl-att-curve">
      <value value="&quot;beta2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="juvenile-mortality">
      <value value="0.55"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collapse?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prop-returning-breeders">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capture-data?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-prop">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adult-mortality-sd">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emig-out-prob">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="verbose?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attrition?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="raft-half-way">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="behav?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-timer">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="low-lambda">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collapse-half-way">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="behav-output-path">
      <value value="&quot;./output/enso_analysis/&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chick-mortality">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed-id">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="old-mortality">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prop-suitable">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="starting-juvenile-population">
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-file-name">
      <value value="&quot;./output/test.csv&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collapse-perc-sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-curve">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="predator-arrival">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="juvenile-mortality-sd">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-max-attempts">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-stage?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adult-predation">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update-colour?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="female-philopatry">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chick-mortality-sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chick-predation">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nhb-rad">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-burrow-limit">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adult-mortality">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="starting-adult-population">
      <value value="40000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="high-lambda">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enso?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initialisation-data">
      <value value="&quot;./data/consistency_analysis/two_isl_baseline.csv&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-tries">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-age">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="debug?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enso-adult-mort">
      <value value="&quot;[0.02 0.01 0 0.01 0.02]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collapse-perc">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nlrx?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="time-to-prospect">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="burrow-attrition-rate">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-burrow-minimum">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="profiler?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enso-breed-impact">
      <value value="&quot;[0.20 0.1 0 0.1 0.20]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clust-radius">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="enso_analysis_2" repetitions="40" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>step</go>
    <final>behav-csv</final>
    <timeLimit steps="600"/>
    <enumeratedValueSet variable="nlrx-id">
      <value value="&quot;test&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="age-at-first-breeding">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prospect?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="habitat-aggregation">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isl-att-curve">
      <value value="&quot;beta2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="juvenile-mortality">
      <value value="0.55"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collapse?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prop-returning-breeders">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capture-data?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-prop">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adult-mortality-sd">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emig-out-prob">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="verbose?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attrition?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="raft-half-way">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="behav?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-timer">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="low-lambda">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collapse-half-way">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="behav-output-path">
      <value value="&quot;./output/enso_analysis/&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chick-mortality">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed-id">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="old-mortality">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prop-suitable">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="starting-juvenile-population">
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-file-name">
      <value value="&quot;./output/test.csv&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collapse-perc-sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-curve">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="predator-arrival">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="juvenile-mortality-sd">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-max-attempts">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-stage?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adult-predation">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update-colour?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="female-philopatry">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chick-mortality-sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chick-predation">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nhb-rad">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-burrow-limit">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adult-mortality">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="starting-adult-population">
      <value value="40000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="high-lambda">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enso?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initialisation-data">
      <value value="&quot;./data/consistency_analysis/two_isl_baseline.csv&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-tries">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-age">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="debug?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enso-adult-mort">
      <value value="&quot;[0.02 0.01 0 0.01 0.02]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collapse-perc">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nlrx?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="time-to-prospect">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="burrow-attrition-rate">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-burrow-minimum">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="profiler?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enso-breed-impact">
      <value value="&quot;[0.20 0.1 0 0.1 0.20]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clust-radius">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
