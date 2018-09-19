import osproc, os, sequtils, times, strutils

var runInLoop = true
var nimhaMain: Process

proc handler() {.noconv.} =
  ## Catch ctrl+c from user

  runInLoop = false
  kill(nimhaMain)
  echo "Program quitted."
  quit()

setControlCHook(handler)


proc checkCompileOptions(): string =
  ## Checking for known compile options
  ## and returning them as a space separated string.
  ## See README.md for explation of the options.
  
  result = ""

  when defined(adminnotify):
    result.add(" -d:adminnotify")
  when defined(dev):
    result.add(" -d:dev")
  when defined(devemailon):
    result.add(" -d:devemailon")
  when defined(demo):
    result.add(" -d:demo")
  when defined(demoloadbackup):
    result.add(" -d:demoloadbackup")
  when defined(ssl):
    result.add(" -d:ssl")

  return result
  
let compileOptions = checkCompileOptions()


template addArgs(inExec = false): string =
  ## User specified args

  #var args = foldl(commandLineParams(), a & (b & ""), "")
  var args = commandLineParams().join(" ")

  if args == "":
    ""

  elif inExec:
    " --run " & args

  else:
    " " & args


proc launcherActivated() =
  ## 1) Executing the main-program in a loop.
  ## 2) Each time a new compiled file is available,
  ##    the program exits the running process and starts a new
  echo $getTime() & ": Nim Website Creator: Launcher initialized"

  nimhaMain = startProcess(getAppDir() & "/nimwcpkg/nimwc_main" & addArgs(true), options = {poParentStreams, poEvalCommand})

  while runInLoop:
    if fileExists(getAppDir() & "/nimwcpkg/nimwc_main_new"):
      kill(nimhaMain)
      moveFile(getAppDir() & "/nimwcpkg/nimwc_main_new", getAppDir() & "/nimwcpkg/nimwc_main")
    
    if not running(nimhaMain):
      echo $getTime() & ": Restarting program in 1 second"

      discard execCmd("pkill nimwc_main")
      sleep(1000)
      
      let args = addArgs(true)
      if args != "":
        echo " Using args: " & args

      nimhaMain = startProcess(getAppDir() & "/nimwcpkg/nimwc_main" & addArgs(true), options = {poParentStreams, poEvalCommand})
   
    sleep(2000)

  echo $getTime() & ": Nim Website Creator: Quitted"
  quit()


proc startupCheck() =
  ## Checking if the main-program file exists. If not it will
  ## be compiled with args and compiler options (compiler
  ## options should be specified in the *.nim.pkg)
  if not fileExists(getAppDir() & "/nimwcpkg/nimwc_main") or defined(rc):
    echo "Compiling"
    echo " - Using params:" & addArgs()
    echo " - Using compile options in *.nim.cfg"
    echo " "
    echo " .. please wait while compiling"
    let output = execCmd("nim c " & compileOptions & " " & getAppDir() & "/nimwcpkg/nimwc_main.nim")
    if output == 1:
      echo "\nAn error occurred\n"
      quit()
    else:
      echo "\n"
      echo """Compiling done. 
      
    - To start Nim Website Creator and access at 127.0.0.1:<port>
      # Manually compiled
      ./nimwc

      # Through nimble, then just run with symlink
      nimwc
      
    - To add an admin user, append args:
      ./nimwc newuser -u:name -p:password -e:email
      
    - To insert standard data in the database, append args:
      ./nimwc insertdata



      """


proc updateNimwc() =
  ## GIT hard update
  ##
  ## This needs to be modified! What if there's a new stylesheet or js?

  if "gitupdate" in commandLineParams() or defined(gitupdate):
    discard existsOrCreateDir("tmp")
    discard execCmd("mv plugins/plugin_import.txt tmp/plugin_import.txt")

    discard execCmd("git fetch --all")
    discard execCmd("git reset --hard origin/master")

    discard execCmd("mv tmp/plugin_import.txt plugins/plugin_import.txt")

    echo "\n\nNimWC has been updated\n\n"
    quit()



updateNimwc()
startupCheck()
launcherActivated()