# Fixture for rule 4: a mix of literal-title and computed-title registrations.
Add menu command: "Objects", "Praat", "Alpha", "", 0, "alpha.praat"
Add action command: "Sound", 1, "", 0, "", 0, "Beta", "", 0, "beta.praat"
Add menu command: "Objects", "Praat", dynamicTitle$, "", 0, "gamma.praat"
Add action command: "Sound", 2, "TextGrid", 1, "", 0, computedName$, "", 0, "delta.praat"
