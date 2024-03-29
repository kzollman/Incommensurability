;; TODO: Comment the code adequately
;; TODO: Use the visuals switch to save time
;; TODO: Fix plots

;; Global variables
;;   bandit-means: a list with the means of each bandit. This is a list of ordered pairs.
;;   bandit-vars: a list with the variance of each bandit
;;   sub-final-performance: this variable is set by go-full, which is used to run
;;                          multiple instances of the model.  This variable respresents
;;                          the final *subjective* performance -- i.e. the performance
;;                          according to each turtle's preferred dimension on the payoff
;;                          vector. This is a mean of that over all runs
;;   sub-final-performance-var: this is the variance from above
;;   obj-final-performances: this variable is also set by go-full.  It is a list which
;;                           represents how a turtle did on each dimension of the payoff
;;                           vector
;;   obj-final-performances-var: this is a list with the variances from above

globals [bandit-means bandit-vars net-gap sub-final-performance sub-final-performance-var
  obj-final-performance-0 obj-final-performance-1 obj-final-performance-0-var obj-final-performance-1-var]


;; Turtle variables
;;   bandit-obs-mean: a list with the observed mean for each bandit
;;   bandit-obs-n: a list with the number of observations for each bandit
;;   current-best: the bandit that I currently think is best.  If I'm updating my
;;                 judgment every round, this really isn't needed.  But it's used
;;                 when reeval-frequency is longer to keep track of what I thought
;;                 best when I last reevaluated
;;   current-bandit: what did I play this round?
;;   current-result: what was my result this round?
;;   favored-outcome: represents which dimension of the payoff vector I care about

turtles-own [ bandit-obs-mean bandit-obs-n bandit-perf bandit-perf-n current-bandit current-result favored-outcome]

;;
;; setup: sets everything up
;;

to setup
  clear-all

  ;; copy the means from the interface into a list.  (1 means the first dimension of the payoff vector, 2 means the second)
  set bandit-means (list (list b1-mean-1 b1-mean-2) (list b2-mean-1 b2-mean-2) (list b3-mean-1 b3-mean-2) (list b4-mean-1 b4-mean-2))
  set bandit-vars (list b1-variance b2-variance b3-variance b4-variance)

 ;; create the agents
 crt Number-Of-Agents [

    ;; determine whether they care about dimension 1 or dimension 2
    set favored-outcome ifelse-value (random-float 1 < PreferenceBias) [0] [1]

    set bandit-obs-mean n-values Number-Of-Bandits [[0 0]]
    set bandit-obs-n n-values Number-Of-Bandits [Initial-Sample]

    ;; draw initial samples
    foreach n-values Number-of-Bandits [i -> i] [
      i ->

      let start-sample n-values Initial-Sample [draw-bandit i]

      let results-0 map [j -> item 0 j] start-sample
      let results-1 map [j -> item 1 j] start-sample

      set bandit-obs-mean replace-item i bandit-obs-mean (list (mean results-0) (mean results-1))
    ]

    set bandit-perf n-values Number-Of-Bandits [[0 0]]
    set bandit-perf-n n-values Number-Of-Bandits [0]


    if Visuals? [
      set shape ifelse-value (favored-outcome  = 0) ["circle"]["square"]
      move-to one-of patches
    ]
 ]

 if Number-Of-Agents > 1 [
    if Network = "Complete" [
      ;; because the complete network is slow to create, we're going to handle it specially
      ;; this commented out code is how we would create it.

      ;;  ask turtles [
      ;;    let num who
      ;;    create-links-with turtles with [who > num]
      ;;  ]
    ]
    if Network = "Cycle" [
      ask turtles [
        let num who
        create-link-with turtle ((num + 1) mod Number-Of-Agents)
      ]
    ]
  ]

  if Visuals? [
    layout-circle (sort turtles) max-pxcor - 1
  ]

  reset-ticks
end

;;
;; go-full: runs multiple instances, created for use by the OpenMole controller to reduce the number of jobs created
;;

to go-full
  let sub-results []
  let obj-results-0 []
  let obj-results-1 []

  repeat Number-Of-Trials [
    setup
    repeat Number-Of-Pulls [ step ]

    set sub-results lput mean [my-sub-performance] of turtles sub-results
    set obj-results-0 lput mean [my-obj-performance 0] of turtles obj-results-0
    set obj-results-1 lput mean [my-obj-performance 1] of turtles obj-results-1
  ]

  set sub-final-performance mean sub-results
  set obj-final-performance-0 mean obj-results-0
  set obj-final-performance-1 mean obj-results-1


  ifelse length sub-results > 1 [
    set sub-final-performance-var variance sub-results
    set obj-final-performance-0-var variance obj-results-0
    set obj-final-performance-1-var variance obj-results-1

  ]
  [
    set sub-final-performance-var 0
    set obj-final-performance-0-var 0
    set obj-final-performance-1-var 0

  ]



