import nre
import terminal
import strformat
import strutils

proc log*(text:string, color="", colormode="all") =
  var cs = ""
  case color
  of "green": cs = ansiForegroundColorCode(fgGreen)
  of "cyan": cs = ansiForegroundColorCode(fgCyan)
  of "red": cs = ansiForegroundColorCode(fgRed)
  if colormode == "all":
    echo &"{cs}{text}{ansiResetCode}"
  elif colormode == "start":
    let split = text.split(": ")
    let t1 = split[0].strip()
    let t2 = split[1].strip()
    echo &"{cs}{t1}:{ansiResetCode} {t2}"

proc pname*(s:string, n:int): string =
  if n != 1:
    if s.endsWith("y"):
      return s.replace(re"y$", "ies")
    else:
      return &"{s}s"
  return s

proc error*(message:string) =
  log(&"Error: {message}", "red", "start")

proc enter_altscreen*() =
  echo "\u001b[?1049h"

proc exit_altscreen*() =
  echo "\u001b[?1049l"

proc to_bottom*() =
  cursorDown(stdout, terminalHeight())

proc clear*() =
  eraseScreen()