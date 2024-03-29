import std/os
import std/osproc
import std/posix
import std/nre
import std/strutils
import std/strformat
import std/rdstdin
import constants
import utils
import config


var conf: Config
var current_dir = ""
var last_path = ("", "")
var current_level = 0
var dirs_created = 0
var files_created = 0
var used_file = ""
var script = ""

proc create(path:string, cmode:string, extra:string="") = 
  # Create dir
  if cmode == "dir":
    try:
      if not existsDir(path):
        createDir(path)
        info(&"Directory: {smalldir(path)}")
        inc(dirs_created)
    except:
      error("Can't create directory: {smalldir(path)}")
      quit(0)
  
  # Create file
  elif cmode == "file":
    try:
      if not existsFile(path):
        writeFile(path, "")
        info(&"File: {smalldir(path)}")
        inc(files_created)
    except:
      error("Can't create file: {smalldir(path)}")
      quit(0)
  
  elif cmode == "text":
    var content = ""
    try:
      content = readFile(path)
    except:
      error(&"Can't read file: {smalldir(path)}")
      quit(0)
    try:
      if content != "":
        content.add("\n")
      info(&"Text: {smalldir(path)}")
      writeFile(path, &"{content}{extra}")
    except:
      error(&"Can't write to file: {smalldir(path)}")
      quit(0)

proc process(script: string, mode="check") =
  if script.strip() == "":
    echo "Empty script."
    return

  current_dir = getCurrentDir()
  last_path = ("", "")
  dirs_created = 0
  files_created = 0
  current_level = 0
  used_file = ""

  let lines = script.splitLines

  for i, line in lines:
    var cmode = "dir"
    var extra = ""
    var direction = ""
    if line.strip() == "": continue
    let m = line.find(re"^(\t+)")

    var level = if m.isSome:
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
    elif path.startsWith("text "):
      path = path.replace(re"^text ", "").strip()
      cmode = "text"

    if path == "": continue

    # Top level
    if level == 0:
      if cmode != "dir":
        error("Root paths must be directories.")
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
        if last_path[1] == "file" and cmode != "text":
          error("A file can't be a top level path.")
          return
        if cmode == "text" and last_path[1] != "file":
          error("Text must go inside file paths.")
          return
      
      elif direction == "left":
        if last_path[1] == "text":
          dec(level)
          dec(level_diff)
      
      used_file = ""

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
      elif cmode == "text":
        used_file = last_path[0]
        extra = path
        path = used_file
    
    last_path = (path, cmode)

    if mode == "run":
      create(path, cmode, extra)
  
  # On completion
  
  if mode == "check":
    echo "Looks good."
    return
  elif mode == "runcheck":
    process(script, "run")
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

proc print_menu() =
  let cs = get_ansi("blue")
  let cr = get_ansi("reset")
  echo ""
  echo &"({cs}e{cr}) Edit Script"
  echo &"({cs}k{cr}) Check Script"
  echo &"({cs}c{cr}) Create Stuff"
  echo &"({cs}h{cr}) See Example"
  echo &"({cs}H{cr}) Run Example"
  echo &"({cs}q{cr}) Quit"
  echo ""

proc get_input(): string =
  readLineFromStdin("Choice: ").strip()
  
# Main
when isMainModule:
  conf = get_config()

  if conf.path != "":
    try:
      script = readFile(conf.path)
      if conf.run:
        process(script, "runcheck")
        quit(0)
    except:
      error("Can't read script file.")
      quit(0)
  
  enter_altscreen()
  to_bottom()
  
  while true:
    print_menu()
  
    case get_input()
    of "e": 
      script = edit(script)
      clear()
    of "h": 
      discard edit(example)
      clear()
    of "H": 
      clear()
      process(example, "runcheck")
    of "k":
      clear()
      process(script, "check")
    of "c":
      clear()
      process(script, "runcheck")
    of "q":
      exit_altscreen()
      break
    else: clear()