end


;;
;; step: steps the model one tick.  plays the bandit then updates
;;
to step
  if ticks > Number-Of-Pulls [
    set sub-final-performance mean [my-sub-performance] of turtles
    set sub-final-performance-var 0

    set obj-final-performance-0 mean [my-obj-performance 0] of turtles
    set obj-final-performance-0-var 0

    set obj-final-performance-1 mean [my-obj-performance 1] of turtles
    set obj-final-performance-1-var 0

    stop
  ]
  ask turtles [
    play
  ]

  ;; There are a total of for updater functions, each optimized for a different type of
  ;; situation.
  ;;      update-me: is the empty network, I only update based on my own results.  Useful
  ;;                 for a world with only one turtle
  ;;      update-network-small: used for relatively sparse networks
  ;;      update-network-large: used for relatively dense networks
  ;;      update-complete: ignores the network structure and just has everyone update on
  ;;                       everyone.  For efficiency reasons when we have a complete network
  ;;                       we don't use network primatives because they just slow everything
  ;;                       down.

  ;; As you add networks: if the network is relatively sparse, use update-network-small
  ;; if the network is dense, use update-network-large.  Both will work for any network, but they have
  ;; different efficiency properties.  BUT NOTE: every turtle on a given round must use the same update
  ;; function.  If you mix updated functions on a given round things will not work as intended

  ifelse Number-Of-Agents = 1 [
    ;; if we have only one agent, we can update a little faster
    ask turtles [
      update-me
    ]
  ]
  [
    ;; if we have more than one agent
    if Network = "Cycle" [
      ask turtles [
        update-network-small
      ]
    ]
    if Network = "Complete" [
      update-complete
    ]
  ]

  tick
end


;;
;; play: must be called in turtle context.  Has a turtle play
;;


to play

  ifelse random-float 1 < epsilon [
    ;; are we experimenting
    set current-bandit random Number-Of-Bandits
    set current-result draw-bandit current-bandit

  ]
  [
    ;; or optimizing
    let my-results map [i -> item favored-outcome i] bandit-obs-mean
    set current-bandit position (max my-results) my-results
    set current-result draw-bandit current-bandit
  ]

  let old-mean item current-bandit bandit-perf
  let old-n item current-bandit bandit-perf-n
  let new-mean (map [[m c] -> ((old-n * m) + c) / (old-n + 1)] old-mean current-result)

  set bandit-perf replace-item current-bandit bandit-perf new-mean
  set bandit-perf-n replace-item current-bandit bandit-perf-n (old-n + 1)


  set color (current-bandit * 30) + 15
end

;;
;; update-me: if we have only one player we can save some time by using a simpler update system
;;

to update-me
  let old-mean item current-bandit bandit-obs-mean
  let old-n item current-bandit bandit-obs-n
  let new-mean (map [[m c] -> ((old-n * m) + c) / (old-n + 1)] old-mean current-result)

  set bandit-obs-mean replace-item current-bandit bandit-obs-mean new-mean
  set bandit-obs-n replace-item current-bandit bandit-obs-n (old-n + 1)
end

;;
;; update-network-small: must be called in turtle context.  This has a turtle "push"
;;                       his results out to his neighbors.  It is most efficient for
;;                       small networks

to update-network-small

  let updating-bandit current-bandit
  let updating-result current-result

  ask (turtle-set link-neighbors self) [
    let old-mean item updating-bandit bandit-obs-mean
    let old-n item updating-bandit bandit-obs-n
    let new-mean (map [[m c] -> ((old-n * m) + c) / (old-n + 1)] old-mean updating-result)

    set bandit-obs-mean replace-item updating-bandit bandit-obs-mean new-mean
    set bandit-obs-n replace-item updating-bandit bandit-obs-n (old-n + 1)
  ]
end


;;
;; update-network-large: must be called in turtle context. This has a turtle "pull" her
;;                       results from her neighbors. Each turtle first creates a summary
;;                       of how each bandit did in the previous round, then updates her
;;                       results.  It is efficient in dense networks when there are many
;;                       turtles playing a bandit on a particular round
;;

to update-network-large
  ;; This is an alternative way of doing the update step, designed to (potentially) be more efficient

  let updaters (turtle-set link-neighbors self)

  foreach n-values Number-of-Bandits [i -> i] [
    i ->

    let results-0 [item 0 current-result] of (updaters with [current-bandit = i])
    let results-1 [item 1 current-result] of (updaters with [current-bandit = i])
    if not empty? results-0 [
      let mperf (list (mean results-0) (mean results-1))
      let num length results-0

      let old-mean item i bandit-obs-mean
      let old-n item i bandit-obs-n

      let new-mean (map [[m c] -> ((old-n * m) + (num * c)) / (old-n + num)] old-mean mperf)

      set bandit-obs-mean replace-item i bandit-obs-mean new-mean
      set bandit-obs-n replace-item i bandit-obs-n (old-n + num)

    ]

  ]
