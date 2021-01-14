# Config file for sg from signal-cli-wrapper

declare -A NUM

# 1. User's number
MYNUM="+19999999999"

# 2. Phone book; make sure every entry from `sg ids` is entered here:
NUM[joe]="+19999999991"
NUM[jane]="+19999999992"

# 3. location of sg executable
SG=/path/to/sg
