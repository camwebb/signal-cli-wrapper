#!/bin/env -S gawk -f

# Wrapper for signal-cli, adding convenience and color
# Cam Webb. See <https://github.com/camwebb/signal-cli-wrapper>
# License: GNU GPLv3. See LICENSE file.

# Installation:
#   1) Make this script executable
#   2) This script and signal-cli must be in your shell's $PATH
#   3) Make sure "scw_config.awk" is in a directory present in environment
#      variable $AWKPATH

@load "json"
@include "scw_config.awk"

BEGIN{

  # Setup
  config()  # in file scw_config.awk
  proc_nums()

  # logfile
  LOG = SCLI "msgs"
  
  # logfile date format. Note the three extra 0s
  DATE = strftime("%s000 (%Y-%m-%dT%H:%M:00.000Z)")
  DATETS = strftime("%s000")
  
  USAGE = "Usage: sig ...\n"                                           \
    "           NAME [ts]      = Conversation [show timestamps]\n"     \
    "           NAME \"MSG\"     = Send (use \"...\"\\!\\!\"...\" for" \
    " multiple !)\n"                                                   \
    "           NAME TS :+1:   = React with emoji\n"                   \
    "           rcv            = Receive\n"                            \
    "           log            = See log\n"                            \
    "           ids NAME       = Get contact info from server\n"       \
    "           num            = List contacts in config\n"            \
    "           gls            = List groups\n"                        \
    "           gnu DESC       = New group (v2 GROUPS CURRENTLY NOT WORKING)\n"\
    "           gad GNAME NAME = Add person to group\n"                \
    "           glv GNAME      = Leave group\n"                        \
    "           ckn +NUM       = Check +NUM for Signal\n"              \
    "           ver NAME CODE  = Verify safety CODE\n"                 \
    "           cfg            = Edit config file\n"                   \
    "           cli            = Show signal-cli usage\n"              \
    "           new            = See new messages"

  # Begin tests for actions
  
  # Get the registered numbers
  if ((ARGV[1] == "ids") &&                     \
      (ARGC == 3)) {
    ("signal-cli -o json -u " MYNUM " listIdentities -n " NUM[ARGV[2]]) \
      | getline json
    # json::from_json(json, data)
    # print ARGV[2]
    # print "  " data[1]["number"]
    print "  " data[1]["uuid"]
    print "  " data[1]["trustLevel"]
    print "  " data[1]["safetyNumber"]
  }

  # Get the user names/numbers
  else if ((ARGV[1] == "num") &&               \
      (ARGC == 2)) {
    print "Short names of people and groups in config file:"
    PROCINFO["sorted_in"] = "@ind_str_asc"
    for (i in NUM)
      printf "  %-10s : %s\n",  i , NUM[i]
  }

  # Get the latest messages and write to stdout and to logfile
  else if ((ARGV[1] ~ /^(rcv|new|n)$/) &&       \
           (ARGC == 2)) {
    err = system("signal-cli -o json -u " MYNUM " receive | tee -a " LOG)
    if (err) {
      print "Receiving failed" > "/dev/stderr"
      exit 1
    }
    
    # list new recieved messages since last time this was run
    if (ARGV[1] ~ /^new$/) {
      getline OLDLINES < (SCLI "oldlines")
      RS=""
      FS="\n"
      while (( getline < LOG ) > 0) {
        if (++l <= OLDLINES)
          continue
        sender = body = ""
        for (i = 1; i <= NF; i++) {
          if ($i ~ /^Sender:/)
            sender = gensub(/^[^+]+(\+[0-9]+) .*$/,"\\1","G",$i)
          else if (($i ~ /^Body:/) && sender) {
            if ((iNUM[sender]) && (sender != MYNUM))
              list[iNUM[sender]]++
            else if (sender != MYNUM)
              list[sender]++
          }
        }
      }
      
      PROCINFO["sorted_in"] = "@ind_str_asc"
      if (isarray(list)) {
        print "New messages from:"
        for (i in list)
          print "  " i " (" list[i] ")"
      }
      else
        print "No new messages"
      
      # reset
      print l > (SCLI "oldlines")
    }
  }
  
  # read the logfile, substituting names for numbers
  else if ((ARGV[1] == "log") &&                \
           (ARGC == 2)) {
    "mktemp" | getline TMPLOG
    while (( getline < LOG ) > 0) {
      for (i in iNUM)
        gsub(gensub(/\+/,"\\\\+","G",i),("{" iNUM[i] "}"),$0)
      print $0 >> TMPLOG
    }
    system("less +G " TMPLOG)
  }
  
  # Send a message to <name> (can be a group) and write to logfile
  else if ((ARGC == 3) &&                       \
           (NUM[ARGV[1]]) &&                    \
           (ARGV[2] != "ts")) {
    
    if (NUM[ARGV[1]] ~ /=/)
      cmd = "signal-cli -u " MYNUM " send -g " NUM[ARGV[1]] \
        " -m \"" ARGV[2] "\""
    else
      cmd = "signal-cli -u " MYNUM " send " NUM[ARGV[1]]    \
        " -m \"" ARGV[2] "\""
    err = system(cmd)

    if (err) {
      print "Sending failed" > "/dev/stderr"
      exit 1
    }
    
    out = "{'envelope':{'source':'" MYNUM "','sourceNumber':'" MYNUM    \
      "','sourceDevice':1,'timestamp':" DATETS                            \
      ",'syncMessage':{'sentMessage':{'destination':'"                  \
      NUM[ARGV[1]] "','destinationNumber':'" NUM[ARGV[1]] "','timestamp':" \
      DATETS ",'message':'" ARGV[2] "'}}},'account':'" MYNUM "'}"
    print gensub(/'/,"\"","G",out) >> LOG
    
  }
  
  # Send a reaction and write to logfile
  else if ((ARGC == 4) &&                       \
           (NUM[ARGV[1]]) &&                    \
           (ARGV[2] ~ /16[0-9]+/) &&            \
           (ARGV[3] ~ /^:.+:$/)) {

    emoji[":+1:"] = "👍"
    emoji[":heart:"] = "🧡"

    if (!emoji[ARGV[3]]) {
      print "Emoji not found" > "/dev/stderr"
      exit 1
    }

    err = system("signal-cli -u " MYNUM " sendReaction " NUM[ARGV[1]]   \
                 " -a " NUM[ARGV[1]] " -t " ARGV[2] " -e " emoji[ARGV[3]])
    if (err) {
      print "Sending failed" > "/dev/stderr"
      exit 1
    }

    print "Envelope from: " MYNUM " (device: 1)\n"  \
      "Timestamp: " DATE "\n"                       \
      "Sender: " MYNUM " (device: 1)\n"             \
      "To: " NUM[ARGV[1]] "\n"                      \
      "Reaction:\n"                                 \
      "  Emoji: " emoji[ARGV[3]] "\n"               \
      "  Target timestamp: " ARGV[2] "\n"  >> LOG
  }

  # Create a conversation from the logfile
  else if (((ARGC == 2)     &&                  \
            (NUM[ARGV[1]])) ||                  \
           ((ARGC == 3) &&                      \
            (NUM[ARGV[1]]) &&                   \
            (ARGV[2] == "ts"))) {
    # RS=""
    # FS="\n"
    Width = 51
    name = ARGV[1]
    showts = (ARGV[2] == "ts") ? 1 : 0
    json = "["

    # read log file
    while (getline < LOG )
      json = json $0 ","
    gsub(/,$/,"]",json)

    # parse
    if (! json::from_json(json, data)) {
      print "JSON import failed!" > "/dev/stderr"
      exit 1
    }

    walk_array(data, "data")
    # exit 0
    # read json
    PROCINFO["sorted_in"] = "@ind_num_asc"

    for (i in data) {
      
      # #   order of log fields
      # sender = sent_to = ts = body = att = ""
      # for (i = 1; i <= NF; i++) {
      #   if ($i ~ /^Sender:/)
      #     # complicated, because if the number is in Signal 'contacts' then
      #     #   the contact name appears before the number
      #     sender = gensub(/^[^+]+(\+[0-9]+).*$/,"\\1","G",$i)
      #   else if ($i ~ /^ *To:/)
      #     sent_to = gensub(/^[^+]+(\+[0-9]+).*$/,"\\1","G",$i)
      #   else if ($i ~ /^ *Timestamp:/) # note 2nd ts will overwrite
      #     ts = gensub(/.* (16[0-9]+) .*/, "\\1", "G", $i)
      #   else if ($i ~ /^ *Body:/) {
      #     body = gensub(/^ *Body: +/, "", "G", $i)
      #     # multi line - tricky
      #     k = i + 1
      #     # to do - if the message contains \n\n then the end of the
      #     # record is noted.  Somehow need to join these records together
      #     while ((k <= NF) &&                         \
      #            ($k !~ /^ *[A-Z][a-z]+:/) &&         \
      #            ($k !~ /^ *Profile key update/)) {
      #       body = body " // " $k
      #       k++
      #     }
      #   }
      #   else if ($i ~ /Stored plaintext/)
      #     body = body " [ " gensub(/.*\/attachments\/(.*)$/,"\\1","G",$i) " ]"
      # }
      
      # print "{" sender "}{" sent_to "}{" body "}"
      # for each log entry, is it a sent to person?
      # TODO, separate out Group messages

      body = ts = dest = from = group =""
      if (isarray(data[i]["envelope"]["syncMessage"]) ||    \
          isarray(data[i]["envelope"]["dataMessage"])) {

        # post from me to person or group
        if (isarray(data[i]["envelope"]["syncMessage"]["sentMessage"])) {
          body = data[i]["envelope"]["syncMessage"]["sentMessage"]["message"]
          ts = data[i]["envelope"]["syncMessage"]["sentMessage"]["timestamp"]
          dest = (isarray(data[i]["envelope"]["syncMessage"]["sentMessage"]["groupInfo"])) ? data[i]["envelope"]["syncMessage"]["sentMessage"]["groupInfo"]["groupId"] : data[i]["envelope"]["syncMessage"]["sentMessage"]["destination"]
          from = data[i]["envelope"]["sourceNumber"]
        }
        # post from someone else to group (but not a reaction or call)
        else if (isarray(data[i]["envelope"]["dataMessage"]))
          if (data[i]["envelope"]["dataMessage"]["message"]) {
            body = data[i]["envelope"]["dataMessage"]["message"]
            ts = data[i]["envelope"]["dataMessage"]["timestamp"]
            group = data[i]["envelope"]["dataMessage"]["groupInfo"]["groupId"]
            from = data[i]["envelope"]["source"]
          }

        # me to person or group
        if (from == MYNUM && dest == NUM[name])
          format_line(body, (sprintf("%*s", (length(name)), " ") " < "), \
                      "10", ts , showts)
        # other direct to me
        else if (dest == MYNUM && from == NUM[name])
          format_line(body, (name " : "), "11", ts, showts)
        # other to group
        else if (group == NUM[name] && from != NUM[name])
          format_line(body, (iNUM[from] " : "), "11", ts, showts)
        # other to me, in dataMessage, no dest
        else if (!group && from == NUM[name])
          format_line(body, (iNUM[from] " : "), "11", ts, showts)
      }
    }
  }

  # Test for user
  else if ((ARGV[1] == "ckn") &&                \
           (ARGC == 3) &&                       \
           (ARGV[2] ~ /\+[0-9]+/)) {
    print "Testing for a Signal user at " ARGV[2]
    ("signal-cli -o json -u " MYNUM " getUserStatus " ARGV[2]) | getline json
    json::from_json(json, data)
    if (!data[1]["isRegistered"])
      print "... User does not have a Signal account"
    else
      print "... User has a Signal account"
  }

  # list groups
  else if (ARGV[1] == "gls") {
    cmd = "signal-cli -u " MYNUM " listGroups -d"
    while ((cmd | getline) > 0) {
      for (i in iNUM)
        gsub(gensub(/\+/,"\\\\+","G",i),("{" iNUM[i] "}"),$0)
      print $0
    }
  }

  # Leave group
  else if ((ARGV[1] == "glv") && \
           (NUM[ARGV[2]])) {
    err = system("signal-cli -u " MYNUM " quitGroup -g '" NUM[ARGV[2]] "'")
    if (err)
      print "... Error. Could not leave group."
    else
      print "... Left group"
  }

  # # New group
  # else if ((ARGV[1] == "gnu") &&                \
  #          (ARGC == 3)) {
  #   err = system("signal-cli -u " MYNUM " updateGroup -n '" ARGV[2] "'")
  #   if (err)
  #     print "... Error. Could not create group."
  #   else
  #     print "... Group created"
  #   # 2021-01-14:
  #   # ~> sg gnu 'test 2'
  #   # [main] WARN org.asamk.signal.manager.helper.GroupHelper - Cannot create a V2 group as self does not have a versioned profile
  #   # [main] ERROR org.asamk.signal.manager.storage.SignalAccount - Error saving file: (was java.lang.NullPointerException) (through reference chain: org.asamk.signal.manager.storage.groups.JsonGroupStore["groups"]->org.asamk.signal.manager.storage.groups.GroupInfoV1["expectedV2Id"])
  #   # Creating new group "6oW4cvxphi6FIROn+JATZw==" …
  #   # ... Group created
  #   # but... group not visible.
  #   # Ahh: https://github.com/AsamK/signal-cli/issues/354
  # }

  # Add a person to group
  else if ((ARGV[1] == "gad") &&                \
           (NUM[ARGV[2]])     &&                \
           (NUM[ARGV[3]])) {
    err = system("signal-cli -u " MYNUM " updateGroup -g '" ARGV[2] "' -m " \
                 NUM[ARGV[3]])
    if (err)
      print "... Error. Could not add member"
  }
  
  # Send a message to <group> and write to logfile
  else if ((ARGV[1] == "gsn") &&                \
           (ARGC == 4) &&                       \
           (NUM[ARGV[2]])) {
    # (as long as the right # of arguments)
    
    err = system("signal-cli -u " MYNUM " send -g " NUM[ARGV[2]] \
                 " -m '" ARGV[3] "'")
    if (err) {
      print "sending failed!" > "/dev/stderr"
      exit 1
    }

    # TODO Check this format
    print "Group sent to: " NUM[ARGV[2]] "\nTimestamp: " DATE "\nBody: " \
      ARGV[3] "\n" >> LOG
  }

  else if ((ARGV[1] == "ver") &&                \
           (ARGC == 4) &&                       \
           (NUM[ARGV[2]]) &&
           (gensub(/ /,"","G",ARGV[3]) ~ /^[0-9]+$/)) {
    
    err = system("signal-cli -u " MYNUM " trust " NUM[ARGV[2]]  \
                 " -v '" gensub(/ /,"","G",ARGV[3]) "'")
    if (err) {
      print "trust command failed!" > "/dev/stderr"
      exit 1
    }
  }

  # Edit config file
  else if (ARGV[1] == "cfg") {
    split(ENVIRON["AWKPATH"], e, ":")
    for (i in e) {
      gsub(/\/+$/,"",e[i])
      "test -e " e[i] "/scw_config.awk ; echo $?" | getline status
      if (!status)
        system("emacs " e[i] "/scw_config.awk &")
    }
  }
  
  # Show signal-cli commands
  else if (ARGV[1] == "cli")
    print                                                               \
      "signal-cli -u " MYNUM " addDevice --uri 'tsdevice:/?uuid=...'\n" \
      "signal-cli -u " MYNUM " listDevices\n"                           \
      "signal-cli -u " MYNUM " getUserStatus NUM\n"                     \
      "signal-cli -u " MYNUM " listIdentities -n NUM\n"                 \
      "signal-cli -u " MYNUM " updateAccount\n"                         \
      "signal-cli -u " MYNUM " send +1234... -m 'message'\n"            \
      "signal-cli -u " MYNUM " send +1234... -a FILE.jpg\n"             \
      "signal-cli -u " MYNUM " sendReaction +1234... -t TS -e 😃\n"     \
      "signal-cli -u " MYNUM " receive\n"                               \
      "signal-cli -u " MYNUM " updateGroup -n 'New name' -d 'Description'\n" \
      "signal-cli -u " MYNUM " updateGroup -g '1XAe...' -m +1234\n"     \
      "signal-cli -u " MYNUM " send -g '1XAe...' -m 'message'\n"        \
      "signal-cli -u " MYNUM " quitGroup -g '1XAe...'\n"                \
      "signal-cli -u " MYNUM " listGroups -d\n"                         \
      "signal-cli -u " MYNUM " trust +1234... -v '2345 4567 ...'\n"     \
      "signal-cli -u " MYNUM " updateProfile --name 'Joe' --avatar FILE.jpg\n" \
      "signal-cli -u " MYNUM " updateContact +1234... --name 'Jane'\n" \
      "signal-cli -u " MYNUM " sendContacts\n"
  
  # If no arguments, or other fail
  else {
    print USAGE
    exit 1
  }

  exit 0
}

# TODO add trust:
#  signal-cli -u +1xxxxxxxxxx trust -v "50467 94008 ..." +62yyyyyyyyyy

function format_line(msg, l1, col, ts, showts,     lines, i,dash,ec,bc) {
  # arguments: message, message prefix, color, timestamp
  # (for colors: https://en.wikipedia.org/wiki/ANSI_escape_code )

  if (showts)
    msg = msg " " ts 
  lines = int((length(msg)-1) / Width) + 1
  # create the dash, if needed
  ec = substr(msg,Width,1)
  bc = substr(msg,Width+1,1)
  dash = (ec && (ec!=" ") && bc && (bc!=" ")) ? "-" : ""

  # print the first format_line, preceded by date and name
  # print "\x1b[38;5;8m" strftime("[%m-%d %a %H:%M] ",int(ts/1000)) "\x1b[38;5;"
  print "\x1b[38;5;8m" strftime("[%b%d %H] ",int(ts/1000)) "\x1b[38;5;" \
    col "m" l1 substr(msg,1,Width) dash
  
  for (i = 2; i <= lines; i++) {
    # print other lines
    ec = substr(msg,(i*Width),1)
    bc=substr(msg,(i*Width)+1,1)
    dash = (ec && (ec!=" ") && bc && (bc!=" ")) ? "-" : ""
    print sprintf("%*s", length(l1)+(62-Width), " ")                        \
      gensub(/^ */,"","G",substr(msg,((i-1)*Width)+1,Width)) dash
  }
  # print color reset:
  printf "\x1b[0;m"
}

function proc_nums(    i, n1, n2, nm, np) {
  gsub(/ +/,"",NUMS)
  gsub(/;$/,"",NUMS)
  split(NUMS, n1, ";")
  for (i in n1) {
    split(n1[i], n2, ":")
    nm[n2[1]]++
    np[n2[2]]++
    if((nm[n2[1]] > 1) || (np[n2[2]] > 1)) {
      print "Duplicate entry: " n1[i] > "/dev/stderr"
      exit 1
    }
    NUM[n2[1]] = n2[2]
    iNUM[n2[2]] = n2[1]
    if (n2[1] == MYNAME)
      MYNUM = n2[2]
    if (n2[1] ~ /^(rcv|log|ids|num|gls|gnu|gad|glv|ckn|trs|cfg|cli|new)$/) {
      print "'" n2[1] "' in config file is a reserved keyword" > "/dev/stderr"
      exit 1
    }
  }
  if (!NUM[MYNAME]) {
    print "No MYNAME in config file" > "/dev/stderr"
    exit 1
  }


  
  # create SCLI
  SCLI = "/home/" ENVIRON["USER"] "/.local/share/signal-cli/data/" MYNUM ".d/"
}

# NB: this is needed for compatibility with gawk-json v2+
function json_fromJSON(input_string, output_array) {
  return json::from_json(input_string, output_array)
}

function walk_array(arr, name,      i) {
  for (i in arr) {
    if (isarray(arr[i]))
      if (i ~ /^[0-9]+$/)
        walk_array(arr[i], (name "[" i "]"))
      else
        walk_array(arr[i], (name "[\"" i "\"]"))
    else
      if (i ~ /^[0-9]+$/)
        printf("%s[%s] = %s\n", name, i, arr[i])
      else
        printf("%s[\"%s\"] = %s\n", name, i, arr[i])
  }
}