end

;;
;; update-complete: run in OBSERVER context (different from above). Works similarly to update-network-large,
;;                  except it presumes that you are updating everyone and completely ignores links
;;                  this saves computational overhead for the complete graph
;;

to update-complete

  foreach n-values Number-of-Bandits [i -> i] [
    i ->

    let results-0 [item 0 current-result] of (turtles with [current-bandit = i])
    let results-1 [item 1 current-result] of (turtles with [current-bandit = i])
    if not empty? results-0 [
      let mperf (list (mean results-0) (mean results-1))
      let num length results-0

      ask turtles [
        let old-mean item i bandit-obs-mean
        let old-n item i bandit-obs-n

        let new-mean (map [[m c] -> ((old-n * m) + (num * c)) / (old-n + num)] old-mean mperf)

        set bandit-obs-mean replace-item i bandit-obs-mean new-mean
        set bandit-obs-n replace-item i bandit-obs-n (old-n + num)
      ]

    ]
  ]
end


to-report draw-bandit [arm]
  if arm > Number-Of-Bandits [
    user-message "Somebody asked for a bandit that doesn't exist"
  ]
  let x1 random-normal 0 1
  let x2 random-normal 0 1
  let x3 (ResultCorrelation * x1) + (sqrt ( 1 - (ResultCorrelation ^ 2)) * x2)
  let mu-1 item 0 (item arm bandit-means)
  let mu-2 item 1 (item arm bandit-means)
  let sig item arm bandit-vars
  report (list (mu-1 + (sig * x1)) (mu-2 + (sig * x3)))
end

to-report my-sub-performance
  if ticks = 0 [
    report 0
  ]

  let my-results map [i -> item favored-outcome i] bandit-perf
  report (sum (map * my-results bandit-perf-n)) / (sum bandit-perf-n)
end

to-report my-obj-performance [correct-dimension]

   if ticks = 0 [
    report 0
  ]

  let my-results map [i -> item correct-dimension i] bandit-perf
  report (sum (map * my-results bandit-perf-n)) / (sum bandit-perf-n)

end

to network-gap
  set Network "Complete"
  setup
  repeat Number-Of-Pulls [step]
  let complete-perf mean [my-sub-performance] of turtles

  set Network "Cycle"
  setup
  repeat Number-Of-Pulls [step]
  let cycle-perf mean [my-sub-performance] of turtles

  set net-gap cycle-perf - complete-perf
end
@#$#@#$#@
GRAPHICS-WINDOW
230
17
667
455
-1
-1
13.0
1
10
1
1
1
0
0
0
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
10
23
84
57
NIL
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
87
23
152
57
NIL
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

BUTTON
154
23
218
57
go
step
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
680
100
745
160
b1-mean-1
10.0
1
0
Number

INPUTBOX
825
100
892
160
b1-variance
100.0
1
0
Number

INPUTBOX
680
170
745
230
b2-mean-1
0.0
1
0
Number

INPUTBOX
825
170
892
230
b2-variance
0.0
1
0
Number

INPUTBOX
680
240
745
300
b3-mean-1
0.0
1
0
Number

INPUTBOX
825
240
890
300
b3-variance
0.0
1
0
Number

INPUTBOX
680
310
745
370
b4-mean-1
0.0
1
0
Number

INPUTBOX
825
310
892
370
b4-variance
0.0
1
0
Number

SLIDER
680
20
890
53
Number-Of-Bandits
Number-Of-Bandits
2
4
2.0
1
1
NIL
HORIZONTAL

SLIDER
10
65
215
98
Number-Of-Agents
Number-Of-Agents
1
100
10.0
1
1
NIL
HORIZONTAL

SLIDER
10
105
215
138
Epsilon
Epsilon
0
1
0.5
.01
1
NIL
HORIZONTAL

SLIDER
10
145
215
178
Initial-Sample
Initial-Sample
1
100
1.0
1
1
NIL
HORIZONTAL

PLOT
925
20
1125
170
Subjective Bandit Performance
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Bandit 1" 1.0 0 -2674135 true "" "plotxy ticks mean [item 0 (map [i -> item favored-outcome i] bandit-obs-mean)] of turtles"
"Bandit 2" 1.0 0 -1184463 true "" "plotxy ticks mean [item 1 (map [i -> item favored-outcome i] bandit-obs-mean)] of turtles"
"Bandit 3" 1.0 0 -14835848 true "" "if Number-Of-Bandits > 2 [plotxy ticks mean [item 2 (map [i -> item favored-outcome i] bandit-obs-mean)] of turtles]"
"Badnit 4" 1.0 0 -13345367 true "" "if Number-Of-Bandits > 3 [plotxy ticks mean [item 3 (map [i -> item favored-outcome i] bandit-obs-mean)] of turtles]"

