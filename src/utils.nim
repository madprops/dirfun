import os
import nre
import terminal
import strformat
import strutils

proc get_ansi*(color:string): string =
  case color
  of "green": ansiForegroundColorCode(fgGreen)
  of "cyan": ansiForegroundColorCode(fgCyan)
  of "red": ansiForegroundColorCode(fgRed)
  of "blue": ansiForegroundColorCode(fgBlue)
  of "reset": ansiResetCode
  else: ""

proc log*(text:string, color="", colormode="all") =
  let cs = get_ansi(color)
  let cr = get_ansi("reset")
  if colormode == "all":
    echo &"{cs}{text}{cr}"
  elif colormode == "start":
    let split = text.split(": ")
    let t1 = split[0].strip()
    let t2 = split[1].strip()
    echo &"{cs}{t1}:{cr} {t2}"

proc pname*(s:string, n:int): string =
  if n != 1:
    if s.endsWith("y"):
      return s.replace(re"y$", "ies")
    else:
      return &"{s}s"
  return s

proc info*(message:string) =
  log(message, "cyan", "start")

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

proc smalldir*(path:string): string =
  let str = re(&"^{getHomeDir()}")
  path.replace(str, "~/")