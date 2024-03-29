import pkg/nap

type Config* = object
  editor*: string
  path*: string
  run*: bool

proc get_config*(): Config =
  let editor = add_arg(name="editor", kind="value", help="nano or vim", value="nano")
  let path = add_arg(name="path", kind="argument", help="Path to a script file")
  let run = add_arg(name="run", kind="flag", help="Run path automatically")
  add_header("dirfun - Create directories and files")
  parse_args();
  Config(editor:editor.value, path:path.value, run:run.used)