PLOT
925
185
1125
335
Performance
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Subjective" 1.0 0 -16777216 true "" "plotxy ticks mean [my-sub-performance] of turtles"
"Objective 0" 1.0 0 -2674135 true "" "plotxy ticks mean [my-obj-performance 0] of turtles"
"Objective 1" 1.0 0 -14070903 true "" "plotxy ticks mean [my-obj-performance 1] of turtles"

CHOOSER
10
185
215
230
Network
Network
"Complete" "Cycle"
0

SLIDER
10
235
215
268
Number-Of-Pulls
Number-Of-Pulls
1
10000
500.0
50
1
NIL
HORIZONTAL

SLIDER
680
60
890
93
ResultCorrelation
ResultCorrelation
-1
1
-0.5
.1
1
NIL
HORIZONTAL

SLIDER
10
275
215
308
PreferenceBias
PreferenceBias
0
1
0.5
.01
1
NIL
HORIZONTAL

INPUTBOX
750
100
820
160
b1-mean-2
-10.0
1
0
Number

INPUTBOX
750
170
820
230
b2-mean-2
0.0
1
0
Number

INPUTBOX
750
240
815
300
b3-mean-2
0.0
1
0
Number

INPUTBOX
750
310
815
370
b4-mean-2
0.0
1
0
Number

SWITCH
235
460
347
493
Visuals?
Visuals?
0
1
-1000

INPUTBOX
350
460
507
520
Number-Of-Trials
2.0
1
0
Number

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
NetLogo 6.0.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="CorrelationSearch-e0" repetitions="20000" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>step</go>
    <metric>mean [my-performance] of turtles</metric>
    <enumeratedValueSet variable="Initial-Sample">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Agents">
      <value value="10"/>
    </enumeratedValueSet>
    <steppedValueSet variable="ResultCorrelation" first="-1" step="0.1" last="1"/>
    <enumeratedValueSet variable="PreferenceBias">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Network">
      <value value="&quot;Complete&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Bandits">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Epsilon">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b1-mean">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b1-variance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b2-mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b2-variance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b3-mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b3-variance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b4-mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b4-variance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Pulls">
      <value value="500"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="EpsilonSearch-rminus1" repetitions="20000" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>step</go>
    <metric>mean [my-performance] of turtles</metric>
    <enumeratedValueSet variable="Initial-Sample">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Agents">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ResultCorrelation">
      <value value="-1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PreferenceBias">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Network">
      <value value="&quot;Complete&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Bandits">
      <value value="2"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Epsilon" first="0" step="0.05" last="0.5"/>
    <enumeratedValueSet variable="b1-mean">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b1-variance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b2-mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b2-variance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b3-mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b3-variance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b4-mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b4-variance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Pulls">
      <value value="500"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ProportionSearch" repetitions="20000" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>step</go>
    <metric>mean [my-performance] of turtles</metric>
    <enumeratedValueSet variable="Initial-Sample">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Agents">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ResultCorrelation">
      <value value="-1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="PreferenceBias" first="0" step="0.1" last="0.5"/>
    <enumeratedValueSet variable="Network">
      <value value="&quot;Complete&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Bandits">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Epsilon">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b1-mean">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b1-variance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b2-mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b2-variance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b3-mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b3-variance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b4-mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b4-variance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Pulls">
      <value value="500"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="EpsilonSearch-otherr" repetitions="20000" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>step</go>
    <metric>mean [my-performance] of turtles</metric>
    <enumeratedValueSet variable="Initial-Sample">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Agents">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ResultCorrelation">
      <value value="-0.5"/>
      <value value="0"/>
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PreferenceBias">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Network">
      <value value="&quot;Complete&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Bandits">
      <value value="2"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Epsilon" first="0" step="0.05" last="0.5"/>
    <enumeratedValueSet variable="b1-mean">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b1-variance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b2-mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b2-variance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b3-mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b3-variance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b4-mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b4-variance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Pulls">
      <value value="500"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ProportionSearch-othere" repetitions="20000" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>step</go>
    <metric>mean [my-performance] of turtles</metric>
    <enumeratedValueSet variable="Initial-Sample">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Agents">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ResultCorrelation">
      <value value="-1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="PreferenceBias" first="0" step="0.1" last="0.5"/>
    <enumeratedValueSet variable="Network">
      <value value="&quot;Complete&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Bandits">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Epsilon">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b1-mean">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b1-variance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b2-mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b2-variance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b3-mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b3-variance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b4-mean">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b4-variance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Pulls">
      <value value="500"/>
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
