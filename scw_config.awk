# Config file for sg from signal-cli-wrapper

function config() {
  # 1. User's number
  MYNUM        = "+1XXXXXXXXXX"
  
  # 2. Phone book; make sure every entry from `sg ids` is entered here:
  NUM["foo"]     = "+1YYYYYYYYYY"
  NUM["bar"]     = "+1ZZZZZZZZZZ"
  # ...

  # groups
  NUM["foobar"]  = "aFQxxxxxxxxxxxxxxxxxxx=="
  # ...
  
  # location of sg executable
  SG           = "/home/foo/bin/sg"
  # config home
  SCLI         = "/home/foo/.local/share/signal-cli/"
}
