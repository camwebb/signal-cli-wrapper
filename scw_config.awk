# Config file for sg from signal-cli-wrapper

function config() {
  
  # 1. Phone book; every entry from `sg ids` and `sg listGroups` :
  NUMS = " \
    foo     : +1xxxxxxxxx  ;                      \
    bar     : +62yyyyyyyyy  ;                     \
    zGroup  : aFQFxxxxxxxxxxxxxxxxxx== ; " 

  # User's name in number list:
  MYNAME        = "foo"
  # path to signal-cli data directory:
  SCLI         = "/home/foo/.local/share/signal-cli/data/+1xxxxxxxxxx.d/"
  # location of sg executable (for checksg):
  SG           = "/home/foo/bin/sg"
}
