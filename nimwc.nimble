# Package
version       = "4.0.7"
author        = "Thomas T. Jarløv (https://github.com/ThomasTJdev)"
description   = "Generate and host a website. Run the package and access your new webpage."
license       = "GPLv3"
bin           = @["nimwc"]
skipDirs      = @["private", "tmp"]
installDirs   = @["config", "nimwcpkg", "plugins", "public"]



# Dependencies
requires "nim >= 0.19.0"
requires "jester >= 0.4.1"
requires "recaptcha >= 1.0.2"
requires "bcrypt >= 0.2.1"


import distros

task setup, "Generating executable":
  if detectOs(Windows):
    echo "Cannot run on Windows"
    quit()

  if not fileExists("config/config.cfg"):
    exec "cp config/config_default.cfg config/config.cfg"

  exec "nim c -r -d:release -d:ssl nimwc.nim"

before install:
    setupTask()
