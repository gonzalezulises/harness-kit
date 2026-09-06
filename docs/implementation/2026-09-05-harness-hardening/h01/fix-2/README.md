# H01 fix round 2 evidence

The authoritative final RED run is `red31-3754ec92.stderr.log` plus its
exit file: 31 tests, six assertion failures, zero errors. The authoritative
GREEN is `freeze-bedd36caa4274691a841ff3e615d211d.json`: an atomic capture of
31 tests passing with the final test hash. Earlier captures are retained as
chronology and may be interim or truncated; they are not the final evidence.
The amended independent review confirms these exact final artifacts.

The source snapshots used for RED are retained in `../snapshots/fix-2/`.
Absolute scratch paths in original logs identify the original execution;
use the snapshot reproduction instructions after cloning elsewhere.
