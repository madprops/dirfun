import os
import osproc
import posix
import nre
import strutils
import strformat
import terminal
import rdstdin

var current_dir = ""
var last_path = ("", "")
var current_level = 0
var dirs_created = 0
var files_created = 0
var input = ""

const example = "" &
"# List all directories and files to create.\n" &
"# Use tabs to create the structure.\n" &
"# Use 'file' at the beginning to create a file.\n" &
"\n" &
"# Example:\n" &
"\n" &
"~/dirfuntest\n" &
"\twork\n" &
"\t\tprograms\n" &
"\t\t\tfile db.sql\n" &
"\t\t\tfile raid.exe\n" &
"\tstuff\n" &
"\t\tfile coffee.js\n" &
"\t\tfile food.sh\n" &
"\t\tfile code.nim\n" &
"\tpics\n" &
"\t\tnice_pics\n" &
"\t\tgreat_pics\n" &
"\t\thuge_pics\n" &
"\t\t\twallpapers\n" &
"\t\t\t\tfile murica.fuckyeah"

proc log(text:string, color="", colormode="all") =
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

proc pname(s:string, n:int): string =
  if n != 1:
    if s.endsWith("y"):
      return s.replace(re"y$", "ies")
    else:
      return &"{s}s"
  return s

proc error(message:string) =
  log(&"Error: {message}", "red", "start")

proc create(path:string, cmode:string) = 
  # Create dir
  if cmode == "dir":
    try:
      if not existsDir(path):
        createDir(path)
        log(&"Directory: {path}", "cyan", "start")
        inc(dirs_created)
    except:
      error("Can't create directory: {path}")
      quit(0)
  
  # Create file
  elif cmode == "file":
    try:
      if not existsFile(path):
        writeFile(path, "")
        log(&"File: {path}", "cyan", "start")
        inc(files_created)
    except:
      error("Can't create file: {path}")
      quit(0)

proc process(input: string, just_check=false) =
  if input.strip() == "":
    echo "Empty input."
    return
  current_dir = getCurrentDir()
  last_path = ("", "")
  dirs_created = 0
  files_created = 0
  current_level = 0

  let files = input.splitLines

  for i, line in files:
    var cmode = "dir"
    var direction = ""

    let m = line.find(re"^(\t+)")

    let level = if m.isSome:
      m.get.captures[0].len
    else: 0

    var level_diff = 0

    if level > current_level:
      direction = "right"
      level_diff = level - current_level
    elif level < current_level:
      direction = "left"
      level_diff = current_level - level
    else: direction = "same"

    if direction == "right" and
      level_diff > 1:
        error("Wrong extra indentation used.")
        return
    
    current_level = level

    var path = line.strip()
    if path.startsWith("#"): continue

    if path.startswith("file "):
      path = path.replace(re"^file ", "").strip()
      cmode = "file"
    
    if path == "": continue

    # Top level
    if level == 0:
      if cmode == "file":
        error("Root paths can't be files.")
        return
      path = expandTilde(path)
      if not path.startsWith("/"):
        error("Root paths must be absolute.")
        return
      current_dir = path
    
    else:
      if path.startsWith("/") or
      path.startsWith("~"):
        error("Only root paths can be absolute.")
        return
      
      if direction == "right":
        if last_path[1] == "file":
          error("A file can't be a top level path.")
          return

      if cmode == "dir":
        if direction == "left":
          for x in 1..level_diff:
            current_dir = current_dir.parentDir
          current_dir = joinPath(current_dir, path)
          path = current_dir
        elif direction == "right":
          current_dir = joinPath(current_dir, path)
          path = current_dir
        else:
          current_dir = joinPath(current_dir.parentDir, path)
          path = current_dir
      elif cmode == "file":
        path = joinPath(current_dir, path)
    
    last_path = (path, cmode)

    if not just_check:
      create(path, cmode)
  
  # On completion
  
  if just_check:
    echo "Looks good."
    return

  if dirs_created > 0 or files_created > 0:
    if dirs_created > 0:
      let pdn = pname("directory", dirs_created)
      log(&"{dirs_created} {pdn} created.", "green")
    if files_created > 0:
      let pfn = pname("file", files_created)
      log(&"{files_created} {pfn} created.", "green")
  else:
    log("Nothing was created.")

proc enter_altscreen() =
  echo "\u001b[?1049h"

proc exit_altscreen() =
  echo "\u001b[?1049l"
  
proc edit(content=""): string =
  let editor = "nano -it -T4"
  let tmpPath = getTempDir() / "userInputString"
  let tmpFile = tmpPath / $getpid()
  createDir tmpPath
  writeFile tmpFile, content
  discard execCmd(editor & " " & tmpFile)
  enter_altscreen()
  return tmpFile.readFile

# Main
when isMainModule:
  enter_altscreen()
  cursorDown(stdout, terminalHeight())
  
  while true:

    echo ""
    echo "e) Edit Script"
    echo "k) Check Script"
    echo "c) Create Stuff"
    echo "h) See Example"
    echo "H) Run Example"
    echo "q) Quit"
    echo ""

    let ans = readLineFromStdin("Choice: ").strip()
  
    case ans
    of "e": 
      input = edit(input)
      eraseScreen()
    of "h": 
      discard edit(example)
      eraseScreen()
    of "H": 
      eraseScreen()
      process(example)
    of "k":
      eraseScreen()
      process(input, true)
    of "c":
      eraseScreen()
      process(input)
    of "q":
      exit_altscreen()
      break
    else: eraseScreen()