import constants
import utils
import config

import os
import osproc
import posix
import nre
import strutils
import strformat
import rdstdin

var conf: Config
var current_dir = ""
var last_path = ("", "")
var current_level = 0
var dirs_created = 0
var files_created = 0
var script = ""

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

proc process(script: string, just_check=false) =
  if script.strip() == "":
    echo "Empty script."
    return
  current_dir = getCurrentDir()
  last_path = ("", "")
  dirs_created = 0
  files_created = 0
  current_level = 0

  let lines = script.splitLines

  for i, line in lines:
    var cmode = "dir"
    var direction = ""
    if line.strip() == "": continue
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
  
proc edit(content=""): string =
  let editor = case conf.editor
  of "vim": "vim -c 'set autoindent tabstop=4'"
  else: "nano -it -T4"
  let tmpPath = getTempDir() / "userInputString"
  let tmpFile = tmpPath / $getpid()
  createDir tmpPath
  writeFile tmpFile, content
  discard execCmd(editor & " " & tmpFile)
  enter_altscreen()
  return tmpFile.readFile
  
# Main
when isMainModule:
  conf = get_config()

  if conf.path != "":
    try:
      script = readFile(conf.path)
      if conf.run:
        process(script)
        quit(0)
    except:
      error("Can't read script file.")
      quit(0)
  
  enter_altscreen()
  to_bottom()
  
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
      script = edit(script)
      clear()
    of "h": 
      discard edit(example)
      clear()
    of "H": 
      clear()
      process(example)
    of "k":
      clear()
      process(script, true)
    of "c":
      clear()
      process(script)
    of "q":
      exit_altscreen()
      break
    else: clear()