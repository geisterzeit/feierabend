# Feierabend

Schedule Bambu Lab prints so they start, or finish, when you want them to.

Feierabend runs as a Bambu Studio post-processing script. After each slice, it asks when the print should start or when it should be finished. Then it adds a wait to the G-code before the machine start sequence. You press **Print** in Bambu Studio as usual, and Bambu Studio sends the job through Bambu Cloud. The printer stays cold until the planned start, then heats up and prints.

## Setup

1. `make install` builds Feierabend and copies it to `/Applications`.
2. Open Feierabend and copy the script line it shows.
3. In Bambu Studio, open the Process settings, turn on **Advanced**, go to **Others › Post-processing Scripts** and paste the line.

## How the wait works

- A single `G4` dwell on Bambu firmware is limited to roughly 90 seconds, so Feierabend writes one-minute `G4 S60` dwells.
- Each dwell is preceded by `M73 P0 R…`, so the printer and Bambu Handy include the wait in the remaining time.
- The wait sits between `; FEIERABEND_WAIT_START` and `; FEIERABEND_WAIT_END`, and a later run replaces it.
- **Finish by** uses Bambu Studio's `total estimated time` from the G-code header.
- The wait is counted from when the printer starts the job, so press Print soon after scheduling.
