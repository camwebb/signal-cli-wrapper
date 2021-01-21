# signal-cli-wrapper

**NOTE** (2021-01-13) Rewrote from a `bash` to `gawk` script.

_An `awk` (Gawk) wrapper script for easier use of
[signal-cli](https://github.com/AsamK/signal-cli)_

Usage: 

 * `sig snd <name> "message"` : Send to a name not a number (set names
   in config file)
 * `sig rcv` : Get messages, which are written to a log file
 * `sig log` : Read the logs more easily (to see receipts and read-receipts)
 * `sig ids` : Check the phone numbers you have keys for
 * `sig num` : Check the phone numbers in your config file
 * `sig ckn <num>` : Test if `<num>` (prefix with `+`) using Signal
 * `sig cfg` : Edit config file
 * `sig cli` : Show `signal-cli` usage
 * `sig new` : Show the most recent new messages and confirmations
 * `sig cnv <name>` : Display a conversation:
 
<img src="img/cnv.png" width="50%"/>

Note (2021-01-21): `signal-cli` seems not to be able to
[fully handle](https://github.com/AsamK/signal-cli/issues/354)
Signal’s version 2 groups; action `gnu` will probably fail. Actions
`gls`, `gad`, `glv` still work on version 1 groups. See usage by just
typing `sig`.

Also included: `checksig` a script to execute `sig rcv` and notify you via
`send-notify`; run it as a `cron` job.

## Installation

 1. Make the scripts executable (`chmod u+x sig; chmod u+x checksig`)
 2. Make sure the hashbang in the first line of scripts points to `gawk`
 3. Scripts and `signal-cli` must be in the shell’s `$PATH`
 4. Make sure `scw_config.awk` is in a directory present in environment
    variable `$AWKPATH` (set in `.bash_profile`, etc)
 5. Edit `scw_config.awk` to add short names to your numbers
 6. (Optional) Add `checksig` to your `crontab` file. E.g.: 

```    
0,10,20,30,40,50 * * * *   /home/foo/bin/checksig
```
